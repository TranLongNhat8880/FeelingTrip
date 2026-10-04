const db = require('../../config/database');
const apiError = require('../../shared/utils/apiError.util');

const lockTrip = async (client, tripId) => {
  const { rows: [trip] } = await client.query('SELECT * FROM trips WHERE id = $1 FOR UPDATE', [tripId]);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  return trip;
};
const requireMember = async (tripId, userId, client = db, leaderOnly = false) => {
  const { rows: [row] } = await client.query(`
    SELECT t.creator_id, tm.id AS membership_id, tm.role, tm.membership_status FROM trips t
    LEFT JOIN trip_members tm ON tm.trip_id = t.id AND tm.user_id = $2
    WHERE t.id = $1`, [tripId, userId]);
  // Creator fallback supports legacy trips without a membership row. A retained
  // LEFT/REMOVED row must never regain access through creator_id or its old role.
  const legacyCreator = row && !row.membership_id && row.creator_id === userId;
  const activeMember = row && row.membership_status === 'ACTIVE'
    && ['LEADER', 'MEMBER'].includes(row.role);
  if (!legacyCreator && (!activeMember || (leaderOnly && row.role !== 'LEADER'))) {
    throw apiError(403, 'Bạn không có quyền truy cập chuyến đi này');
  }
};
const createExpenseWithSplits = async (expense, splits, client) => {
  const { rows: [created] } = await client.query(`
    INSERT INTO expenses (trip_id, payer_id, title, amount, category, receipt_image_url, expense_date)
    VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [expense.tripId, expense.payerId, expense.title, expense.amount, expense.category,
      expense.receiptImageUrl || null, expense.expenseDate || new Date()]);
  const saved = [];
  for (const split of splits) {
    const { rows: [row] } = await client.query(
      'INSERT INTO expense_splits (expense_id, user_id, amount_owed) VALUES ($1,$2,$3) RETURNING *',
      [created.id, split.userId, split.amountOwed]);
    saved.push(row);
  }
  await client.query(`
    INSERT INTO notifications (user_id, title, message, type, data)
    SELECT DISTINCT user_id, 'Khoản chi mới', $2, 'BILL', $3::jsonb
    FROM expense_splits WHERE expense_id = $1`,
    [created.id, expense.title, JSON.stringify({ tripId: expense.tripId, expenseId: created.id })]);
  return { expense: created, splits: saved };
};

const findExpensesByTripId = async (tripId) => {
  // Lấy các khoản chi kèm thông tin người trả
  const expensesQuery = `
    SELECT e.id, e.trip_id, e.payer_id, e.title, e.amount, e.category,
           e.receipt_image_url, e.expense_date, e.created_at,
           u.full_name AS payer_name, u.avatar_url AS payer_avatar
    FROM expenses e
    JOIN users u ON e.payer_id = u.id
    WHERE e.trip_id = $1
    ORDER BY e.expense_date DESC, e.created_at DESC;
  `;
  const { rows: expenses } = await db.query(expensesQuery, [tripId]);

  if (expenses.length === 0) return [];

  // Lấy danh sách chia tiền của toàn bộ các khoản chi trong trip này
  const splitsQuery = `
    SELECT es.id, es.expense_id, es.user_id, es.amount_owed,
           u.full_name, u.avatar_url
    FROM expense_splits es
    JOIN users u ON es.user_id = u.id
    JOIN expenses e ON es.expense_id = e.id
    WHERE e.trip_id = $1;
  `;
  const { rows: splits } = await db.query(splitsQuery, [tripId]);

  // Gom nhóm splits theo expense_id
  const splitsByExpenseId = {};
  splits.forEach((split) => {
    if (!splitsByExpenseId[split.expense_id]) {
      splitsByExpenseId[split.expense_id] = [];
    }
    splitsByExpenseId[split.expense_id].push({
      userId: split.user_id,
      fullName: split.full_name,
      avatarUrl: split.avatar_url,
      amountOwed: Number(split.amount_owed),
    });
  });

  return expenses.map((exp) => ({
    ...exp,
    amount: Number(exp.amount),
    splits: splitsByExpenseId[exp.id] || [],
  }));
};

/**
 * 3. Lấy báo cáo tổng ngân sách và chi tiêu của chuyến đi
 */
const getTripBudgetSummary = async (tripId) => {
  // Lấy thông tin ngân sách dự kiến của chuyến đi
  const tripQuery = `
    SELECT id, name, destination, estimated_budget
    FROM trips
    WHERE id = $1;
  `;
  const { rows: tripRows } = await db.query(tripQuery, [tripId]);
  if (tripRows.length === 0) return null;

  const trip = tripRows[0];

  // Tổng tiền đã chi
  const spentQuery = `
    SELECT COALESCE(SUM(amount), 0) AS total_spent
    FROM expenses
    WHERE trip_id = $1;
  `;
  const { rows: spentRows } = await db.query(spentQuery, [tripId]);
  const totalSpent = Number(spentRows[0].total_spent);
  const estimatedBudget = Number(trip.estimated_budget) || 0;
  const remainingBudget = estimatedBudget - totalSpent;

  // Thống kê chi tiêu theo danh mục
  const categoryQuery = `
    SELECT category, COALESCE(SUM(amount), 0) AS total_amount, COUNT(id) AS count
    FROM expenses
    WHERE trip_id = $1
    GROUP BY category
    ORDER BY total_amount DESC;
  `;
  const { rows: categoryRows } = await db.query(categoryQuery, [tripId]);

  return {
    tripId: trip.id,
    tripName: trip.name,
    destination: trip.destination,
    estimatedBudget,
    totalSpent,
    remainingBudget,
    byCategory: categoryRows.map((cat) => ({
      category: cat.category,
      totalAmount: Number(cat.total_amount),
      count: parseInt(cat.count, 10),
    })),
  };
};

/**
 * 4. Tính toán số dư ròng của các thành viên trong chuyến đi
 * (Tổng tiền đã chi - Tổng tiền phải chịu)
 */

// Include former members with financial history so removing a member cannot erase a debt.
const calculateTripNetBalances = async (tripId, client = db) => {
  const { rows } = await client.query(`
    WITH ledger AS (
      SELECT payer_id AS user_id, amount AS delta, amount AS paid, 0::numeric AS owed
        FROM expenses WHERE trip_id = $1
      UNION ALL
      SELECT es.user_id, -es.amount_owed, 0, es.amount_owed FROM expense_splits es
        JOIN expenses e ON e.id = es.expense_id WHERE e.trip_id = $1
      UNION ALL SELECT from_user_id, amount, 0, 0 FROM settlements WHERE trip_id = $1 AND status = 'PAID'
      UNION ALL SELECT to_user_id, -amount, 0, 0 FROM settlements WHERE trip_id = $1 AND status = 'PAID'
    ), people AS (
      SELECT user_id FROM trip_members WHERE trip_id = $1 AND membership_status = 'ACTIVE'
      UNION SELECT creator_id FROM trips WHERE id = $1
      UNION SELECT user_id FROM ledger
    )
    SELECT u.id, u.full_name, u.avatar_url, u.bank_bin, u.bank_name, u.bank_account_number, u.bank_account_name,
      COALESCE(SUM(l.delta),0) AS balance, COALESCE(SUM(l.paid),0) AS paid, COALESCE(SUM(l.owed),0) AS owed
    FROM people p JOIN users u ON u.id = p.user_id LEFT JOIN ledger l ON l.user_id = u.id
    GROUP BY u.id ORDER BY u.id`, [tripId]);
  return rows.map(u => ({
    userId: u.id, fullName: u.full_name, avatarUrl: u.avatar_url,
    bankBin: u.bank_bin, bankName: u.bank_name, bankAccountNumber: u.bank_account_number,
    bankAccountName: u.bank_account_name, totalPaid: Number(u.paid),
    totalOwed: Number(u.owed), netBalance: Number(u.balance),
  }));
};
const findSettlementById = async (id, client = db) => {
  const { rows: [row] } = await client.query(`
    SELECT s.*, fu.full_name AS from_user_name, tu.full_name AS to_user_name
    FROM settlements s JOIN users fu ON fu.id = s.from_user_id JOIN users tu ON tu.id = s.to_user_id
    WHERE s.id = $1`, [id]);
  return row || null;
};
const openSettlements = async (tripId, client) => {
  const { rows } = await client.query(
    "SELECT * FROM settlements WHERE trip_id = $1 AND status IN ('PENDING','REPORTED') ORDER BY id", [tripId]);
  return rows;
};
const saveSettlements = async (tripId, list, client) => {
  // Keep retired QR references for audit; they must never match a new payment.
  await client.query("UPDATE settlements SET status = 'CANCELLED' WHERE trip_id = $1 AND status = 'PENDING'", [tripId]);
  const saved = [];
  for (const s of list) {
    const { rows: [row] } = await client.query(`
      INSERT INTO settlements (id, trip_id, from_user_id, to_user_id, amount, vietqr_url,
        bank_bin, bank_account_number, bank_account_name)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [s.id, tripId, s.fromUserId, s.toUserId, s.amount, s.vietqrUrl,
        s.bankBin, s.bankAccountNumber, s.bankAccountName]);
    saved.push(row);
  }
  return saved;
};
const updateSettlementStatus = async (id, status, client) => {
  const { rows: [row] } = await client.query(`
    UPDATE settlements SET status = $2::varchar,
      reported_at = CASE WHEN $2 = 'REPORTED' THEN NOW() ELSE reported_at END,
      paid_at = CASE WHEN $2 = 'PAID' THEN NOW() ELSE paid_at END
    WHERE id = $1 RETURNING *`, [id, status]);
  return row;
};
const findSettlementByReference = async (reference, client = db) => {
  // Exact full reference for new QRs; accept legacy 8-char references only when unambiguous.
  const { rows } = await client.query(`
    SELECT * FROM settlements WHERE REPLACE(id::text, '-', '') = $1
      OR (LENGTH($1) = 8 AND LEFT(REPLACE(id::text, '-', ''),8) = $1)`, [reference.toLowerCase()]);
  if (rows.length > 1) throw apiError(409, 'Mã thanh toán không duy nhất');
  return rows[0] || null;
};
const updateBudget = async (tripId, amount, client) => {
  const { rows: [row] } = await client.query(
    'UPDATE trips SET estimated_budget = $2 WHERE id = $1 RETURNING id, estimated_budget', [tripId, amount]);
  return { tripId: row.id, estimatedBudget: Number(row.estimated_budget) };
};
const recordWebhook = async (event, settlementId, client) => {
  const { rows } = await client.query(`
    INSERT INTO sepay_events (transaction_id, settlement_id) VALUES ($1,$2)
    ON CONFLICT (transaction_id) DO NOTHING RETURNING transaction_id`, [String(event.id), settlementId]);
  return rows.length === 1;
};
const findRecipientBank = async (id, client) => {
  const { rows: [bank] } = await client.query(
    'SELECT bank_bin, bank_account_number, bank_account_name FROM users WHERE id = $1', [id]);
  return bank;
};
const attachVietQR = async (id, bank, url, client) => {
  const { rows: [row] } = await client.query(`UPDATE settlements SET bank_bin = $2,
    bank_account_number = $3, bank_account_name = $4, vietqr_url = $5 WHERE id = $1 RETURNING *`,
    [id, bank.bank_bin, bank.bank_account_number, bank.bank_account_name, url]);
  return row;
};
module.exports = { lockTrip, requireMember, createExpenseWithSplits, findExpensesByTripId,
  getTripBudgetSummary, calculateTripNetBalances, findSettlementById, openSettlements,
  saveSettlements, updateSettlementStatus, findSettlementByReference, updateBudget, recordWebhook,
  findRecipientBank, attachVietQR };
