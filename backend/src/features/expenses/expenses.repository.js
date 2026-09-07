const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Expenses & Split Bill
// Thao tác với các bảng 'expenses', 'expense_splits', 'settlements' trong Database
// ============================================================================

/**
 * 1. Tạo khoản chi tiêu và phân bổ số tiền nợ (Database Transaction)
 */
const createExpenseWithSplits = async (expenseData, splitsData) => {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');

    // 1.1 Insert khoản chi chính
    const expenseQuery = `
      INSERT INTO expenses (trip_id, payer_id, title, amount, category, receipt_image_url, expense_date)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *;
    `;
    const expenseValues = [
      expenseData.tripId,
      expenseData.payerId,
      expenseData.title,
      expenseData.amount,
      expenseData.category || 'OTHER',
      expenseData.receiptImageUrl || null,
      expenseData.expenseDate || new Date(),
    ];
    const { rows: expenseRows } = await client.query(expenseQuery, expenseValues);
    const createdExpense = expenseRows[0];

    // 1.2 Insert từng phần chia cho các thành viên
    const savedSplits = [];
    for (const split of splitsData) {
      const splitQuery = `
        INSERT INTO expense_splits (expense_id, user_id, amount_owed)
        VALUES ($1, $2, $3)
        RETURNING id, expense_id, user_id, amount_owed;
      `;
      const { rows: splitRows } = await client.query(splitQuery, [
        createdExpense.id,
        split.userId,
        split.amountOwed,
      ]);
      savedSplits.push(splitRows[0]);
    }

    await client.query('COMMIT');
    return {
      expense: createdExpense,
      splits: savedSplits,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

/**
 * 2. Lấy danh sách toàn bộ các khoản chi trong chuyến đi kèm chi tiết ai chịu
 */
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
const calculateTripNetBalances = async (tripId) => {
  // Lấy tất cả thành viên trong chuyến đi (bao gồm creator và members)
  const membersQuery = `
    SELECT u.id AS user_id, u.full_name, u.avatar_url,
           u.bank_bin, u.bank_name, u.bank_account_number, u.bank_account_name
    FROM trip_members tm
    JOIN users u ON tm.user_id = u.id
    WHERE tm.trip_id = $1
    UNION
    SELECT u.id AS user_id, u.full_name, u.avatar_url,
           u.bank_bin, u.bank_name, u.bank_account_number, u.bank_account_name
    FROM trips t
    JOIN users u ON t.creator_id = u.id
    WHERE t.id = $1;
  `;
  const { rows: members } = await db.query(membersQuery, [tripId]);

  // Tổng tiền mỗi người đã thanh toán trước
  const paidQuery = `
    SELECT payer_id AS user_id, COALESCE(SUM(amount), 0) AS total_paid
    FROM expenses
    WHERE trip_id = $1
    GROUP BY payer_id;
  `;
  const { rows: paidRows } = await db.query(paidQuery, [tripId]);
  const paidMap = {};
  paidRows.forEach((r) => {
    paidMap[r.user_id] = Number(r.total_paid);
  });

  // Tổng tiền mỗi người phải chịu theo các khoản chi
  const owedQuery = `
    SELECT es.user_id, COALESCE(SUM(es.amount_owed), 0) AS total_owed
    FROM expense_splits es
    JOIN expenses e ON es.expense_id = e.id
    WHERE e.trip_id = $1
    GROUP BY es.user_id;
  `;
  const { rows: owedRows } = await db.query(owedQuery, [tripId]);
  const owedMap = {};
  owedRows.forEach((r) => {
    owedMap[r.user_id] = Number(r.total_owed);
  });

  return members.map((member) => {
    const totalPaid = paidMap[member.user_id] || 0;
    const totalOwed = owedMap[member.user_id] || 0;
    const netBalance = totalPaid - totalOwed;
    return {
      userId: member.user_id,
      fullName: member.full_name,
      avatarUrl: member.avatar_url,
      bankBin: member.bank_bin,
      bankName: member.bank_name,
      bankAccountNumber: member.bank_account_number,
      bankAccountName: member.bank_account_name,
      totalPaid,
      totalOwed,
      netBalance,
    };
  });
};

/**
 * 5. Lưu danh sách thanh toán rút gọn vào bảng 'settlements'
 */
const saveSettlements = async (tripId, settlementsList) => {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');

    // Xóa các khoản nợ cũ chưa thanh toán (PENDING) để tính toán lại mới
    await client.query(
      `DELETE FROM settlements WHERE trip_id = $1 AND status = 'PENDING'`,
      [tripId]
    );

    const savedSettlements = [];
    for (const item of settlementsList) {
      const queryText = item.id
        ? `
          INSERT INTO settlements (id, trip_id, from_user_id, to_user_id, amount, status, vietqr_url)
          VALUES ($1, $2, $3, $4, $5, 'PENDING', $6)
          RETURNING *;
        `
        : `
          INSERT INTO settlements (trip_id, from_user_id, to_user_id, amount, status, vietqr_url)
          VALUES ($1, $2, $3, $4, 'PENDING', $5)
          RETURNING *;
        `;
      const values = item.id
        ? [item.id, tripId, item.fromUserId, item.toUserId, item.amount, item.vietqrUrl || null]
        : [tripId, item.fromUserId, item.toUserId, item.amount, item.vietqrUrl || null];

      const { rows } = await client.query(queryText, values);
      savedSettlements.push(rows[0]);
    }

    await client.query('COMMIT');
    return savedSettlements;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

/**
 * 6. Lấy chi tiết một khoản nợ kèm thông tin ngân hàng người thụ hưởng
 */
const findSettlementById = async (settlementId) => {
  const queryText = `
    SELECT s.id, s.trip_id, s.from_user_id, s.to_user_id, s.amount, s.status,
           s.vietqr_url, s.paid_at, s.created_at,
           fu.full_name AS from_user_name, fu.avatar_url AS from_user_avatar,
           tu.full_name AS to_user_name, tu.avatar_url AS to_user_avatar,
           tu.bank_bin, tu.bank_name, tu.bank_account_number, tu.bank_account_name
    FROM settlements s
    JOIN users fu ON s.from_user_id = fu.id
    JOIN users tu ON s.to_user_id = tu.id
    WHERE s.id = $1;
  `;
  const { rows } = await db.query(queryText, [settlementId]);
  return rows[0] || null;
};

/**
 * 7. Cập nhật trạng thái thanh toán khoản nợ ('PAID')
 */
const updateSettlementStatus = async (settlementId, status = 'PAID') => {
  const queryText = `
    UPDATE settlements
    SET status = $2, paid_at = CURRENT_TIMESTAMP
    WHERE id = $1
    RETURNING *;
  `;
  const { rows } = await db.query(queryText, [settlementId, status]);
  return rows[0] || null;
};

/**
 * 8. Tìm khoản nợ theo mã tham chiếu (Dùng cho SePay Webhook)
 */
const findSettlementByReference = async (refText) => {
  // Tìm kiếm theo chuỗi ID khớp với nội dung chuyển khoản
  const queryText = `
    SELECT s.*
    FROM settlements s
    WHERE s.status = 'PENDING'
      AND (
        $1 ILIKE '%' || REPLACE(s.id::text, '-', '') || '%'
        OR $1 ILIKE '%' || SUBSTRING(REPLACE(s.id::text, '-', '') FROM 1 FOR 8) || '%'
      )
    ORDER BY s.created_at DESC
    LIMIT 1;
  `;
  const { rows } = await db.query(queryText, [refText]);
  return rows[0] || null;
};

module.exports = {
  createExpenseWithSplits,
  findExpensesByTripId,
  getTripBudgetSummary,
  calculateTripNetBalances,
  saveSettlements,
  findSettlementById,
  updateSettlementStatus,
  findSettlementByReference,
};
