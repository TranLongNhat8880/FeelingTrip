const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Authentication
// Định nghĩa quy tắc kiểm tra dữ liệu đầu vào cho phân hệ Auth
// ============================================================================

const registerSchema = Joi.object({
  email: Joi.string()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  password: Joi.string()
    .min(6)
    .required()
    .messages({
      'string.empty': 'Mật khẩu không được để trống',
      'string.min': 'Mật khẩu phải có độ dài tối thiểu 6 ký tự',
      'any.required': 'Mật khẩu là trường bắt buộc',
    }),
  fullName: Joi.string()
    .trim()
    .min(2)
    .max(100)
    .required()
    .messages({
      'string.empty': 'Họ và tên không được để trống',
      'string.min': 'Họ và tên phải có ít nhất 2 ký tự',
      'string.max': 'Họ và tên không được vượt quá 100 ký tự',
      'any.required': 'Họ và tên là trường bắt buộc',
    }),
  phone: Joi.string()
    .trim()
    .pattern(/^[0-9]{9,12}$/)
    .allow(null, '')
    .messages({
      'string.pattern.base': 'Số điện thoại phải từ 9 đến 12 chữ số',
    }),
});

const verifyOtpSchema = Joi.object({
  email: Joi.string()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  otp: Joi.string()
    .trim()
    .length(6)
    .required()
    .messages({
      'string.empty': 'Mã OTP không được để trống',
      'string.length': 'Mã OTP phải bao gồm đúng 6 chữ số',
      'any.required': 'Mã OTP là trường bắt buộc',
    }),
});

const loginSchema = Joi.object({
  email: Joi.string()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  password: Joi.string()
    .required()
    .messages({
      'string.empty': 'Mật khẩu không được để trống',
      'any.required': 'Mật khẩu là trường bắt buộc',
    }),
});

const resendOtpSchema = Joi.object({
  email: Joi.string()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  type: Joi.string()
    .valid('VERIFY_EMAIL', 'FORGOT_PASSWORD')
    .default('VERIFY_EMAIL'),
});

const forgotPasswordSchema = Joi.object({
  email: Joi.string()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
});

const resetPasswordSchema = Joi.object({
  email: Joi.string()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  otp: Joi.string()
    .trim()
    .length(6)
    .required()
    .messages({
      'string.empty': 'Mã OTP không được để trống',
      'string.length': 'Mã OTP phải bao gồm đúng 6 chữ số',
      'any.required': 'Mã OTP là trường bắt buộc',
    }),
  newPassword: Joi.string()
    .min(6)
    .required()
    .messages({
      'string.empty': 'Mật khẩu mới không được để trống',
      'string.min': 'Mật khẩu mới phải có tối thiểu 6 ký tự',
      'any.required': 'Mật khẩu mới là trường bắt buộc',
    }),
});

module.exports = {
  registerSchema,
  verifyOtpSchema,
  loginSchema,
  resendOtpSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
};
