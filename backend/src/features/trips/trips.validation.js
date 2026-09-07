const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Trips & Group Management (src/features/trips/)
// Quy tắc kiểm tra dữ liệu tạo chuyến đi, sửa lịch trình, mời và quản lý thành viên
// ============================================================================

/**
 * Tạo chuyến đi mới
 */
const createTripSchema = Joi.object({
  name: Joi.string().trim().min(2).max(255).required().messages({
    'string.empty': 'Tên chuyến đi không được để trống',
    'string.min': 'Tên chuyến đi phải có ít nhất 2 ký tự',
    'string.max': 'Tên chuyến đi không được vượt quá 255 ký tự',
    'any.required': 'Tên chuyến đi là bắt buộc',
  }),
  destination: Joi.string().trim().min(2).max(255).required().messages({
    'string.empty': 'Điểm đến không được để trống',
    'any.required': 'Điểm đến là bắt buộc',
  }),
  startDate: Joi.date().iso().required().messages({
    'date.format': 'Ngày khởi hành phải đúng định dạng chuẩn ISO (YYYY-MM-DD)',
    'any.required': 'Ngày khởi hành là bắt buộc',
  }),
  endDate: Joi.date().iso().min(Joi.ref('startDate')).required().messages({
    'date.format': 'Ngày kết thúc phải đúng định dạng chuẩn ISO (YYYY-MM-DD)',
    'date.min': 'Ngày kết thúc không thể trước ngày khởi hành',
    'any.required': 'Ngày kết thúc là bắt buộc',
  }),
  estimatedBudget: Joi.number().min(0).default(0).messages({
    'number.min': 'Ngân sách dự kiến không được âm',
  }),
  coverImageUrl: Joi.string().uri().allow(null, '').messages({
    'string.uri': 'Đường dẫn ảnh bìa không hợp lệ',
  }),
  description: Joi.string().trim().max(2000).allow(null, '').messages({
    'string.max': 'Mô tả chuyến đi không được vượt quá 2000 ký tự',
  }),
  privacyType: Joi.string().valid('PRIVATE', 'PUBLIC').default('PRIVATE').messages({
    'any.only': 'Chế độ riêng tư phải là PRIVATE hoặc PUBLIC',
  }),
});

/**
 * Cập nhật thông tin chuyến đi
 */
const updateTripSchema = Joi.object({
  name: Joi.string().trim().min(2).max(255),
  destination: Joi.string().trim().min(2).max(255),
  startDate: Joi.date().iso(),
  endDate: Joi.date().iso(),
  estimatedBudget: Joi.number().min(0),
  coverImageUrl: Joi.string().uri().allow(null, ''),
  description: Joi.string().trim().max(2000).allow(null, ''),
  privacyType: Joi.string().valid('PRIVATE', 'PUBLIC'),
  status: Joi.string().valid('UPCOMING', 'ONGOING', 'COMPLETED', 'CANCELLED').messages({
    'any.only': 'Trạng thái chuyến đi phải là UPCOMING, ONGOING, COMPLETED hoặc CANCELLED',
  }),
}).min(1).messages({
  'object.min': 'Vui lòng cung cấp ít nhất một thông tin cần cập nhật',
});

/**
 * Tham gia chuyến đi bằng mã mời (Invite code)
 */
const joinTripSchema = Joi.object({
  inviteCode: Joi.string().trim().min(4).max(20).required().messages({
    'string.empty': 'Mã mời nhóm không được để trống',
    'any.required': 'Mã mời nhóm (inviteCode) là bắt buộc',
  }),
});

/**
 * Kiểm tra ID chuyến đi trên URL
 */
const tripIdParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã chuyến đi (id) phải là UUID hợp lệ',
    'any.required': 'Mã chuyến đi là bắt buộc',
  }),
});

/**
 * Kiểm tra tham số khi xóa thành viên khỏi chuyến đi
 */
const kickMemberParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã chuyến đi (id) phải là UUID hợp lệ',
  }),
  userId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã thành viên (userId) phải là UUID hợp lệ',
  }),
});

module.exports = {
  createTripSchema,
  updateTripSchema,
  joinTripSchema,
  tripIdParamSchema,
  kickMemberParamSchema,
};
