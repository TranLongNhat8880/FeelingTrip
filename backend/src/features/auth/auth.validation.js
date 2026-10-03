const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Authentication
// Định nghĩa quy tắc kiểm tra dữ liệu đầu vào cho phân hệ Auth
// ============================================================================

// Same policy for registration and password reset; login accepts existing passwords.
const passwordSchema = Joi.string().min(8).max(72)
  .pattern(/[A-Z]/, 'uppercase')
  .pattern(/[a-z]/, 'lowercase')
  .pattern(/[0-9]/, 'number')
  .pattern(/[!-/:-@\[-`{-~]/, 'special')
  .custom((value, helpers) => Buffer.byteLength(value, 'utf8') > 72
    ? helpers.error('password.bytes') : value)
  .required()
  .messages({
    'string.empty': 'Mật khẩu không được để trống',
    'string.min': 'Mật khẩu phải có ít nhất 8 ký tự',
    'string.max': 'Mật khẩu không được vượt quá 72 ký tự',
    'string.pattern.name': 'Mật khẩu phải có chữ hoa, chữ thường, số và ký tự đặc biệt',
    'password.bytes': 'Mật khẩu không được vượt quá 72 byte UTF-8',
    'any.required': 'Mật khẩu là trường bắt buộc',
  });

const registerSchema = Joi.object({
  termsAccepted: Joi.boolean().strict().valid(true).required().messages({
    'any.only': 'Vui lòng đồng ý với Điều khoản sử dụng',
    'any.required': 'Vui lòng đồng ý với Điều khoản sử dụng',
  }),
  termsVersion: Joi.string().valid('1.0').required().messages({
    'any.only': 'Vui lòng đọc và đồng ý với phiên bản điều khoản hiện tại',
    'any.required': 'Thiếu phiên bản điều khoản sử dụng',
  }),
  email: Joi.string().trim().lowercase()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  password: passwordSchema,
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
  email: Joi.string().trim().lowercase()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  otp: Joi.string()
    .trim()
    .pattern(/^[0-9]{6}$/)
    .required()
    .messages({
      'string.empty': 'Mã OTP không được để trống',
      'string.pattern.base': 'Mã OTP phải bao gồm đúng 6 chữ số',
      'any.required': 'Mã OTP là trường bắt buộc',
    }),
});

const loginSchema = Joi.object({
  email: Joi.string().trim().lowercase()
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
  email: Joi.string().trim().lowercase()
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
  email: Joi.string().trim().lowercase()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
});

const resetPasswordSchema = Joi.object({
  email: Joi.string().trim().lowercase()
    .email({ tlds: { allow: false } })
    .required()
    .messages({
      'string.empty': 'Email không được để trống',
      'string.email': 'Email không đúng định dạng',
      'any.required': 'Email là trường bắt buộc',
    }),
  otp: Joi.string()
    .trim()
    .pattern(/^[0-9]{6}$/)
    .required()
    .messages({
      'string.empty': 'Mã OTP không được để trống',
      'string.pattern.base': 'Mã OTP phải bao gồm đúng 6 chữ số',
      'any.required': 'Mã OTP là trường bắt buộc',
    }),
  newPassword: passwordSchema,
});

module.exports = {
  registerSchema,
  verifyOtpSchema,
  loginSchema,
  resendOtpSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
};
