const Joi = require('joi');

// ============================================================================
// VALIDATION: Reviews, Reports, Blocks, Emergency Contacts
// ============================================================================

const uuidSchema = Joi.string().guid({
  version: ['uuidv4', 'uuidv5'],
});

const ratingSchema = Joi.number()
  .integer()
  .min(1)
  .max(5)
  .required()
  .messages({
    'number.base': 'Điểm đánh giá phải là số',
    'number.integer': 'Điểm đánh giá phải là số nguyên',
    'number.min': 'Điểm đánh giá tối thiểu là 1 sao',
    'number.max': 'Điểm đánh giá tối đa là 5 sao',
    'any.required': 'Điểm đánh giá là bắt buộc',
  });

const commentSchema = Joi.string()
  .trim()
  .max(1000)
  .allow(null, '')
  .messages({
    'string.max': 'Nội dung nhận xét không được vượt quá 1000 ký tự',
  });

/**
 * Đánh giá một thành viên cùng chuyến đi.
 */
const reviewMemberSchema = Joi.object({
  tripId: uuidSchema.required().messages({
    'string.guid': 'Mã chuyến đi (tripId) phải là UUID hợp lệ',
    'any.required': 'Mã chuyến đi là bắt buộc',
  }),

  revieweeId: uuidSchema.required().messages({
    'string.guid': 'Mã người được đánh giá (revieweeId) phải là UUID hợp lệ',
    'any.required': 'Mã người được đánh giá là bắt buộc',
  }),

  rating: ratingSchema,
  comment: commentSchema,
});

/**
 * Đánh giá trải nghiệm chung của chuyến đi.
 */
const reviewTripSchema = Joi.object({
  tripId: uuidSchema.required().messages({
    'string.guid': 'Mã chuyến đi (tripId) phải là UUID hợp lệ',
    'any.required': 'Mã chuyến đi là bắt buộc',
  }),

  rating: ratingSchema,
  comment: commentSchema,
});

/**
 * Báo cáo người dùng, chuyến đi hoặc cả hai.
 *
 * Ảnh bằng chứng không nhận dưới dạng URL trong body.
 * Route sẽ lấy URL từ multipart field "evidence".
 */
const reportSchema = Joi.object({
  reportedUserId: uuidSchema.messages({
    'string.guid': 'Mã người dùng bị báo cáo phải là UUID hợp lệ',
  }),

  reportedTripId: uuidSchema.messages({
    'string.guid': 'Mã chuyến đi bị báo cáo phải là UUID hợp lệ',
  }),

  reason: Joi.string()
    .trim()
    .min(5)
    .max(2000)
    .required()
    .messages({
      'string.empty': 'Lý do báo cáo không được để trống',
      'string.min': 'Lý do báo cáo phải có ít nhất 5 ký tự',
      'string.max': 'Lý do báo cáo không được vượt quá 2000 ký tự',
      'any.required': 'Lý do báo cáo là bắt buộc',
    }),
})
  .or('reportedUserId', 'reportedTripId')
  .messages({
    'object.missing':
      'Phải cung cấp người dùng hoặc chuyến đi cần báo cáo',
  });

/**
 * Chặn người dùng.
 */
const blockUserSchema = Joi.object({
  blockedUserId: uuidSchema.required().messages({
    'string.guid': 'Mã người dùng bị chặn phải là UUID hợp lệ',
    'any.required': 'Mã người dùng bị chặn là bắt buộc',
  }),
});

/**
 * Tạo người liên hệ khẩn cấp.
 */
const createEmergencyContactSchema = Joi.object({
  fullName: Joi.string()
    .trim()
    .min(2)
    .max(100)
    .required()
    .messages({
      'string.empty': 'Tên người liên hệ không được để trống',
      'string.min': 'Tên người liên hệ phải có ít nhất 2 ký tự',
      'string.max': 'Tên người liên hệ không được vượt quá 100 ký tự',
      'any.required': 'Tên người liên hệ là bắt buộc',
    }),

  phone: Joi.string()
    .trim()
    .pattern(/^\+?[0-9]{9,15}$/)
    .required()
    .messages({
      'string.empty': 'Số điện thoại không được để trống',
      'string.pattern.base':
        'Số điện thoại phải gồm 9 đến 15 chữ số và có thể bắt đầu bằng dấu +',
      'any.required': 'Số điện thoại là bắt buộc',
    }),

  relationship: Joi.string()
    .trim()
    .max(100)
    .allow(null, '')
    .messages({
      'string.max': 'Mối quan hệ không được vượt quá 100 ký tự',
    }),
});

/**
 * Cập nhật người liên hệ khẩn cấp.
 */
const updateEmergencyContactSchema = Joi.object({
  fullName: Joi.string()
    .trim()
    .min(2)
    .max(100)
    .messages({
      'string.empty': 'Tên người liên hệ không được để trống',
      'string.min': 'Tên người liên hệ phải có ít nhất 2 ký tự',
      'string.max': 'Tên người liên hệ không được vượt quá 100 ký tự',
    }),

  phone: Joi.string()
    .trim()
    .pattern(/^\+?[0-9]{9,15}$/)
    .messages({
      'string.empty': 'Số điện thoại không được để trống',
      'string.pattern.base':
        'Số điện thoại phải gồm 9 đến 15 chữ số và có thể bắt đầu bằng dấu +',
    }),

  relationship: Joi.string()
    .trim()
    .max(100)
    .allow(null, '')
    .messages({
      'string.max': 'Mối quan hệ không được vượt quá 100 ký tự',
    }),
})
  .min(1)
  .messages({
    'object.min': 'Phải cung cấp ít nhất một thông tin cần cập nhật',
  });

const tripReviewsQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).max(100000).default(1),
  limit: Joi.number().integer().min(1).max(50).default(20),
});

/**
 * Param UUID chung cho contactId, tripId và user ID cần bỏ chặn.
 */
const idParamSchema = Joi.object({
  id: uuidSchema.required().messages({
    'string.guid': 'Tham số id phải là UUID hợp lệ',
    'any.required': 'Tham số id là bắt buộc',
  }),
});

module.exports = {
  reviewMemberSchema,
  reviewTripSchema,
  tripReviewsQuerySchema,
  reportSchema,
  blockUserSchema,
  createEmergencyContactSchema,
  updateEmergencyContactSchema,
  idParamSchema,
};
