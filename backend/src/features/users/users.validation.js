const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Users & eKYC (src/features/users/)
// Kiểm tra dữ liệu cập nhật thông tin cá nhân, tài khoản ngân hàng và xác minh CCCD
// ============================================================================

/**
 * Cập nhật thông tin cá nhân (Profile)
 */
const updateProfileSchema = Joi.object({
  fullName: Joi.string().trim().min(2).max(100).messages({
    'string.min': 'Họ và tên phải có ít nhất 2 ký tự',
    'string.max': 'Họ và tên không được vượt quá 100 ký tự',
  }),
  nickname: Joi.string().trim().max(50).allow(null, '').messages({
    'string.max': 'Biệt danh không được vượt quá 50 ký tự',
  }),
  phone: Joi.string()
    .pattern(/^(0|\+84)[3|5|7|8|9][0-9]{8}$/)
    .allow(null, '')
    .messages({
      'string.pattern.base': 'Số điện thoại không đúng định dạng Việt Nam (VD: 0912345678 hoặc +84912345678)',
    }),
  avatarUrl: Joi.string().uri().allow(null, '').messages({
    'string.uri': 'Đường dẫn ảnh đại diện (avatarUrl) không hợp lệ',
  }),
  bio: Joi.string().trim().max(500).allow(null, '').messages({
    'string.max': 'Tiểu sử không được vượt quá 500 ký tự',
  }),
  gender: Joi.string().valid('MALE', 'FEMALE', 'OTHER').allow(null).messages({
    'any.only': 'Giới tính phải là MALE, FEMALE hoặc OTHER',
  }),
  dob: Joi.date().iso().max('now').allow(null).messages({
    'date.format': 'Ngày sinh phải theo định dạng chuẩn ISO (YYYY-MM-DD)',
    'date.max': 'Ngày sinh không thể là ngày trong tương lai',
  }),
}).min(1).messages({
  'object.min': 'Vui lòng cung cấp ít nhất một thông tin cần cập nhật',
});

/**
 * Lưu thông tin tài khoản ngân hàng thụ hưởng (Dùng cho VietQR & Split Bill)
 */
const bankAccountSchema = Joi.object({
  bankBin: Joi.string().trim().min(3).max(20).required().messages({
    'string.empty': 'Mã BIN ngân hàng không được để trống (VD: 970422 - MB Bank)',
    'any.required': 'Mã BIN ngân hàng là bắt buộc',
  }),
  bankName: Joi.string().trim().min(2).max(100).required().messages({
    'string.empty': 'Tên ngân hàng không được để trống',
    'any.required': 'Tên ngân hàng là bắt buộc',
  }),
  bankAccountNumber: Joi.string()
    .trim()
    .pattern(/^[0-9A-Za-z]{4,30}$/)
    .required()
    .messages({
      'string.pattern.base': 'Số tài khoản ngân hàng chỉ được chứa số hoặc chữ cái (từ 4 đến 30 ký tự)',
      'string.empty': 'Số tài khoản ngân hàng không được để trống',
      'any.required': 'Số tài khoản ngân hàng là bắt buộc',
    }),
  bankAccountName: Joi.string().trim().min(2).max(100).required().messages({
    'string.empty': 'Tên chủ tài khoản không được để trống',
    'any.required': 'Tên chủ tài khoản là bắt buộc',
  }),
});

/**
 * Nộp hồ sơ xác minh danh tính eKYC (CCCD)
 */
const ekycVerifySchema = Joi.object({
  cccdNumber: Joi.string()
    .trim()
    .pattern(/^[0-9]{12}$/)
    .required()
    .messages({
      'string.pattern.base': 'Số Căn cước công dân phải gồm đúng 12 chữ số',
      'string.empty': 'Số CCCD không được để trống',
      'any.required': 'Số CCCD là bắt buộc',
    }),
  cccdFrontImage: Joi.string().uri().required().messages({
    'string.uri': 'Đường dẫn ảnh mặt trước CCCD không hợp lệ',
    'any.required': 'Ảnh mặt trước CCCD là bắt buộc',
  }),
  cccdBackImage: Joi.string().uri().required().messages({
    'string.uri': 'Đường dẫn ảnh mặt sau CCCD không hợp lệ',
    'any.required': 'Ảnh mặt sau CCCD là bắt buộc',
  }),
  selfieImage: Joi.string().uri().required().messages({
    'string.uri': 'Đường dẫn ảnh chụp chân dung (Selfie) không hợp lệ',
    'any.required': 'Ảnh chân dung xác thực là bắt buộc',
  }),
});

/**
 * Kiểm tra ID người dùng trên URL
 */
const userIdParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã người dùng (id) phải là UUID hợp lệ',
    'any.required': 'Mã người dùng là bắt buộc',
  }),
});

module.exports = {
  updateProfileSchema,
  bankAccountSchema,
  ekycVerifySchema,
  userIdParamSchema,
};
