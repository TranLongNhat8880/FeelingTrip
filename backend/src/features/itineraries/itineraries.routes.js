const express = require('express');
const controller = require('./itineraries.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const v = require('./itineraries.validation');

const router = express.Router();
router.use(authenticate);

const deprecated = replacement => (req, res, next) => {
  res.set('Warning', `299 - "Deprecated API; use ${replacement}"`);
  next();
};

// ============================================================================
// ROUTES: Itineraries (/api/v1/itineraries)
// Lên lịch trình, quản lý hoạt động, clone plan và smart swap
// ============================================================================

// --- Lịch trình cộng đồng (Public Plans) & Clone ---
router.get('/public', validate({ query: v.publicListQuerySchema }), controller.listPublic);
router.get('/public/:sourceTripId',
  validate({ params: v.sourceTripIdParamSchema }), controller.getPublic);
router.post('/public/:sourceTripId/clone',
  validate({ params: v.sourceTripIdParamSchema, body: v.clonePlanSchema }), controller.clonePlan);

// --- Lịch trình theo ngày ---
router.get('/trips/:tripId', validate({ params: v.tripIdParamSchema }), controller.getItineraries);
router.post('/trips/:tripId/days',
  validate({ params: v.tripIdParamSchema, body: v.createDaySchema }), controller.createDay);
router.get('/days/:dayId', validate({ params: v.dayIdParamSchema }), controller.getDay);
router.patch('/days/:dayId',
  validate({ params: v.dayIdParamSchema, body: v.updateDaySchema }), controller.updateDay);

// --- Quản lý các hoạt động (Itinerary Items) ---
router.get('/items/:itemId', validate({ params: v.itemIdParamSchema }), controller.getItem);
router.post('/days/:dayId/items',
  validate({ params: v.dayIdParamSchema, body: v.createItineraryItemSchema }), controller.addItem);
router.patch('/items/:itemId',
  validate({ params: v.itemIdParamSchema, body: v.updateItineraryItemSchema }), controller.updateItem);
router.delete('/items/:itemId',
  validate({ params: v.itemIdParamSchema, body: v.deleteItemSchema }), controller.deleteItem);
router.patch('/items/:itemId/completion',
  validate({ params: v.itemIdParamSchema, body: v.completionSchema }), controller.setCompletion);

// --- Tính năng Smart Swap ---
router.get('/items/:itemId/swap-candidates',
  validate({ params: v.itemIdParamSchema, query: v.swapQuerySchema }), controller.getSwapCandidates);
router.post('/items/:itemId/swap',
  validate({ params: v.itemIdParamSchema, body: v.smartSwapApplySchema }), controller.applySmartSwap);

// ============================================================================
// TEMPORARY COMPATIBILITY ALIASES
// Các đường dẫn cũ (legacy), gọi cùng service gốc. Chức năng reorder đã bị bỏ.
// ============================================================================
router.get('/trip/:tripId', deprecated('GET /api/v1/itineraries/trips/:tripId'),
  validate({ params: v.tripIdParamSchema }), controller.getItineraries);
router.post('/:dayId/items', deprecated('POST /api/v1/itineraries/days/:dayId/items'),
  validate({ params: v.dayIdParamSchema, body: v.createItineraryItemSchema }), controller.addItem);
router.put('/items/:itemId', deprecated('PATCH /api/v1/itineraries/items/:itemId'),
  validate({ params: v.itemIdParamSchema, body: v.updateItineraryItemSchema }), controller.updateItem);
router.get('/smart-swap/:itemId', deprecated('GET /api/v1/itineraries/items/:itemId/swap-candidates'),
  validate({ params: v.itemIdParamSchema, query: v.swapQuerySchema }), controller.getSwapCandidates);
router.post('/smart-swap/apply', deprecated('POST /api/v1/itineraries/items/:itemId/swap'),
  validate(v.legacySmartSwapApplySchema), controller.legacyApplySmartSwap);
router.post('/clone/:sourceTripId', deprecated('POST /api/v1/itineraries/public/:sourceTripId/clone'),
  validate({ params: v.sourceTripIdParamSchema, body: v.clonePlanSchema }), controller.clonePlan);

module.exports = router;
