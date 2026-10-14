const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Users & eKYC
// ============================================================================

/**
 * Cập nhật hồ sơ cá nhân.
 *
 * Không nhận avatarUrl trực tiếp từ client.
 * Ảnh avatar phải được upload multipart qua Cloudinary và URL được lấy từ req.file.
 *
 * Schema không dùng .min(1) vì request có thể chỉ chứa file avatar,
 * trong trường hợp đó req.body sẽ rỗng và service sẽ kiểm tra req.file.
 */
const updateProfileSchema = Joi.object({
  fullName: Joi.string().trim().min(2).max(100).messages({
    'string.empty': 'Họ và tên không được để trống',
    'string.min': 'Họ và tên phải có ít nhất 2 ký tự',
    'string.max': 'Họ và tên không được vượt quá 100 ký tự',
  }),

  nickname: Joi.string().trim().max(50).allow(null, '').messages({
    'string.max': 'Biệt danh không được vượt quá 50 ký tự',
  }),

  phone: Joi.string()
    .trim()
    .pattern(/^(?:0|\+84)[35789][0-9]{8}$/)
    .allow(null, '')
    .messages({
      'string.pattern.base':
        'Số điện thoại không đúng định dạng Việt Nam (VD: 0912345678 hoặc +84912345678)',
    }),

  bio: Joi.string().trim().max(500).allow(null, '').messages({
    'string.max': 'Tiểu sử không được vượt quá 500 ký tự',
  }),

  gender: Joi.string()
    .valid('MALE', 'FEMALE', 'OTHER')
    .allow(null, '')
    .messages({
      'any.only': 'Giới tính phải là MALE, FEMALE hoặc OTHER',
    }),

  dob: Joi.date().iso().max('now').allow(null, '').messages({
    'date.base': 'Ngày sinh không hợp lệ',
    'date.format': 'Ngày sinh phải theo định dạng ISO YYYY-MM-DD',
    'date.max': 'Ngày sinh không thể là ngày trong tương lai',
  }),

  bankBin: Joi.string()
    .trim()
    .pattern(/^[0-9]{6}$/)
    .allow(null, '')
    .messages({
      'string.pattern.base': 'Mã BIN ngân hàng phải gồm 6 chữ số',
    }),

  bankName: Joi.string().trim().max(100).allow(null, '').messages({
    'string.max': 'Tên ngân hàng không được vượt quá 100 ký tự',
  }),

  bankAccountNumber: Joi.string().trim().max(50).allow(null, '').messages({
    'string.max': 'Số tài khoản không được vượt quá 50 ký tự',
  }),

  bankAccountName: Joi.string().trim().max(100).allow(null, '').messages({
    'string.max': 'Tên chủ tài khoản không được vượt quá 100 ký tự',
  }),
});

/**
 * Dữ liệu chữ của request multipart nộp hồ sơ eKYC.
 *
 * Ba ảnh CCCD trước, CCCD sau và selfie nằm trong req.files,
 * không nhận URL ảnh do client tự gửi trong req.body.
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
});

/**
 * Kiểm tra ID người dùng trên URL.
 */
const userIdParamSchema = Joi.object({
  id: Joi.string()
    .guid({ version: ['uuidv4', 'uuidv5'] })
    .required()
    .messages({
      'string.guid': 'Mã người dùng (id) phải là UUID hợp lệ',
      'any.required': 'Mã người dùng là bắt buộc',
    }),
});

module.exports = {
  updateProfileSchema,
  ekycVerifySchema,
  userIdParamSchema,
};
