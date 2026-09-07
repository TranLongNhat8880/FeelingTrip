const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Itineraries & Smart Swap (src/features/itineraries/)
// Quy tắc kiểm tra dữ liệu lịch trình ngày, địa điểm dừng chân, sắp xếp & smart swap
// ============================================================================

const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)(:([0-5]\d))?$/;

/**
 * Thêm hoạt động/địa điểm vào một ngày lịch trình
 */
const createItineraryItemSchema = Joi.object({
  placeId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).allow(null).messages({
    'string.guid': 'Mã địa điểm (placeId) phải là UUID hợp lệ',
  }),
  customName: Joi.string().trim().min(1).max(255).required().messages({
    'string.empty': 'Tên hoạt động/địa điểm không được để trống',
    'string.max': 'Tên hoạt động không được vượt quá 255 ký tự',
    'any.required': 'Tên hoạt động/địa điểm là bắt buộc',
  }),
  customAddress: Joi.string().trim().allow(null, ''),
  startTime: Joi.string().pattern(TIME_REGEX).allow(null).messages({
    'string.pattern.base': 'Thời gian bắt đầu phải theo định dạng HH:mm (VD: 08:30)',
  }),
  endTime: Joi.string().pattern(TIME_REGEX).allow(null).messages({
    'string.pattern.base': 'Thời gian kết thúc phải theo định dạng HH:mm (VD: 10:30)',
  }),
  orderIndex: Joi.number().integer().min(0).default(0),
  note: Joi.string().trim().max(1000).allow(null, '').messages({
    'string.max': 'Ghi chú không được vượt quá 1000 ký tự',
  }),
  estimatedCost: Joi.number().min(0).default(0).messages({
    'number.min': 'Chi phí ước tính không được âm',
  }),
});

/**
 * Cập nhật một hoạt động trong lịch trình
 */
const updateItineraryItemSchema = Joi.object({
  customName: Joi.string().trim().min(1).max(255),
  customAddress: Joi.string().trim().allow(null, ''),
  startTime: Joi.string().pattern(TIME_REGEX).allow(null),
  endTime: Joi.string().pattern(TIME_REGEX).allow(null),
  orderIndex: Joi.number().integer().min(0),
  note: Joi.string().trim().max(1000).allow(null, ''),
  estimatedCost: Joi.number().min(0),
  isCompleted: Joi.boolean(),
}).min(1).messages({
  'object.min': 'Vui lòng cung cấp ít nhất một thông tin cần cập nhật',
});

/**
 * Cập nhật thứ tự hiển thị các hoạt động trong ngày (Drag & Drop Reorder)
 */
const reorderItemsSchema = Joi.object({
  items: Joi.array()
    .items(
      Joi.object({
        itemId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
          'string.guid': 'Mã hoạt động (itemId) phải là UUID hợp lệ',
          'any.required': 'Mã hoạt động (itemId) là bắt buộc',
        }),
        orderIndex: Joi.number().integer().min(0).required().messages({
          'number.base': 'Thứ tự (orderIndex) phải là một số nguyên',
          'any.required': 'Thứ tự sắp xếp (orderIndex) là bắt buộc',
        }),
      })
    )
    .min(1)
    .required()
    .messages({
      'array.base': 'Danh sách sắp xếp phải là một mảng',
      'array.min': 'Vui lòng cung cấp ít nhất 1 phần tử cần sắp xếp',
      'any.required': 'Danh sách sắp xếp (items) là bắt buộc',
    }),
});

/**
 * Áp dụng tính năng Smart Swap (Đổi địa điểm B sang điểm B+ tương đương lân cận)
 */
const smartSwapApplySchema = Joi.object({
  itemId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã hoạt động (itemId) phải là UUID hợp lệ',
    'any.required': 'Mã hoạt động cần đổi (itemId) là bắt buộc',
  }),
  newPlaceId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã địa điểm thay thế (newPlaceId) phải là UUID hợp lệ',
    'any.required': 'Mã địa điểm mới (newPlaceId) là bắt buộc',
  }),
});

/**
 * Nhân bản lịch trình từ chuyến đi khác (Clone / Fork Plan)
 */
const clonePlanSchema = Joi.object({
  targetTripId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã chuyến đi đích (targetTripId) phải là UUID hợp lệ',
    'any.required': 'Mã chuyến đi đích (targetTripId) là bắt buộc',
  }),
});

/**
 * Params Schemas
 */
const tripIdParamSchema = Joi.object({
  tripId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã chuyến đi (tripId) phải là UUID hợp lệ',
  }),
});

const dayIdParamSchema = Joi.object({
  dayId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã ngày lịch trình (dayId) phải là UUID hợp lệ',
  }),
});

const itemIdParamSchema = Joi.object({
  itemId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã hoạt động (itemId) phải là UUID hợp lệ',
  }),
});

const placeIdParamSchema = Joi.object({
  placeId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã địa điểm (placeId) phải là UUID hợp lệ',
  }),
});

module.exports = {
  createItineraryItemSchema,
  updateItineraryItemSchema,
  reorderItemsSchema,
  smartSwapApplySchema,
  clonePlanSchema,
  tripIdParamSchema,
  dayIdParamSchema,
  itemIdParamSchema,
  placeIdParamSchema,
};
