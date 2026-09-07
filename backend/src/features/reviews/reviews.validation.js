const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Reviews, Reports & SOS Safety (src/features/reviews/)
// Quy tắc kiểm tra đánh giá chuyến đi, bạn đồng hành, tố cáo vi phạm và tín hiệu SOS
// ============================================================================

/**
 * Đánh giá thành viên cùng chuyến đi
 */
const reviewMemberSchema = Joi.object({
  tripId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã chuyến đi (tripId) phải là UUID hợp lệ',
    'any.required': 'Mã chuyến đi là bắt buộc',
  }),
  revieweeId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã người được đánh giá (revieweeId) phải là UUID hợp lệ',
    'any.required': 'Mã thành viên được đánh giá là bắt buộc',
  }),
  rating: Joi.number().integer().min(1).max(5).required().messages({
    'number.min': 'Điểm đánh giá tối thiểu là 1 sao',
    'number.max': 'Điểm đánh giá tối đa là 5 sao',
    'any.required': 'Điểm đánh giá (sao) là bắt buộc',
  }),
  comment: Joi.string().trim().max(1000).allow(null, '').messages({
    'string.max': 'Nội dung nhận xét không được vượt quá 1000 ký tự',
  }),
});

/**
 * Đánh giá trải nghiệm chung của chuyến đi
 */
const reviewTripSchema = Joi.object({
  tripId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã chuyến đi (tripId) phải là UUID hợp lệ',
    'any.required': 'Mã chuyến đi là bắt buộc',
  }),
  rating: Joi.number().integer().min(1).max(5).required().messages({
    'number.min': 'Điểm đánh giá tối thiểu là 1 sao',
    'number.max': 'Điểm đánh giá tối đa là 5 sao',
    'any.required': 'Điểm đánh giá (sao) là bắt buộc',
  }),
  comment: Joi.string().trim().max(1000).allow(null, '').messages({
    'string.max': 'Nội dung nhận xét không được vượt quá 1000 ký tự',
  }),
});

/**
 * Báo cáo tài khoản xấu hoặc chuyến đi vi phạm
 */
const reportSchema = Joi.object({
  reportedUserId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).allow(null),
  reportedTripId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).allow(null),
  reason: Joi.string().trim().min(5).max(2000).required().messages({
    'string.empty': 'Lý do báo cáo không được để trống',
    'string.min': 'Lý do báo cáo phải có ít nhất 5 ký tự',
    'string.max': 'Lý do báo cáo không được vượt quá 2000 ký tự',
    'any.required': 'Lý do báo cáo vi phạm là bắt buộc',
  }),
}).or('reportedUserId', 'reportedTripId').messages({
  'object.missing': 'Vui lòng cung cấp mã người dùng hoặc mã chuyến đi bị báo cáo',
});

/**
 * Chặn người dùng khác
 */
const blockUserSchema = Joi.object({
  blockedUserId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã người dùng bị chặn (blockedUserId) phải là UUID hợp lệ',
    'any.required': 'Mã người dùng bị chặn là bắt buộc',
  }),
});

/**
 * Kích hoạt tín hiệu khẩn cấp SOS (Lưu tọa độ vị trí hiện tại)
 */
const emergencySosSchema = Joi.object({
  latitude: Joi.number().min(-90).max(90).required().messages({
    'any.required': 'Vĩ độ hiện tại là bắt buộc',
  }),
  longitude: Joi.number().min(-180).max(180).required().messages({
    'any.required': 'Kinh độ hiện tại là bắt buộc',
  }),
  message: Joi.string().trim().max(500).allow(null, '').messages({
    'string.max': 'Tin nhắn khẩn cấp không được vượt quá 500 ký tự',
  }),
});

module.exports = {
  reviewMemberSchema,
  reviewTripSchema,
  reportSchema,
  blockUserSchema,
  emergencySosSchema,
};
