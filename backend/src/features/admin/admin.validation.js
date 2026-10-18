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
  adminNotes: Joi.string().trim().min(3).max(1000).required().messages({
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

// Bộ lọc báo cáo
const reportQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  status: Joi.string().valid('PENDING', 'RESOLVED', 'DISMISSED').allow(''),
  search: Joi.string().trim().max(100).allow(''),
});

// Bộ lọc kho lịch trình
const templateQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  search: Joi.string().trim().max(100).allow(''),
  destination: Joi.string().trim().max(100).allow(''),
  durationDays: Joi.number().integer().min(1).max(30),
  status: Joi.string().valid('ACTIVE', 'HIDDEN').allow(''),
  source: Joi.string().valid('SYSTEM', 'COMMUNITY').default('SYSTEM'),
  sortBy: Joi.string().valid('newest', 'usage', 'rating').default('newest'),
});

// Một hoạt động trong ngày
const templateItemSchema = Joi.object({
  placeId: Joi.string().lowercase().guid({ version: ['uuidv4', 'uuidv5'] }).allow(null),
  customName: Joi.string().trim().min(1).max(255).required(),
  customAddress: Joi.string().trim().max(500).allow('', null),
  category: Joi.string().valid(
    'ATTRACTION', 'RESTAURANT', 'CAFE', 'HOTEL', 'ENTERTAINMENT',
    'NATURE', 'CULTURE', 'SHOPPING', 'OTHER'
  ).default('OTHER'),
  startTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/).required(),
  endTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/).required(),
  estimatedCost: Joi.number().integer().min(0).max(1000000000000).default(0),
  note: Joi.string().trim().max(1000).allow('', null),
}).custom((value, helpers) => {
  if (value.startTime >= value.endTime) {
    return helpers.message({ custom: 'Giờ bắt đầu phải trước giờ kết thúc' });
  }

  return value;
});

// Nội dung mẫu khi tạo và cập nhật
const templateBodySchema = Joi.object({
  name: Joi.string().trim().min(2).max(255).required(),
  destination: Joi.string().trim().min(2).max(100).required(),
  durationDays: Joi.number().integer().min(1).max(30).required(),
  estimatedBudget: Joi.number().integer().min(0).max(1000000000000).default(0),
  description: Joi.string().trim().max(5000).allow('', null),
  days: Joi.array().min(1).max(30).items(Joi.object({
    dayNumber: Joi.number().integer().min(1).max(30).required(),
    title: Joi.string().trim().max(255).allow('', null),
    items: Joi.array().items(templateItemSchema).min(1).max(50).required(),
  })).required(),
});

const templateUpdateSchema = templateBodySchema.keys({
  expectedVersion: Joi.string().pattern(/^\d+$/).required(),
});

const templateStatusSchema = Joi.object({
  isActive: Joi.boolean().required(),
  expectedVersion: Joi.string().pattern(/^\d+$/).required(),
});

const templateDeleteQuerySchema = Joi.object({
  expectedVersion: Joi.string().pattern(/^\d+$/).required(),
});

const templateApplySchema = Joi.object({
  tripId: Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).required(),
});

// Bộ lọc và thao tác kiểm duyệt bài tuyển
const moderationQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(50).default(20),
  search: Joi.string().trim().max(200).allow('').default(''),
});

const moderatePostSchema = Joi.object({
  action: Joi.string().valid('HIDE', 'WARN').required(),
  reason: Joi.string().trim().min(3).max(1000).required(),
});

const warnReportSchema = Joi.object({
  reason: Joi.string().trim().min(3).max(980).required(),
});

// Hành động xử lý báo cáo chuyến đi
const processTripReportSchema = Joi.object({
  adminNotes: Joi.string().trim().min(3).max(1000).required(),
  reason: Joi.string().trim().min(3).max(500).required(),
  actions: Joi.array().min(1).max(10).items(Joi.object({
    type: Joi.string().valid('HIDE_POST', 'WARN_USER', 'BAN_USER').required(),
    targetId: Joi.string().lowercase().guid({ version: ['uuidv4', 'uuidv5'] }).required(),
  })).required(),
}).custom((value, helpers) => {
  const seen = new Set();
  for (const action of value.actions) {
    const key = `${action.type === 'HIDE_POST' ? 'post' : 'user'}:${action.targetId}`;
    if (seen.has(key)) {
      return helpers.message({ custom: 'Không chọn trùng đối tượng hoặc vừa cảnh cáo vừa khóa cùng tài khoản' });
    }
    seen.add(key);
  }
  return value;
});

module.exports = {
  processTripReportSchema,
  moderationQuerySchema,
  moderatePostSchema,
  warnReportSchema,
  reportQuerySchema,
  templateQuerySchema,
  templateBodySchema,
  templateUpdateSchema,
  templateStatusSchema,
  templateDeleteQuerySchema,
  templateApplySchema,
  updateUserStatusSchema,
  rejectEkycSchema,
  resolveReportSchema,
  adminIdParamSchema,
  getUsersQuerySchema,
  getEkycPendingQuerySchema,
};
