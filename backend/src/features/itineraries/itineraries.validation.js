const Joi = require('joi');

// ============================================================================
// VALIDATION: Itineraries
// Xác thực dữ liệu đầu vào cho API Itineraries
// ============================================================================

const UUID = Joi.string().guid({ version: ['uuidv4', 'uuidv5'] });
const TIME = Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/);
const ROW_VERSION = Joi.string().pattern(/^\d+$/);
const DATE = Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).custom((value, helpers) => {
  const parsed = new Date(`${value}T00:00:00Z`);
  return Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value
    ? helpers.error('date.format') : value;
});
/**
 * @description Thực thi logic nghiệp vụ cho lịch trình.
 */
const CATEGORIES = ['ATTRACTION', 'RESTAURANT', 'CAFE', 'HOTEL', 'ENTERTAINMENT', 'NATURE', 'CULTURE', 'SHOPPING', 'OTHER'];
const LOCATION_SOURCES = ['CATALOG', 'GEOAPIFY', 'MANUAL'];

const LATITUDE = Joi.number().min(-90).max(90);
const LONGITUDE = Joi.number().min(-180).max(180);

const createDaySchema = Joi.object({
  dayNumber: Joi.number().integer().min(1).required(),
  title: Joi.string().trim().max(255).allow(null, ''),
});

const updateDaySchema = Joi.object({
  title: Joi.string().trim().max(255).allow(null, '').required(),
  expectedVersion: ROW_VERSION.required(),
});

/**
 * Quy ước locationSource:
 *   - CATALOG  : item liên kết với bảng places nội bộ (placeId UUID bắt buộc)
 *   - GEOAPIFY : item từ kết quả tìm kiếm Geoapify (cần externalProvider, externalPlaceId, lat/lng)
 *   - MANUAL   : nhập tay (tọa độ tùy chọn, nếu có phải đi theo cặp)
 *
 * Backward-compatibility:
 *   - Request có placeId nhưng không có locationSource → hiểu là CATALOG
 *   - Request không có placeId và không có locationSource → hiểu là MANUAL
 */
const createItineraryItemSchema = Joi.object({
  placeId: UUID.allow(null),
  locationSource: Joi.string().valid(...LOCATION_SOURCES).allow(null),
  externalProvider: Joi.string().trim().max(50).allow(null),
  externalPlaceId: Joi.string().trim().max(500).allow(null),
  latitude: LATITUDE.allow(null),
  longitude: LONGITUDE.allow(null),
  customName: Joi.string().trim().min(1).max(255).required(),
  customAddress: Joi.string().trim().allow(null, ''),
  category: Joi.string().valid(...CATEGORIES).when('placeId', { is: null, then: Joi.required(), otherwise: Joi.optional() }),
  startTime: TIME.required(),
  endTime: TIME.required(),
  note: Joi.string().trim().max(1000).allow(null, ''),
  estimatedCost: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER).default(0),
  orderIndex: Joi.forbidden(),
  isCompleted: Joi.forbidden(),
}).custom((value, helpers) => {
  if (value.startTime >= value.endTime) return helpers.error('time.range');
  // Backward-compat: infer locationSource
  if (!value.locationSource) {
    value.locationSource = value.placeId ? 'CATALOG' : 'MANUAL';
  }
  // CATALOG: placeId bắt buộc
  if (value.locationSource === 'CATALOG') {
    if (!value.placeId) return helpers.message('placeId bắt buộc khi nguồn là CATALOG');
  }
  // GEOAPIFY: placeId phải null; externalProvider, externalPlaceId, lat/lng bắt buộc
  if (value.locationSource === 'GEOAPIFY') {
    if (value.placeId) return helpers.message('placeId phải null khi nguồn là GEOAPIFY');
    if (!value.externalProvider) value.externalProvider = 'GEOAPIFY';
    if (value.externalProvider !== 'GEOAPIFY') return helpers.message('externalProvider phải là GEOAPIFY');
    if (!value.externalPlaceId) return helpers.message('externalPlaceId bắt buộc khi nguồn là GEOAPIFY');
    if (value.latitude == null || value.longitude == null) return helpers.message('Tọa độ bắt buộc khi nguồn là GEOAPIFY');
  }
  // MANUAL: tọa độ tùy chọn nhưng phải đi theo cặp
  if (value.locationSource === 'MANUAL') {
    if (value.placeId) return helpers.message('placeId phải null khi nguồn là MANUAL');
    if ((value.latitude == null) !== (value.longitude == null)) return helpers.message('latitude và longitude phải đi theo cặp');
  }
  return value;
}).messages({ 'time.range': 'Thời gian bắt đầu phải trước thời gian kết thúc' });

const updateItineraryItemSchema = Joi.object({
  customName: Joi.string().trim().min(1).max(255),
  customAddress: Joi.string().trim().allow(null, ''),
  category: Joi.string().valid(...CATEGORIES),
  locationSource: Joi.string().valid(...LOCATION_SOURCES),
  externalProvider: Joi.string().trim().max(50).allow(null),
  externalPlaceId: Joi.string().trim().max(500).allow(null),
  latitude: LATITUDE.allow(null),
  longitude: LONGITUDE.allow(null),
  startTime: TIME,
  endTime: TIME,
  note: Joi.string().trim().max(1000).allow(null, ''),
  estimatedCost: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER),
  expectedVersion: ROW_VERSION.required(),
  orderIndex: Joi.forbidden(),
  isCompleted: Joi.forbidden(),
}).min(2).custom((value, helpers) => {
  // Tọa độ phải đi theo cặp
  if (value.latitude !== undefined || value.longitude !== undefined) {
    if ((value.latitude == null) !== (value.longitude == null)) {
      return helpers.message('latitude và longitude phải đi theo cặp');
    }
  }
  // GEOAPIFY constraints khi cập nhật source
  if (value.locationSource === 'GEOAPIFY') {
    if (value.externalProvider && value.externalProvider !== 'GEOAPIFY') return helpers.message('externalProvider phải là GEOAPIFY');
    if (value.externalPlaceId === '') return helpers.message('externalPlaceId bắt buộc khi nguồn là GEOAPIFY');
    if ((value.latitude !== undefined && value.latitude == null) || (value.longitude !== undefined && value.longitude == null)) {
      return helpers.message('Tọa độ bắt buộc khi nguồn là GEOAPIFY');
    }
  }
  return value;
});

const deleteItemSchema = Joi.object({ expectedVersion: ROW_VERSION.required() });
const completionSchema = Joi.object({
  isCompleted: Joi.boolean().required(),
  expectedVersion: ROW_VERSION.required(),
});

const swapQuerySchema = Joi.object({
  radiusKm: Joi.number().min(0.5).max(20).default(3),
  limit: Joi.number().integer().min(1).max(20).default(10),
});

const smartSwapApplySchema = Joi.object({
  newPlaceId: UUID.required(),
  candidateToken: Joi.string().min(20).max(4096).required(),
  expectedVersion: ROW_VERSION.required(),
});
/**
 * @description Kiểm tra tính hợp lệ của lịch trình.
 */
const legacySmartSwapApplySchema = smartSwapApplySchema.keys({ itemId: UUID.required() });

const clonePlanSchema = Joi.object({
  startDate: DATE.required(),
  name: Joi.string().trim().min(2).max(255),
});
const reorderItemsSchema = Joi.object({
  orderedItemIds: Joi.array().items(UUID.required()).min(1).unique().required(),
  expectedVersion: ROW_VERSION.required(),
});
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
  CATEGORIES, LOCATION_SOURCES, createDaySchema, updateDaySchema, createItineraryItemSchema,
  updateItineraryItemSchema, deleteItemSchema, completionSchema, swapQuerySchema,
  smartSwapApplySchema, legacySmartSwapApplySchema, clonePlanSchema, reorderItemsSchema,
  publicListQuerySchema,
  tripIdParamSchema, dayIdParamSchema, itemIdParamSchema, sourceTripIdParamSchema,
};

