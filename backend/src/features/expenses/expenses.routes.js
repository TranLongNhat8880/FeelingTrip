const express = require('express');
const router = express.Router();
const expensesController = require('./expenses.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const {
  createExpenseSchema,
  tripIdParamSchema,
  settlementIdParamSchema,
} = require('./expenses.validation');

// ============================================================================
// ROUTES: Expenses & Split Bill (/api/v1/expenses)
// Phân hệ quản lý chi tiêu, chia hóa đơn (Split Bill), rút gọn nợ & VietQR
// ============================================================================

// 1. Quản lý chi tiêu trong chuyến đi
router.post(
  '/',
  authenticate,
  validate(createExpenseSchema),
  expensesController.createExpense
);

router.get(
  '/trip/:tripId',
  authenticate,
  validate({ params: tripIdParamSchema }),
  expensesController.getTripExpenses
);

// 2. Cân đối tài chính & Thuật toán rút gọn nợ (Min Cash Flow)
router.get(
  '/trip/:tripId/balances',
  authenticate,
  validate({ params: tripIdParamSchema }),
  expensesController.getTripBalances
);

router.post(
  '/trip/:tripId/settle',
  authenticate,
  validate({ params: tripIdParamSchema }),
  expensesController.settleTripDebts
);

// 3. Thanh toán & VietQR
router.get(
  '/settlement/:id/vietqr',
  authenticate,
  validate({ params: settlementIdParamSchema }),
  expensesController.getSettlementVietQR
);

router.put(
  '/settlement/:id/paid',
  authenticate,
  validate({ params: settlementIdParamSchema }),
  expensesController.markSettlementPaid
);

// 4. Webhook tự động gạch nợ từ SePay (Công khai, xác thực qua API Key Header)
router.post('/webhook/sepay', expensesController.handleSepayWebhook);

module.exports = router;
