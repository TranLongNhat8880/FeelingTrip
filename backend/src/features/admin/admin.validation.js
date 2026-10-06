const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Admin Panel (src/features/admin/)
// Quy tắc kiểm tra thao tác khóa tài khoản, duyệt eKYC và xử lý báo cáo vi phạm
// ============================================================================

/**
 * Cập nhật trạng thái người dùng (Khóa / Mở khóa tài khoản)
 */
const updateUserStatusSchema = Joi.object({
  status: Joi.string().valid('ACTIVE', 'BANNED').required().messages({
    'any.only': 'Trạng thái tài khoản phải là ACTIVE hoặc BANNED',
    'any.required': 'Trạng thái tài khoản là bắt buộc',
  }),
  reason: Joi.string().trim().max(500).allow(null, ''),
});

/**
 * Từ chối hồ sơ xác minh CCCD
 */
const rejectEkycSchema = Joi.object({
  reason: Joi.string().trim().min(3).max(500).required().messages({
    'string.empty': 'Lý do từ chối không được để trống',
    'string.min': 'Lý do từ chối phải có ít nhất 3 ký tự',
    'any.required': 'Lý do từ chối hồ sơ là bắt buộc',
  }),
});

/**
 * Xử lý báo cáo vi phạm
 */
const resolveReportSchema = Joi.object({
  action: Joi.string().valid('RESOLVED', 'DISMISSED').required().messages({
    'any.only': 'Hành động xử lý phải là RESOLVED hoặc DISMISSED',
    'any.required': 'Hành động xử lý là bắt buộc',
  }),
  adminNotes: Joi.string().trim().max(1000).allow(null, '').messages({
    'string.max': 'Ghi chú của quản trị viên không được vượt quá 1000 ký tự',
  }),
});

/**
 * Query params khi lấy danh sách người dùng
 */
const getUsersQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  search: Joi.string().trim().max(100).allow('', null),
  role: Joi.string().valid('USER', 'ADMIN').allow('', null),
  status: Joi.string().valid('ACTIVE', 'BANNED').allow('', null),
});

/**
 * Query params khi lấy danh sách eKYC chờ duyệt
 */
const getEkycPendingQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

/**
 * Params Schemas
 */
const adminIdParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã định danh (id) phải là UUID hợp lệ',
    'any.required': 'Mã định danh là bắt buộc',
  }),
});

module.exports = {
  updateUserStatusSchema,
  rejectEkycSchema,
  resolveReportSchema,
  adminIdParamSchema,
  getUsersQuerySchema,
  getEkycPendingQuerySchema,
};
