const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Notifications (src/features/notifications/)
// Quy tắc kiểm tra danh sách thông báo, phân trang và đánh dấu đã đọc
// ============================================================================

/**
 * Lấy danh sách thông báo (Query)
 */
const getNotificationsQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  isRead: Joi.boolean(),
});

/**
 * Kiểm tra ID thông báo trên URL
 */
const notificationIdParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã thông báo (id) phải là UUID hợp lệ',
    'any.required': 'Mã thông báo là bắt buộc',
  }),
});

module.exports = {
  getNotificationsQuerySchema,
  notificationIdParamSchema,
};
