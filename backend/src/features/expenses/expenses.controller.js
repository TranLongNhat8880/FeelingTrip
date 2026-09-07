const expensesService = require('./expenses.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: Expenses & Split Bill
// Tiếp nhận Request từ Client, gọi Service xử lý nghiệp vụ và trả Response chuẩn
// ============================================================================

/**
 * [POST] /api/v1/expenses
 * Tạo khoản chi tiêu mới và phân bổ số tiền nợ cho các thành viên
 */
const createExpense = async (req, res, next) => {
  try {
    const payerId = req.body.payerId || req.user.id;
    const expenseData = { ...req.body, payerId };
    const result = await expensesService.createExpense(expenseData, req.user.id);
    return sendSuccess(res, result, 'Tạo khoản chi tiêu thành công', HTTP_STATUS.CREATED);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [GET] /api/v1/expenses/trip/:tripId
 * Lấy danh sách toàn bộ các khoản chi và ngân sách chuyến đi
 */
const getTripExpenses = async (req, res, next) => {
  try {
    const { tripId } = req.params;
    const result = await expensesService.getTripExpenses(tripId, req.user.id);
    return sendSuccess(res, result, 'Lấy danh sách chi tiêu thành công', HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [GET] /api/v1/expenses/trip/:tripId/balances
 * Xem bảng cân đối tài chính cá nhân (Số dư ròng = Đã trả - Phải chịu)
 */
const getTripBalances = async (req, res, next) => {
  try {
    const { tripId } = req.params;
    const result = await expensesService.getTripBalances(tripId, req.user.id);
    return sendSuccess(res, result, 'Lấy bảng cân đối tài chính thành công', HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/expenses/trip/:tripId/settle
 * Chạy thuật toán Min Cash Flow rút gọn nợ & sinh mã VietQR thanh toán
 */
const settleTripDebts = async (req, res, next) => {
  try {
    const { tripId } = req.params;
    const result = await expensesService.settleTripDebts(tripId, req.user.id);
    return sendSuccess(res, result, 'Tính toán và rút gọn công nợ thành công', HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [GET] /api/v1/expenses/settlement/:id/vietqr
 * Lấy chi tiết một khoản nợ và link mã ảnh VietQR để quét
 */
const getSettlementVietQR = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await expensesService.getSettlementVietQR(id, req.user.id);
    return sendSuccess(res, result, 'Lấy mã VietQR thanh toán thành công', HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [PUT] /api/v1/expenses/settlement/:id/paid
 * Đánh dấu khoản nợ đã thanh toán thành công (Xác nhận thủ công)
 */
const markSettlementPaid = async (req, res, next) => {
  try {
    const { id } = req.params;
    const currentUserId = req.user.id;
    const result = await expensesService.markSettlementPaid(id, currentUserId);
    return sendSuccess(res, result.settlement, result.message, HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/expenses/webhook/sepay
 * Webhook tự động nhận thông báo biến động số dư từ SePay để tự động gạch nợ 100%
 */
const handleSepayWebhook = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const result = await expensesService.handleSepayWebhook(req.body, authHeader);
    return sendSuccess(res, result, result.message, HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
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

module.exports.confirmSettlement = async (req,res,next) => {
  try {
    const result = await expensesService.confirmSettlement(req.params.id, req.user.id);
    return sendSuccess(res, result.settlement, result.message);
  } catch (error) { next(error); }
};
module.exports.updateBudget = async (req,res,next) => {
  try {
    const result = await expensesService.updateBudget(req.params.tripId, req.user.id, req.body.estimatedBudget);
    return sendSuccess(res, result, 'Cập nhật ngân sách thành công');
  } catch (error) { next(error); }
};
