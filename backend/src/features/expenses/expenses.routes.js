const express = require('express');
const router = express.Router();
const expensesController = require('./expenses.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const {
  createExpenseSchema,
  budgetSchema,
  tripIdParamSchema,
  settlementIdParamSchema,
  linkExpenseSchema,
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
router.put('/:id/itinerary-item', authenticate,
  validate({params:settlementIdParamSchema,body:linkExpenseSchema}),expensesController.linkExpenseToItem);

router.get(
  '/trip/:tripId',
  authenticate,
  validate({ params: tripIdParamSchema }),
  expensesController.getTripExpenses
);

// 2. Cân đối tài chính & Thuật toán rút gọn nợ (Min Cash Flow)
router.get('/trip/:tripId/settlements', authenticate,
  validate({ params: tripIdParamSchema }), expensesController.getTripSettlements);
router.get('/trip/:tripId/planned-costs', authenticate,
  validate({ params: tripIdParamSchema }), expensesController.getPlannedCosts);
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

router.get('/settlement/:id/status', authenticate, validate({ params: settlementIdParamSchema }),
  async (req,res,next) => {
    try {
      const data = await require('./expenses.service').getPaymentStatus(req.params.id,req.user.id);
      res.set('Cache-Control','no-store');
      return require('../../shared/utils/response.util').sendSuccess(res,data);
    } catch (error) { next(error); }
  });

router.put(
  '/settlement/:id/paid',
  authenticate,
  validate({ params: settlementIdParamSchema }),
  expensesController.markSettlementPaid
);

// 4. Webhook tự động gạch nợ từ SePay (Công khai, xác thực qua API Key Header)
router.post('/webhook/sepay', expensesController.handleSepayWebhook);

router.put('/settlement/:id/confirm', authenticate, validate({params: settlementIdParamSchema}), expensesController.confirmSettlement);
router.put('/trip/:tripId/budget', authenticate, validate({params: tripIdParamSchema, body: budgetSchema}), expensesController.updateBudget);
module.exports = router;
