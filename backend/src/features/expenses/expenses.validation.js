const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Expenses & Split Bill
// Định nghĩa quy tắc kiểm tra dữ liệu đầu vào cho phân hệ Quản lý chi tiêu
// ============================================================================

const createExpenseSchema = Joi.object({
  tripId: Joi.string()
    .guid({ version: ['uuidv4', 'uuidv5'] })
    .required()
    .messages({
      'string.empty': 'Mã chuyến đi (tripId) không được để trống',
      'string.guid': 'Mã chuyến đi (tripId) phải là định dạng UUID hợp lệ',
      'any.required': 'Mã chuyến đi (tripId) là trường bắt buộc',
    }),
  title: Joi.string()
    .trim()
    .min(1)
    .max(255)
    .required()
    .messages({
      'string.empty': 'Tên khoản chi không được để trống',
      'string.max': 'Tên khoản chi không được vượt quá 255 ký tự',
      'any.required': 'Tên khoản chi là trường bắt buộc',
    }),
  amount: Joi.number()
    .positive()
    .precision(2)
    .required()
    .messages({
      'number.base': 'Số tiền phải là một con số',
      'number.positive': 'Số tiền chi tiêu phải lớn hơn 0',
      'any.required': 'Số tiền là trường bắt buộc',
    }),
  category: Joi.string()
    .valid('FOOD', 'TRANSPORTATION', 'ACCOMMODATION', 'TICKETS', 'SHOPPING', 'OTHER')
    .default('OTHER')
    .messages({
      'any.only': 'Danh mục phải thuộc: FOOD, TRANSPORTATION, ACCOMMODATION, TICKETS, SHOPPING, OTHER',
    }),
  receiptImageUrl: Joi.string()
    .uri()
    .allow(null, '')
    .messages({
      'string.uri': 'Đường dẫn ảnh hóa đơn không hợp lệ',
    }),
  expenseDate: Joi.date()
    .iso()
    .allow(null)
    .default(() => new Date(), 'current date'),
  splitType: Joi.string()
    .valid('EQUAL', 'EXACT', 'PERCENTAGE')
    .default('EQUAL')
    .messages({
      'any.only': 'Kiểu chia tiền phải là EQUAL (chia đều), EXACT (số tiền cụ thể) hoặc PERCENTAGE (phần trăm)',
    }),
  splits: Joi.array()
    .min(1)
    .required()
    .messages({
      'array.base': 'Danh sách chia tiền phải là một mảng',
      'array.min': 'Khoản chi tiêu phải được phân bổ cho ít nhất 1 thành viên',
      'any.required': 'Danh sách chia tiền (splits) là trường bắt buộc',
    }),
});

const tripIdParamSchema = Joi.object({
  tripId: Joi.string()
    .guid({ version: ['uuidv4', 'uuidv5'] })
    .required()
    .messages({
      'string.empty': 'Mã chuyến đi không được để trống',
      'string.guid': 'Mã chuyến đi (tripId) phải là UUID hợp lệ',
      'any.required': 'Mã chuyến đi là trường bắt buộc',
    }),
});

const settlementIdParamSchema = Joi.object({
  id: Joi.string()
    .guid({ version: ['uuidv4', 'uuidv5'] })
    .required()
    .messages({
      'string.empty': 'Mã thanh toán không được để trống',
      'string.guid': 'Mã thanh toán (id) phải là UUID hợp lệ',
      'any.required': 'Mã thanh toán là trường bắt buộc',
    }),
});

module.exports = {
  createExpenseSchema,
  tripIdParamSchema,
  settlementIdParamSchema,
};
