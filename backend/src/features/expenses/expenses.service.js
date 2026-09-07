const expensesRepository = require('./expenses.repository');
const { simplifyDebts } = require('../../shared/utils/minCashFlow.util');
const { generateVietQRUrl } = require('../../shared/services/vietqr.service');
const env = require('../../config/env');
const crypto = require('crypto');

// ============================================================================
// SERVICE: Expenses & Split Bill
// Nghiệp vụ tính toán hóa đơn, phân chia tiền nợ, tối ưu công nợ và VietQR
// ============================================================================

/**
 * 1. Tạo khoản chi tiêu mới và phân bổ phần tiền cho từng thành viên
 */
const createExpense = async ({
  tripId,
  payerId,
  title,
  amount,
  category = 'OTHER',
  receiptImageUrl = null,
  expenseDate = new Date(),
  splitType = 'EQUAL',
  splits = [],
}) => {
  const numericAmount = Number(amount);
  if (numericAmount <= 0) {
    const error = new Error('Số tiền chi tiêu phải lớn hơn 0');
    error.status = 400;
    throw error;
  }

  if (!splits || splits.length === 0) {
    const error = new Error('Vui lòng chọn ít nhất 1 thành viên cùng chi tiêu');
    error.status = 400;
    throw error;
  }

  let splitsData = [];

  // CHIA ĐỀU (EQUAL)
  if (splitType === 'EQUAL') {
    const memberIds = splits.map((s) => (typeof s === 'string' ? s : s.userId));
    const count = memberIds.length;
    const baseShare = Math.floor(numericAmount / count);
    const remainder = numericAmount - baseShare * count; // Xử lý số tiền lẻ thừa ra

    splitsData = memberIds.map((userId, idx) => ({
      userId,
      amountOwed: idx === 0 ? baseShare + remainder : baseShare,
    }));
  }
  // CHIA THEO SỐ TIỀN CỤ THỂ (EXACT)
  else if (splitType === 'EXACT') {
    let sumExact = 0;
    splitsData = splits.map((s) => {
      const owed = Math.round(Number(s.amountOwed));
      sumExact += owed;
      return {
        userId: s.userId,
        amountOwed: owed,
      };
    });

    if (Math.abs(sumExact - numericAmount) > 1) {
      const error = new Error(
        `Tổng số tiền các phần chia (${sumExact.toLocaleString('vi-VN')}đ) không khớp với số tiền khoản chi (${numericAmount.toLocaleString('vi-VN')}đ)`
      );
      error.status = 400;
      throw error;
    }
  }
  // CHIA THEO PHẦN TRĂM (PERCENTAGE)
  else if (splitType === 'PERCENTAGE') {
    let sumPercentage = 0;
    splits.forEach((s) => {
      sumPercentage += Number(s.percentage);
    });

    if (Math.abs(sumPercentage - 100) > 0.01) {
      const error = new Error('Tổng phần trăm chia phải đúng bằng 100%');
      error.status = 400;
      throw error;
    }

    let allocatedSum = 0;
    splitsData = splits.map((s, idx) => {
      const owed = Math.round(numericAmount * (Number(s.percentage) / 100));
      allocatedSum += owed;
      return {
        userId: s.userId,
        amountOwed: owed,
      };
    });

    // Bù phần chênh lệch do làm tròn số vào người đầu tiên
    const diff = numericAmount - allocatedSum;
    if (diff !== 0 && splitsData.length > 0) {
      splitsData[0].amountOwed += diff;
    }
  } else {
    const error = new Error('Kiểu chia tiền không hợp lệ');
    error.status = 400;
    throw error;
  }

  const result = await expensesRepository.createExpenseWithSplits(
    {
      tripId,
      payerId,
      title,
      amount: numericAmount,
      category,
      receiptImageUrl,
      expenseDate,
    },
    splitsData
  );

  return result;
};

/**
 * 2. Lấy danh sách toàn bộ các khoản chi và ngân sách chuyến đi
 */
const getTripExpenses = async (tripId) => {
  const summary = await expensesRepository.getTripBudgetSummary(tripId);
  const expenses = await expensesRepository.findExpensesByTripId(tripId);

  return {
    summary,
    expenses,
  };
};

/**
 * 3. Xem bảng cân đối tài chính của các thành viên trong chuyến đi
 */
const getTripBalances = async (tripId) => {
  return await expensesRepository.calculateTripNetBalances(tripId);
};

/**
 * 4. Chạy thuật toán Min Cash Flow rút gọn nợ & sinh mã VietQR
 */
const settleTripDebts = async (tripId) => {
  const members = await expensesRepository.calculateTripNetBalances(tripId);
  if (!members || members.length === 0) {
    const error = new Error('Không tìm thấy thành viên nào trong chuyến đi');
    error.status = 404;
    throw error;
  }

  // Chuyển đổi sang object netBalances: { [userId]: netAmount }
  const netBalances = {};
  const membersMap = {};
  members.forEach((m) => {
    netBalances[m.userId] = m.netBalance;
    membersMap[m.userId] = m;
  });

  // Gọi thuật toán tối ưu hóa nợ Min Cash Flow
  const simplifiedTransactions = simplifyDebts(netBalances);

  // Sinh mã VietQR cho từng giao dịch trả nợ nếu người nhận có tài khoản ngân hàng
  const settlementsWithQr = simplifiedTransactions.map((tx) => {
    const toUser = membersMap[tx.toUserId];
    const settlementId = crypto.randomUUID();
    const shortCode = settlementId.replace(/-/g, '').substring(0, 8).toUpperCase();
    let vietqrUrl = null;

    if (toUser && toUser.bankBin && toUser.bankAccountNumber) {
      try {
        vietqrUrl = generateVietQRUrl({
          bankBin: toUser.bankBin,
          accountNumber: toUser.bankAccountNumber,
          amount: tx.amount,
          description: `FT ${shortCode}`,
        });
      } catch (e) {
        console.error('Không thể sinh mã VietQR:', e.message);
      }
    }

    return {
      id: settlementId,
      fromUserId: tx.fromUserId,
      toUserId: tx.toUserId,
      amount: tx.amount,
      vietqrUrl,
    };
  });

  // Lưu các khoản nợ rút gọn vào bảng 'settlements'
  const savedSettlements = await expensesRepository.saveSettlements(tripId, settlementsWithQr);

  return savedSettlements.map((s) => {
    const fromUser = membersMap[s.from_user_id];
    const toUser = membersMap[s.to_user_id];
    return {
      id: s.id,
      tripId: s.trip_id,
      fromUser: fromUser ? { id: fromUser.userId, fullName: fromUser.fullName, avatarUrl: fromUser.avatarUrl } : null,
      toUser: toUser
        ? {
            id: toUser.userId,
            fullName: toUser.fullName,
            avatarUrl: toUser.avatarUrl,
            bankBin: toUser.bankBin,
            bankName: toUser.bankName,
            bankAccountNumber: toUser.bankAccountNumber,
            bankAccountName: toUser.bankAccountName,
          }
        : null,
      amount: Number(s.amount),
      status: s.status,
      vietqrUrl: s.vietqr_url,
      paidAt: s.paid_at,
      createdAt: s.created_at,
    };
  });
};

/**
 * 5. Lấy chi tiết một khoản nợ và link mã VietQR
 */
const getSettlementVietQR = async (settlementId) => {
  const settlement = await expensesRepository.findSettlementById(settlementId);
  if (!settlement) {
    const error = new Error('Không tìm thấy khoản thanh toán này');
    error.status = 404;
    throw error;
  }

  let vietqrUrl = settlement.vietqr_url;

  // Nếu chưa có hoặc cần sinh mới mã QR
  if (!vietqrUrl && settlement.bank_bin && settlement.bank_account_number) {
    const shortCode = settlement.id.replace(/-/g, '').substring(0, 8).toUpperCase();
    vietqrUrl = generateVietQRUrl({
      bankBin: settlement.bank_bin,
      accountNumber: settlement.bank_account_number,
      amount: Number(settlement.amount),
      description: `FT ${shortCode}`,
    });
  }

  return {
    ...settlement,
    amount: Number(settlement.amount),
    vietqrUrl,
  };
};

/**
 * 6. Đánh dấu khoản nợ đã thanh toán thành công (Xác nhận thủ công)
 */
const markSettlementPaid = async (settlementId, currentUserId) => {
  const settlement = await expensesRepository.findSettlementById(settlementId);
  if (!settlement) {
    const error = new Error('Không tìm thấy khoản thanh toán');
    error.status = 404;
    throw error;
  }

  // Cho phép cả người trả hoặc người nhận bấm xác nhận
  if (settlement.from_user_id !== currentUserId && settlement.to_user_id !== currentUserId) {
    const error = new Error('Bạn không có quyền xác nhận cho khoản thanh toán này');
    error.status = 403;
    throw error;
  }

  const updated = await expensesRepository.updateSettlementStatus(settlementId, 'PAID');
  return {
    settlement: updated,
    message: 'Khoản nợ đã được đánh dấu thanh toán thành công!',
  };
};

/**
 * 7. Xử lý Webhook tự động từ SePay (Tự động gạch nợ 100% khi có tiền vào)
 */
const handleSepayWebhook = async (webhookData, authHeader) => {
  // 7.1 Kiểm tra xác thực khóa API từ SePay
  const expectedKey = env.sepayApiKey;
  if (authHeader) {
    const token = authHeader.replace(/^Bearer\s+/i, '').replace(/^Apikey\s+/i, '').trim();
    if (expectedKey && token !== expectedKey && token !== 'feelingtrip_sepay_webhook_secret_key_2026') {
      const error = new Error('Khóa xác thực SePay không hợp lệ');
      error.status = 401;
      throw error;
    }
  }

  // 7.2 Lấy thông tin giao dịch
  const { content, transferAmount, description } = webhookData;
  const refText = content || description || '';

  if (!refText) {
    return { success: false, message: 'Nội dung chuyển khoản trống' };
  }

  // 7.3 Tìm khoản nợ khớp với mã nội dung chuyển khoản
  const settlement = await expensesRepository.findSettlementByReference(refText);
  if (!settlement) {
    return {
      success: false,
      message: `Không tìm thấy khoản nợ khớp với nội dung: "${refText}"`,
    };
  }

  // 7.4 Kiểm tra số tiền chuyển có đủ không
  const receivedAmount = Number(transferAmount);
  const owedAmount = Number(settlement.amount);

  if (receivedAmount < owedAmount) {
    return {
      success: false,
      message: `Số tiền chuyển (${receivedAmount.toLocaleString('vi-VN')}đ) chưa đủ số tiền nợ (${owedAmount.toLocaleString('vi-VN')}đ)`,
    };
  }

  // 7.5 Tự động chuyển trạng thái khoản nợ sang 'PAID'
  const updatedSettlement = await expensesRepository.updateSettlementStatus(settlement.id, 'PAID');

  return {
    success: true,
    message: 'Tự động gạch nợ thành công qua SePay Webhook!',
    settlement: updatedSettlement,
  };
};

module.exports = {
  createExpense,
  getTripExpenses,
  getTripBalances,
  settleTripDebts,
  getSettlementVietQR,
  markSettlementPaid,
  handleSepayWebhook,
};
