const { sendError } = require('../utils/response.util');
const HTTP_STATUS = require('../constants/httpStatus');

// ============================================================================
// MIDDLEWARE: Request Validation (Joi)
// Kiểm tra tính hợp lệ của dữ liệu đầu vào (req.body, req.query, req.params)
// Trả về danh sách chi tiết các trường bị lỗi cho Frontend Flutter hiển thị
// ============================================================================

/**
 * Tạo middleware validate dữ liệu theo Joi Schema
 * @param {Object|Joi.ObjectSchema} schema - Schema Joi cho req.body, hoặc object chứa { body, query, params }
 */
const validate = (schema) => {
  return (req, res, next) => {
    // Nếu truyền trực tiếp 1 Joi Object -> mặc định kiểm tra req.body
    const isDirectSchema = schema && typeof schema.validate === 'function';
    const targets = isDirectSchema ? { body: schema } : schema;

    const errors = [];

    for (const [target, targetSchema] of Object.entries(targets)) {
      if (targetSchema && typeof targetSchema.validate === 'function') {
        const { error, value } = targetSchema.validate(req[target], {
          abortEarly: false,  // Gom tất cả lỗi của mọi trường, không dừng ở lỗi đầu
          stripUnknown: true, // Loại bỏ các trường thừa không mong muốn
        });

        if (error) {
          error.details.forEach((detail) => {
            errors.push({
              field: detail.path.join('.'),
              message: detail.message.replace(/['"]/g, ''),
            });
          });
        } else {
          // Cập nhật lại dữ liệu sạch sau khi parse
          req[target] = value;
        }
      }
    }

    if (errors.length > 0) {
      return sendError(res, 'Dữ liệu đầu vào không hợp lệ', HTTP_STATUS.BAD_REQUEST, errors);
    }

    next();
  };
};

module.exports = validate;
