const Joi = require('joi');

// ============================================================================
// VALIDATION: Reviews, Reports, Blocks
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

const tripReviewsQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).max(100000).default(1),
  limit: Joi.number().integer().min(1).max(50).default(20),
});

/**
 * Param UUID chung cho tripId và user ID cần bỏ chặn.
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
  idParamSchema,
};
