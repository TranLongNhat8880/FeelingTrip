const Joi = require('joi');

// ============================================================================
// VALIDATION SCHEMAS: Companions Newsfeed (src/features/companions/)
// Quy tắc kiểm tra bài đăng tìm bạn đồng hành, xin ghép đoàn & duyệt thành viên
// ============================================================================

/**
 * Lọc bảng tin bài đăng tìm bạn đồng hành (Newsfeed query)
 */
const companionFeedQuerySchema = Joi.object({
  destination: Joi.string().trim().allow(''),
  genderPreference: Joi.string().valid('ANY', 'MALE', 'FEMALE'),
  minAge: Joi.number().integer().min(16).max(100),
  maxAge: Joi.number().integer().min(16).max(100),
  status: Joi.string().valid('OPEN', 'FULL', 'CLOSED'),
  cursor: Joi.string().allow(''),
  limit: Joi.number().integer().min(1).max(50).default(10),
});

/**
 * Đăng bài tìm bạn đồng hành mới
 */
const createCompanionPostSchema = Joi.object({
  tripId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã chuyến đi (tripId) phải là UUID hợp lệ',
    'any.required': 'Mã chuyến đi (tripId) là bắt buộc',
  }),
  title: Joi.string().trim().min(5).max(255).required().messages({
    'string.empty': 'Tiêu đề bài đăng không được để trống',
    'string.min': 'Tiêu đề bài đăng phải có ít nhất 5 ký tự',
    'string.max': 'Tiêu đề không được vượt quá 255 ký tự',
    'any.required': 'Tiêu đề bài đăng là bắt buộc',
  }),
  content: Joi.string().trim().min(10).max(5000).required().messages({
    'string.empty': 'Nội dung bài đăng không được để trống',
    'string.min': 'Nội dung bài đăng phải có ít nhất 10 ký tự',
    'string.max': 'Nội dung không được vượt quá 5000 ký tự',
    'any.required': 'Nội dung bài đăng là bắt buộc',
  }),
  targetMembersCount: Joi.number().integer().min(1).max(50).required().messages({
    'number.min': 'Số lượng bạn đồng hành cần tuyển tối thiểu là 1',
    'number.max': 'Số lượng bạn đồng hành tối đa là 50',
    'any.required': 'Số lượng tuyển là bắt buộc',
  }),
  minAge: Joi.number().integer().min(16).max(100).allow(null),
  maxAge: Joi.number().integer().min(16).max(100).allow(null),
  genderPreference: Joi.string().valid('ANY', 'MALE', 'FEMALE').default('ANY').messages({
    'any.only': 'Yêu cầu giới tính phải là ANY, MALE hoặc FEMALE',
  }),
  tags: Joi.array().items(Joi.string().trim().max(30)).max(10).allow(null),
});

/**
 * Gửi yêu cầu xin tham gia chuyến đi (Join Request)
 */
const createJoinRequestSchema = Joi.object({
  postId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã bài đăng (postId) phải là UUID hợp lệ',
    'any.required': 'Mã bài đăng (postId) là bắt buộc',
  }),
  introduction: Joi.string().trim().min(5).max(1000).required().messages({
    'string.empty': 'Lời giới thiệu không được để trống',
    'string.min': 'Lời giới thiệu bản thân phải có ít nhất 5 ký tự',
    'string.max': 'Lời giới thiệu không được vượt quá 1000 ký tự',
    'any.required': 'Lời giới thiệu bản thân là bắt buộc',
  }),
});

/**
 * Trưởng nhóm phản hồi yêu cầu xin tham gia (Duyệt hoặc Từ chối)
 */
const updateJoinRequestStatusSchema = Joi.object({
  status: Joi.string().valid('ACCEPTED', 'REJECTED').required().messages({
    'any.only': 'Trạng thái phản hồi phải là ACCEPTED hoặc REJECTED',
    'any.required': 'Trạng thái phản hồi là bắt buộc',
  }),
});

/**
 * Params Schemas
 */
const postIdParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã bài đăng (id) phải là UUID hợp lệ',
  }),
});

const requestIdParamSchema = Joi.object({
  id: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required().messages({
    'string.guid': 'Mã yêu cầu (id) phải là UUID hợp lệ',
  }),
});

module.exports = {
  companionFeedQuerySchema,
  createCompanionPostSchema,
  createJoinRequestSchema,
  updateJoinRequestStatusSchema,
  postIdParamSchema,
  requestIdParamSchema,
};
