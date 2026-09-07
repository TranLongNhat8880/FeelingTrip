const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Places & Maps (src/features/places/)
// Quy tắc kiểm tra tìm kiếm địa điểm, thêm địa điểm mới, tính khoảng cách & lộ trình
// ============================================================================

const PLACE_CATEGORIES = [
  'ATTRACTION',
  'RESTAURANT',
  'CAFE',
  'HOTEL',
  'ENTERTAINMENT',
  'NATURE',
  'CULTURE',
  'OTHER',
];

/**
 * Tìm kiếm và lọc danh sách địa điểm
 */
const searchPlacesQuerySchema = Joi.object({
  keyword: Joi.string().trim().max(100).allow(''),
  destination: Joi.string().trim().max(100).allow(''),
  category: Joi.string().valid(...PLACE_CATEGORIES),
  priceLevel: Joi.number().integer().min(1).max(4),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

/**
 * Thêm địa điểm du lịch / ăn uống mới
 */
const createPlaceSchema = Joi.object({
  name: Joi.string().trim().min(2).max(255).required().messages({
    'string.empty': 'Tên địa điểm không được để trống',
    'any.required': 'Tên địa điểm là bắt buộc',
  }),
  destination: Joi.string().trim().min(2).max(100).required().messages({
    'string.empty': 'Tỉnh/Thành phố (destination) không được để trống',
    'any.required': 'Tỉnh/Thành phố là bắt buộc',
  }),
  address: Joi.string().trim().allow(null, ''),
  category: Joi.string().valid(...PLACE_CATEGORIES).required().messages({
    'any.only': `Danh mục phải là một trong các giá trị: ${PLACE_CATEGORIES.join(', ')}`,
    'any.required': 'Danh mục địa điểm là bắt buộc',
  }),
  latitude: Joi.number().min(-90).max(90).allow(null).messages({
    'number.min': 'Vĩ độ (latitude) phải nằm trong khoảng -90 đến 90',
    'number.max': 'Vĩ độ (latitude) phải nằm trong khoảng -90 đến 90',
  }),
  longitude: Joi.number().min(-180).max(180).allow(null).messages({
    'number.min': 'Kinh độ (longitude) phải nằm trong khoảng -180 đến 180',
    'number.max': 'Kinh độ (longitude) phải nằm trong khoảng -180 đến 180',
  }),
  imageUrl: Joi.string().uri().allow(null, '').messages({
    'string.uri': 'Đường dẫn ảnh địa điểm không hợp lệ',
  }),
  priceLevel: Joi.number().integer().min(1).max(4).default(1).messages({
    'number.min': 'Mức giá từ 1 (Rẻ) đến 4 (Rất đắt)',
    'number.max': 'Mức giá từ 1 (Rẻ) đến 4 (Rất đắt)',
  }),
  avgDurationMinutes: Joi.number().integer().min(10).max(720).default(60).messages({
    'number.min': 'Thời lượng tham quan trung bình tối thiểu là 10 phút',
    'number.max': 'Thời lượng tham quan tối đa là 720 phút (12 tiếng)',
  }),
});

/**
 * Tính khoảng cách giữa 2 tọa độ (Query params)
 */
const distanceQuerySchema = Joi.object({
  originLat: Joi.number().min(-90).max(90).required().messages({
    'any.required': 'Vĩ độ điểm xuất phát (originLat) là bắt buộc',
  }),
  originLng: Joi.number().min(-180).max(180).required().messages({
    'any.required': 'Kinh độ điểm xuất phát (originLng) là bắt buộc',
  }),
  destLat: Joi.number().min(-90).max(90).required().messages({
    'any.required': 'Vĩ độ điểm đến (destLat) là bắt buộc',
  }),
  destLng: Joi.number().min(-180).max(180).required().messages({
    'any.required': 'Kinh độ điểm đến (destLng) là bắt buộc',
  }),
});

/**
 * Tối ưu hóa lộ trình di chuyển qua nhiều địa điểm
 */
const optimizeRouteSchema = Joi.object({
  placeIds: Joi.array()
    .items(Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }))
    .min(2)
    .max(20)
    .required()
    .messages({
      'array.min': 'Cần ít nhất 2 địa điểm để tối ưu hóa lộ trình',
      'array.max': 'Tối đa 20 địa điểm cho 1 lần tối ưu lộ trình',
      'any.required': 'Danh sách địa điểm (placeIds) là bắt buộc',
    }),
  startPlaceId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).allow(null),
});

/**
 * Params Schemas
 */
const placeIdParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã địa điểm (id) phải là UUID hợp lệ',
  }),
});

module.exports = {
  searchPlacesQuerySchema,
  createPlaceSchema,
  distanceQuerySchema,
  optimizeRouteSchema,
  placeIdParamSchema,
};
