const Joi = require('joi');

// ============================================================================
// VALIDATION: Itineraries
// Xác thực dữ liệu đầu vào cho API Itineraries
// ============================================================================

const UUID = Joi.string().guid({ version: ['uuidv4', 'uuidv5'] });
const TIME = Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/);
const VERSION = Joi.date().iso();
/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 */
const CATEGORIES = ['ATTRACTION', 'RESTAURANT', 'CAFE', 'HOTEL', 'ENTERTAINMENT', 'NATURE', 'CULTURE', 'SHOPPING', 'OTHER'];

const createDaySchema = Joi.object({
  dayNumber: Joi.number().integer().min(1).required(),
  title: Joi.string().trim().max(255).allow(null, ''),
});

const updateDaySchema = Joi.object({
  title: Joi.string().trim().max(255).allow(null, '').required(),
  expectedUpdatedAt: VERSION.required(),
});

const createItineraryItemSchema = Joi.object({
  placeId: UUID.allow(null),
  customName: Joi.string().trim().min(1).max(255).required(),
  customAddress: Joi.string().trim().allow(null, ''),
  category: Joi.string().valid(...CATEGORIES).when('placeId', { is: null, then: Joi.required(), otherwise: Joi.optional() }),
  startTime: TIME.required(),
  endTime: TIME.required(),
  note: Joi.string().trim().max(1000).allow(null, ''),
  estimatedCost: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER).default(0),
  orderIndex: Joi.forbidden(),
  isCompleted: Joi.forbidden(),
}).custom((value, helpers) => value.startTime >= value.endTime
  ? helpers.error('time.range') : value).messages({ 'time.range': 'Thời gian bắt đầu phải trước thời gian kết thúc' });

const updateItineraryItemSchema = Joi.object({
  customName: Joi.string().trim().min(1).max(255),
  customAddress: Joi.string().trim().allow(null, ''),
  category: Joi.string().valid(...CATEGORIES),
  startTime: TIME,
  endTime: TIME,
  note: Joi.string().trim().max(1000).allow(null, ''),
  estimatedCost: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER),
  expectedUpdatedAt: VERSION.required(),
  placeId: Joi.forbidden(),
  orderIndex: Joi.forbidden(),
  isCompleted: Joi.forbidden(),
}).min(2);

const deleteItemSchema = Joi.object({ expectedUpdatedAt: VERSION });
const completionSchema = Joi.object({
  isCompleted: Joi.boolean().required(),
  expectedUpdatedAt: VERSION.required(),
});

const swapQuerySchema = Joi.object({
  radiusKm: Joi.number().min(0.5).max(20).default(3),
  limit: Joi.number().integer().min(1).max(20).default(10),
});

const smartSwapApplySchema = Joi.object({
  newPlaceId: UUID.required(),
  candidateToken: Joi.string().min(20).max(4096).required(),
  expectedUpdatedAt: VERSION.required(),
});
/**
 * @description Kiểm tra tính hợp lệ của lịch trình.
 * @param {string} { itemId: UUID.required(
 */
const legacySmartSwapApplySchema = smartSwapApplySchema.keys({ itemId: UUID.required() });

const clonePlanSchema = Joi.object({ targetTripId: UUID.required() });
const publicListQuerySchema = Joi.object({
  destination: Joi.string().trim().max(100),
  durationDays: Joi.number().integer().min(1).max(365),
  keyword: Joi.string().trim().max(100),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(50).default(20),
});

const tripIdParamSchema = Joi.object({ tripId: UUID.required() });
const dayIdParamSchema = Joi.object({ dayId: UUID.required() });
const itemIdParamSchema = Joi.object({ itemId: UUID.required() });
const sourceTripIdParamSchema = Joi.object({ sourceTripId: UUID.required() });

module.exports = {
  CATEGORIES, createDaySchema, updateDaySchema, createItineraryItemSchema,
  updateItineraryItemSchema, deleteItemSchema, completionSchema, swapQuerySchema,
  smartSwapApplySchema, legacySmartSwapApplySchema, clonePlanSchema, publicListQuerySchema,
  tripIdParamSchema, dayIdParamSchema, itemIdParamSchema, sourceTripIdParamSchema,
};
