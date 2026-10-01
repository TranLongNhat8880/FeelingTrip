const Joi = require('joi');


/**
 * Lấy danh sách thông báo
 */
const getNotificationsQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  isRead: Joi.boolean(),
  type: Joi.string().valid('INVITE', 'REQUEST', 'BILL', 'TRIP_UPDATE', 'SYSTEM'),
  sortBy: Joi.string().valid('createdAt', 'isRead').default('createdAt'),
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
