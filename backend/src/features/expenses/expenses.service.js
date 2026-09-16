const crypto = require('crypto');
const repo = require('./expenses.repository');
const db = require('../../config/database');
const env = require('../../config/env');
const { simplifyDebts } = require('../../shared/utils/minCashFlow.util');
const { generateVietQRUrl } = require('../../shared/services/vietqr.service');
const { requireVnd } = require('../../shared/utils/money.util');
const apiError = require('../../shared/utils/apiError.util');
const { createExpenseSchema, webhookSchema } = require('./expenses.validation');

/**
 * Validates request body using Joi schema and strips unknown properties.
 *
 * @param {import('joi').Schema} schema
 * @param {object} input
 * @returns {object} Validated value
 */
const parse = (schema, input) => {
  const { error, value } = schema.validate(input, { stripUnknown: true });
  if (error) {
    throw apiError(400, error.message);
  }
  return value;
};

/**
 * Formats raw database settlement record into client-facing structure.
 *
 * @param {object} settlement - Settlement record from DB
 * @param {Record<string, object>} people - Map of userId -> member details
 * @returns {object}
 */
const formatSettlement = (settlement, people) => ({
  id: settlement.id,
  tripId: settlement.trip_id,
  fromUser: {
    id: settlement.from_user_id,
    fullName: people[settlement.from_user_id]?.fullName,
    avatarUrl: people[settlement.from_user_id]?.avatarUrl,
  },
  toUser: {
    id: settlement.to_user_id,
    fullName: people[settlement.to_user_id]?.fullName,
    avatarUrl: people[settlement.to_user_id]?.avatarUrl,
    bankBin: settlement.bank_bin,
    bankAccountNumber: settlement.bank_account_number,
    bankAccountName: settlement.bank_account_name,
  },
  amount: Number(settlement.amount),
  status: settlement.status,
  vietqrUrl: settlement.vietqr_url,
  paidAt: settlement.paid_at,
  reportedAt: settlement.reported_at,
  createdAt: settlement.created_at,
});

/**
 * Computes deterministic signature of a transaction set to detect identical reruns.
 */
const computeSignature = (list) =>
  list
    .map((s) =>
      [
        s.fromUserId || s.from_user_id,
        s.toUserId || s.to_user_id,
        Number(s.amount),
      ].join(':')
    )
    .sort()
    .join('|');

/**
 * Records a new expense in a trip and calculates split shares among members.
 *
 * @param {object} input - Expense creation payload
 * @param {string} currentUserId - Authenticated user UUID
 * @returns {Promise<object>} Created expense and splits
 */
const createExpense = async (input, currentUserId) => {
  const expense = parse(createExpenseSchema, input);
  expense.payerId = expense.payerId || currentUserId;

  const { amount, splitType, splits, tripId } = expense;
  const participantIds = splits.map((s) => (typeof s === 'string' ? s : s.userId));
  let shares = [];

  if (splitType === 'EQUAL') {
    const memberCount = splits.length;
    const baseShare = Math.floor(amount / memberCount);
    const remainder = amount % memberCount;

    shares = participantIds.map((userId, index) => ({
      userId,
      amountOwed: baseShare + (index < remainder ? 1 : 0),
    }));
  } else if (splitType === 'EXACT') {
    shares = splits.map((s) => ({
      userId: s.userId,
      amountOwed: requireVnd(s.amountOwed, true),
    }));

    const totalShared = shares.reduce((sum, s) => sum + BigInt(s.amountOwed), 0n);
    if (totalShared !== BigInt(amount)) {
      throw apiError(400, 'Tổng tiền chia phải bằng đúng số tiền khoản chi');
    }
  } else {
    // PERCENTAGE split
    const percentagesInBps = splits.map((s) => Math.round(s.percentage * 100));
    const totalPercentage = percentagesInBps.reduce((sum, p) => sum + p, 0);

    if (totalPercentage !== 10000) {
      throw apiError(400, 'Tổng phần trăm phải bằng 100%');
    }

    const products = percentagesInBps.map((p) => BigInt(amount) * BigInt(p));
    shares = participantIds.map((userId, index) => ({
      userId,
      amountOwed: Number(products[index] / 10000n),
    }));

    const allocatedAmount = shares.reduce((sum, s) => sum + s.amountOwed, 0);
    const remainingDiff = amount - allocatedAmount;

    // Distribute remaining fractional dong by largest remainder order
    const remainderOrder = participantIds
      .map((_, index) => index)
      .sort(
        (a, b) =>
          Number((products[b] % 10000n) - (products[a] % 10000n)) || a - b
      );

    for (let i = 0; i < remainingDiff; i++) {
      shares[remainderOrder[i]].amountOwed += 1;
    }
  }

  return db.transaction(async (client) => {
    await repo.lockTrip(client, tripId);
    await repo.requireMember(tripId, currentUserId, client);

    const involvedUsers = new Set([expense.payerId, ...participantIds]);
    for (const userId of involvedUsers) {
      await repo.requireMember(tripId, userId, client);
    }

    return repo.createExpenseWithSplits(expense, shares, client);
  });
};

/**
 * Retrieves all expenses and budget summary for a trip.
 */
const getTripExpenses = async (tripId, userId) => {
  await repo.requireMember(tripId, userId);

  const [summary, expenses] = await Promise.all([
    repo.getTripBudgetSummary(tripId),
    repo.findExpensesByTripId(tripId),
  ]);

  return { summary, expenses };
};

/**
 * Retrieves financial balances of all members in a trip.
 */
const getTripBalances = async (tripId, userId) => {
  await repo.requireMember(tripId, userId);
  return repo.calculateTripNetBalances(tripId);
};

/**
 * Calculates simplified debt settlements using Min Cash Flow algorithm and generates VietQRs.
 */
const settleTripDebts = (tripId, userId) =>
  db.transaction(async (client) => {
    await repo.lockTrip(client, tripId);
    await repo.requireMember(tripId, userId, client);

    const members = await repo.calculateTripNetBalances(tripId, client);
    const peopleMap = Object.fromEntries(members.map((m) => [m.userId, m]));
    const pendingSettlements = await repo.openSettlements(tripId, client);

    if (pendingSettlements.some((s) => s.status === 'REPORTED')) {
      throw apiError(409, 'Cần xác nhận các khoản đã báo chuyển trước khi tính lại');
    }

    const netBalances = Object.fromEntries(members.map((m) => [m.userId, m.netBalance]));
    const optimalTransactions = simplifyDebts(netBalances);

    // If transactions match current open set, reuse existing QRs to preserve payment links
    if (computeSignature(pendingSettlements) === computeSignature(optimalTransactions)) {
      return pendingSettlements.map((s) => formatSettlement(s, peopleMap));
    }

    const newSettlements = optimalTransactions.map((tx) => {
      const recipient = peopleMap[tx.toUserId];
      const settlementId = crypto.randomUUID();
      const bankBin = recipient.bankBin || null;
      const bankAccountNumber = recipient.bankAccountNumber || null;

      const vietqrUrl =
        bankBin && bankAccountNumber
          ? generateVietQRUrl({
              bankBin,
              accountNumber: bankAccountNumber,
              amount: tx.amount,
              description: 'FT ' + settlementId.replaceAll('-', '').toUpperCase(),
            })
          : null;

      return {
        ...tx,
        id: settlementId,
        bankBin,
        bankAccountNumber,
        bankAccountName: recipient.bankAccountName || null,
        vietqrUrl,
      };
    });

    const saved = await repo.saveSettlements(tripId, newSettlements, client);
    return saved.map((s) => formatSettlement(s, peopleMap));
  });

/**
 * Retrieves or generates VietQR for a specific settlement.
 */
const getSettlementVietQR = async (settlementId, userId) =>
  db.transaction(async (client) => {
    const initial = await repo.findSettlementById(settlementId, client);
    if (!initial) {
      throw apiError(404, 'Không tìm thấy khoản thanh toán');
    }

    await repo.lockTrip(client, initial.trip_id);
    await repo.requireMember(initial.trip_id, userId, client);

    let settlement = await repo.findSettlementById(settlementId, client);

    if (settlement.status === 'CANCELLED') {
      throw apiError(409, 'Khoản thanh toán đã được thay thế. Vui lòng tải lại công nợ');
    }

    if (!settlement.vietqr_url && settlement.status === 'PENDING') {
      const bank = await repo.findRecipientBank(settlement.to_user_id, client);
      if (bank.bank_bin && bank.bank_account_number) {
        const url = generateVietQRUrl({
          bankBin: bank.bank_bin,
          accountNumber: bank.bank_account_number,
          amount: Number(settlement.amount),
          description: 'FT ' + settlementId.replaceAll('-', '').toUpperCase(),
        });
        settlement = {
          ...settlement,
          ...(await repo.attachVietQR(settlementId, bank, url, client)),
        };
      }
    }

    return {
      ...settlement,
      amount: Number(settlement.amount),
      vietqrUrl: settlement.vietqr_url,
    };
  });

/**
 * Updates settlement state machine.
 * - Debtor reports payment: PENDING -> REPORTED
 * - Creditor confirms payment: REPORTED -> PAID
 */
const updateSettlementState = (settlementId, userId, isCreditorConfirmation) =>
  db.transaction(async (client) => {
    const initial = await repo.findSettlementById(settlementId, client);
    if (!initial) {
      throw apiError(404, 'Không tìm thấy khoản thanh toán');
    }

    await repo.lockTrip(client, initial.trip_id);
    const settlement = await repo.findSettlementById(settlementId, client);

    const authorizedUser = isCreditorConfirmation
      ? settlement.to_user_id
      : settlement.from_user_id;

    if (authorizedUser !== userId) {
      throw apiError(403, 'Bạn không có quyền thực hiện thao tác này');
    }

    if (settlement.status === 'CANCELLED') {
      throw apiError(409, 'Khoản thanh toán đã được thay thế');
    }

    if (isCreditorConfirmation && settlement.status === 'PENDING') {
      throw apiError(409, 'Người trả chưa báo đã chuyển tiền');
    }

    const nextStatus = isCreditorConfirmation ? 'PAID' : 'REPORTED';
    const isAlreadyTarget =
      settlement.status === 'PAID' ||
      (!isCreditorConfirmation && settlement.status === 'REPORTED');

    const updated = isAlreadyTarget
      ? settlement
      : await repo.updateSettlementStatus(settlementId, nextStatus, client);

    return {
      settlement: updated,
      message: isCreditorConfirmation
        ? 'Đã xác nhận nhận tiền'
        : 'Đã báo chuyển tiền, chờ người nhận xác nhận',
    };
  });

const markSettlementPaid = (id, userId) => updateSettlementState(id, userId, false);
const confirmSettlement = (id, userId) => updateSettlementState(id, userId, true);

// Pollable payment view: only a connected receiver can advertise automatic payment.
const getPaymentStatus = async (id, userId) => {
  const existing = await repo.findSettlementById(id, db);
  if (!existing) throw apiError(404, 'Không tìm thấy khoản thanh toán');
  await repo.requireMember(existing.trip_id, userId);
  if (existing.status === 'CANCELLED') {
    return { id, status: 'CANCELLED', amount: Number(existing.amount), vietqrUrl: null,
      automaticConfirmationAvailable: false, paidAt: existing.paid_at };
  }
  const settlement = await getSettlementVietQR(id, userId);
  const { rows: [account] } = await db.query(`SELECT xid FROM bankhub_accounts
    WHERE user_id=$1 AND bank_bin=$2 AND account_number=$3 AND active=TRUE`,
  [settlement.to_user_id,settlement.bank_bin,settlement.bank_account_number]);
  const canPay = settlement.status === 'PENDING' && Boolean(account);
  return {
    id: settlement.id, status: settlement.status, amount: settlement.amount,
    fromUserId: settlement.from_user_id, toUserId: settlement.to_user_id,
    recipientName: settlement.to_user_name,
    automaticConfirmationAvailable: Boolean(account),
    vietqrUrl: canPay ? settlement.vietqrUrl : null,
    paidAt: settlement.paid_at,
  };
};

/**
 * Updates estimated budget for a trip (leader only).
 */
const updateBudget = (tripId, userId, budget) =>
  db.transaction(async (client) => {
    await repo.lockTrip(client, tripId);
    await repo.requireMember(tripId, userId, client, true);
    return repo.updateBudget(tripId, requireVnd(budget, true), client);
  });

/**
 * Reconciles incoming SePay payment webhook.
 */
const handleSepayWebhook = async (input, authorizationHeader) => {
  if (!env.sepayApiKey) {
    throw apiError(503, 'SePay chưa được cấu hình');
  }

  const match = /^(?:Apikey|Bearer) ([^\s]+)$/i.exec(authorizationHeader || '');
  const sha256 = (str) => crypto.createHash('sha256').update(str).digest();

  if (
    !match ||
    !crypto.timingSafeEqual(sha256(match[1]), sha256(env.sepayApiKey))
  ) {
    throw apiError(401, 'Khóa xác thực SePay không hợp lệ');
  }

  const event = parse(webhookSchema, input);
  const skip = (message) => ({ success: true, processed: false, message });

  if (event.transferType !== 'in') {
    return skip('Bỏ qua tiền ra');
  }

  const matches = [
    ...(event.content || event.description || '').matchAll(
      /\bFT\s*([a-f0-9]{32}|[a-f0-9]{8})\b/gi
    ),
  ];

  if (matches.length !== 1) {
    return skip('Không có một mã FT hợp lệ duy nhất');
  }

  const paymentReference = matches[0][1];

  return db.transaction(async (client) => {
    const initial = await repo.findSettlementByReference(paymentReference, client);
    if (!initial) {
      return skip('Không tìm thấy khoản thanh toán');
    }

    await repo.lockTrip(client, initial.trip_id);
    const settlement = await repo.findSettlementById(initial.id, client);

    if (settlement.status === 'CANCELLED') {
      return skip('QR đã bị thay thế; cần đối soát thủ công');
    }

    const expectedBin = env.sepayBankBins[event.gateway];
    if (!expectedBin) {
      throw apiError(503, 'Chưa cấu hình BIN cho ngân hàng SePay này');
    }

    if (
      settlement.bank_bin !== String(expectedBin) ||
      settlement.bank_account_number !== event.accountNumber
    ) {
      throw apiError(400, 'Ngân hàng hoặc tài khoản nhận không khớp');
    }

    if (event.transferAmount !== Number(settlement.amount)) {
      throw apiError(400, 'Số tiền không khớp; cần đối soát thủ công');
    }

    const isNewEvent = await repo.recordWebhook(event, settlement.id, client);
    if (!isNewEvent) {
      return skip('Giao dịch đã được xử lý');
    }

    if (settlement.status === 'PAID') {
      return skip('Khoản nợ đã được thanh toán');
    }

    const updatedSettlement = await repo.updateSettlementStatus(settlement.id, 'PAID', client);
    return {
      success: true,
      processed: true,
      message: 'Đã xác nhận thanh toán SePay',
      settlement: updatedSettlement,
    };
  });
};

module.exports = {
  createExpense,
  getTripExpenses,
  getTripBalances,
  settleTripDebts,
  getSettlementVietQR,
  markSettlementPaid,
  confirmSettlement,
  updateBudget,
  handleSepayWebhook,
  getPaymentStatus,
};
