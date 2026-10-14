const Joi = require('joi');
const {
  PLACE_CATEGORIES,
} = require('../../shared/constants/categories');

// ============================================================================
// VALIDATION: Places, Maps, Distance & Route Optimization
// ============================================================================

const PLACE_CATEGORY_VALUES = Object.values(PLACE_CATEGORIES);

const latitudeSchema = Joi.number()
  .min(-90)
  .max(90)
  .messages({
    'number.base': 'Vĩ độ phải là số',
    'number.min': 'Vĩ độ phải nằm trong khoảng -90 đến 90',
    'number.max': 'Vĩ độ phải nằm trong khoảng -90 đến 90',
  });

const longitudeSchema = Joi.number()
  .min(-180)
  .max(180)
  .messages({
    'number.base': 'Kinh độ phải là số',
    'number.min': 'Kinh độ phải nằm trong khoảng -180 đến 180',
    'number.max': 'Kinh độ phải nằm trong khoảng -180 đến 180',
  });

const placeFields = {
  name: Joi.string()
    .trim()
    .min(2)
    .max(255)
    .messages({
      'string.empty': 'Tên địa điểm không được để trống',
      'string.min': 'Tên địa điểm phải có ít nhất 2 ký tự',
      'string.max': 'Tên địa điểm không được vượt quá 255 ký tự',
    }),

  destination: Joi.string()
    .trim()
    .min(2)
    .max(100)
    .messages({
      'string.empty': 'Tỉnh hoặc thành phố không được để trống',
      'string.min': 'Tên tỉnh hoặc thành phố phải có ít nhất 2 ký tự',
      'string.max': 'Tên tỉnh hoặc thành phố không được vượt quá 100 ký tự',
    }),

  address: Joi.string()
    .trim()
    .max(500)
    .allow(null, '')
    .messages({
      'string.max': 'Địa chỉ không được vượt quá 500 ký tự',
    }),

  category: Joi.string()
    .valid(...PLACE_CATEGORY_VALUES)
    .messages({
      'any.only':
        `Danh mục phải là một trong: ${PLACE_CATEGORY_VALUES.join(', ')}`,
    }),

  latitude: latitudeSchema.allow(null),
  longitude: longitudeSchema.allow(null),

  priceLevel: Joi.number()
    .integer()
    .min(1)
    .max(4)
    .messages({
      'number.integer': 'Mức giá phải là số nguyên',
      'number.min': 'Mức giá tối thiểu là 1',
      'number.max': 'Mức giá tối đa là 4',
    }),

  avgDurationMinutes: Joi.number()
    .integer()
    .min(10)
    .max(720)
    .messages({
      'number.integer': 'Thời lượng phải là số phút nguyên',
      'number.min': 'Thời lượng tối thiểu là 10 phút',
      'number.max': 'Thời lượng tối đa là 720 phút',
    }),
};

/**
 * Tìm kiếm địa điểm công khai.
 */
const searchPlacesQuerySchema = Joi.object({
  keyword: Joi.string().trim().max(100).allow(''),
  destination: Joi.string().trim().max(100).allow(''),

  category: Joi.string()
    .valid(...PLACE_CATEGORY_VALUES)
    .messages({
      'any.only':
        `Danh mục phải là một trong: ${PLACE_CATEGORY_VALUES.join(', ')}`,
    }),

  priceLevel: Joi.number().integer().min(1).max(4),

  sortBy: Joi.string()
    .valid('newest', 'nameAsc', 'ratingDesc')
    .default('newest'),

  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

/**
 * Danh sách quản lý dành cho Admin.
 *
 * Khác API công khai ở chỗ Admin có thể lọc isActive.
 */
const managePlacesQuerySchema = searchPlacesQuerySchema.keys({
  isActive: Joi.boolean(),
});

/**
 * Admin tạo địa điểm.
 *
 * Ảnh không nhận bằng imageUrl trong JSON.
 * URL ảnh được lấy từ multipart field "image" sau khi upload Cloudinary.
 */
const createPlaceSchema = Joi.object({
  ...placeFields,

  name: placeFields.name.required().messages({
    'string.empty': 'Tên địa điểm không được để trống',
    'any.required': 'Tên địa điểm là bắt buộc',
  }),

  destination: placeFields.destination.required().messages({
    'string.empty': 'Tỉnh hoặc thành phố không được để trống',
    'any.required': 'Tỉnh hoặc thành phố là bắt buộc',
  }),

  category: placeFields.category.required().messages({
    'any.only':
      `Danh mục phải là một trong: ${PLACE_CATEGORY_VALUES.join(', ')}`,
    'any.required': 'Danh mục địa điểm là bắt buộc',
  }),

  priceLevel: placeFields.priceLevel.default(1),
  avgDurationMinutes: placeFields.avgDurationMinutes.default(60),
})
  .and('latitude', 'longitude')
  .messages({
    'object.and': 'Phải cung cấp đồng thời cả latitude và longitude',
  });

/**
 * Admin cập nhật địa điểm.
 *
 * Không dùng .min(1) vì request có thể chỉ upload ảnh mới,
 * khi đó req.body rỗng và service sẽ kiểm tra req.file.
 */
const updatePlaceSchema = Joi.object({
  ...placeFields,
})
  .and('latitude', 'longitude')
  .messages({
    'object.and': 'Phải cung cấp đồng thời cả latitude và longitude',
  });

/**
 * Admin ẩn hoặc khôi phục địa điểm.
 */
const updatePlaceStatusSchema = Joi.object({
  isActive: Joi.boolean()
    .strict()
    .required()
    .messages({
      'boolean.base': 'isActive phải là true hoặc false',
      'any.required': 'isActive là bắt buộc',
    }),
});

/**
 * Tính khoảng cách giữa hai tọa độ.
 */
const distanceQuerySchema = Joi.object({
  originLat: latitudeSchema.required().messages({
    'any.required': 'Vĩ độ điểm xuất phát là bắt buộc',
  }),

  originLng: longitudeSchema.required().messages({
    'any.required': 'Kinh độ điểm xuất phát là bắt buộc',
  }),

  destLat: latitudeSchema.required().messages({
    'any.required': 'Vĩ độ điểm đến là bắt buộc',
  }),

  destLng: longitudeSchema.required().messages({
    'any.required': 'Kinh độ điểm đến là bắt buộc',
  }),

  travelMode: Joi.string()
    .valid('driving', 'walking', 'bicycling', 'transit')
    .default('driving'),
});

/**
 * Tối ưu thứ tự nhiều địa điểm.
 */
const optimizeRouteSchema = Joi.object({
  placeIds: Joi.array()
    .items(
      Joi.string().guid({
        version: ['uuidv4', 'uuidv5'],
      })
    )
    .unique()
    .min(2)
    .max(20)
    .required()
    .messages({
      'array.unique': 'Danh sách địa điểm không được chứa ID trùng nhau',
      'array.min': 'Cần ít nhất 2 địa điểm để tối ưu lộ trình',
      'array.max': 'Tối đa 20 địa điểm cho một lần tối ưu',
      'any.required': 'Danh sách placeIds là bắt buộc',
    }),

  startPlaceId: Joi.string()
    .guid({ version: ['uuidv4', 'uuidv5'] })
    .allow(null),

  travelMode: Joi.string()
    .valid('driving', 'walking', 'bicycling', 'transit')
    .default('driving'),
});

/**
 * Param ID địa điểm.
 */
const placeIdParamSchema = Joi.object({
  id: Joi.string()
    .guid({ version: ['uuidv4', 'uuidv5'] })
    .required()
    .messages({
      'string.guid': 'Mã địa điểm phải là UUID hợp lệ',
      'any.required': 'Mã địa điểm là bắt buộc',
    }),
});

module.exports = {
  searchPlacesQuerySchema,
  managePlacesQuerySchema,
  createPlaceSchema,
  updatePlaceSchema,
  updatePlaceStatusSchema,
  distanceQuerySchema,
  optimizeRouteSchema,
  placeIdParamSchema,
};
