const Joi = require('joi');

// ============================================================================
// VALIDATION: Trips
// Xác thực dữ liệu đầu vào (Request Body, Query, Params) cho API Trips
// ============================================================================

const uuid = Joi.string().guid({ version: ['uuidv4', 'uuidv5'] });
const date = Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).custom((value, helpers) => {
  const parsed = new Date(`${value}T00:00:00Z`);
  return Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value
    ? helpers.error('date.format') : value;
}).messages({ 'date.format': 'Ngày phải đúng định dạng YYYY-MM-DD và tồn tại' });
const version = Joi.date().iso();
const page = Joi.number().integer().min(1).default(1);
const limit = max => Joi.number().integer().min(1).max(max).default(20);

const tagsValidator = Joi.any().custom((value, helpers) => {
  if (value == null) return null;
  let arr = value;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        arr = JSON.parse(trimmed);
      } catch (_) {
        return helpers.message('tags không đúng định dạng JSON');
      }
    } else {
      arr = trimmed.split(',').map(s => s.trim()).filter(Boolean);
    }
  }
  if (!Array.isArray(arr)) {
    return helpers.message('tags phải là danh sách');
  }
  if (arr.length > 10) {
    return helpers.message('Số lượng tags tối đa là 10');
  }
  const validated = [];
  for (const item of arr) {
    if (typeof item !== 'string') {
      return helpers.message('Mỗi tag phải là chuỗi ký tự');
    }
    const t = item.trim();
    if (!t) continue;
    if (t.length > 30) {
      return helpers.message('Mỗi tag không được vượt quá 30 ký tự');
    }
    validated.push(t);
  }
  return validated;
});

const createTripSchema = Joi.object({
  name: Joi.string().trim().min(2).max(255),
  destination: Joi.string().trim().min(2).max(255).required(),
  startDate: date.required(),
  endDate: date.required(),
  estimatedBudget: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER).default(0),
  coverImageUrl: Joi.string().uri().allow(null, ''),
  description: Joi.string().trim().max(2000).allow(null, ''),
  privacyType: Joi.string().valid('PRIVATE', 'PUBLIC').default('PRIVATE'),
  destinationProvider: Joi.string().trim().max(50).allow(null),
  destinationExternalId: Joi.string().trim().max(500).allow(null),
  destinationLatitude: Joi.number().min(-90).max(90).allow(null),
  destinationLongitude: Joi.number().min(-180).max(180).allow(null),
  targetMembersCount: Joi.number().integer().min(1).max(50),
  minAge: Joi.number().integer().min(16).max(100).allow(null),
  maxAge: Joi.number().integer().min(16).max(100).allow(null),
  genderPreference: Joi.string().valid('ANY', 'MALE', 'FEMALE').default('ANY'),
  tags: tagsValidator,
  postTitle: Joi.string().trim().min(5).max(255).allow(null, '').messages({
    'string.min': 'Tiêu đề bài đăng phải có ít nhất 5 ký tự',
    'string.max': 'Tiêu đề không được vượt quá 255 ký tự',
  }),
  postContent: Joi.string().trim().min(10).max(5000).allow(null, '').messages({
    'string.min': 'Nội dung bài đăng phải có ít nhất 10 ký tự',
    'string.max': 'Nội dung không được vượt quá 5000 ký tự',
  }),
  status: Joi.forbidden(),
  creatorId: Joi.forbidden(),
  inviteCode: Joi.forbidden(),
  tripType: Joi.forbidden(),
}).custom((value, helpers) => {
  if (value.endDate < value.startDate) return helpers.error('date.range');
  // Tọa độ phải đi theo cặp
  if ((value.destinationLatitude == null) !== (value.destinationLongitude == null)) {
    return helpers.message('destinationLatitude và destinationLongitude phải đi theo cặp');
  }
  if (value.privacyType === 'PUBLIC' && value.targetMembersCount != null && value.targetMembersCount < 2) {
    return helpers.message('targetMembersCount phải từ 2 trở lên khi tạo chuyến đi công khai');
  }
  if (value.minAge && value.maxAge && value.minAge > value.maxAge) {
    return helpers.message('Độ tuổi tối thiểu không được lớn hơn độ tuổi tối đa');
  }
  return value;
}).messages({ 'date.range': 'Ngày kết thúc không thể trước ngày khởi hành' });

const updateTripSchema = Joi.object({
  name: Joi.string().trim().min(2).max(255),
  destination: Joi.string().trim().min(2).max(255),
  startDate: date,
  endDate: date,
  estimatedBudget: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER),
  coverImageUrl: Joi.string().uri().allow(null, ''),
  description: Joi.string().trim().max(2000).allow(null, ''),
  privacyType: Joi.string().valid('PRIVATE', 'PUBLIC'),
  destinationProvider: Joi.string().trim().max(50).allow(null),
  destinationExternalId: Joi.string().trim().max(500).allow(null),
  destinationLatitude: Joi.number().min(-90).max(90).allow(null),
  destinationLongitude: Joi.number().min(-180).max(180).allow(null),
  targetMembersCount: Joi.number().integer().min(1).max(50),
  minAge: Joi.number().integer().min(16).max(100).allow(null),
  maxAge: Joi.number().integer().min(16).max(100).allow(null),
  genderPreference: Joi.string().valid('ANY', 'MALE', 'FEMALE'),
  tags: tagsValidator,
  postTitle: Joi.string().trim().min(5).max(255).allow(null, '').messages({
    'string.min': 'Tiêu đề bài đăng phải có ít nhất 5 ký tự',
    'string.max': 'Tiêu đề không được vượt quá 255 ký tự',
  }),
  postContent: Joi.string().trim().min(10).max(5000).allow(null, '').messages({
    'string.min': 'Nội dung bài đăng phải có ít nhất 10 ký tự',
    'string.max': 'Nội dung không được vượt quá 5000 ký tự',
  }),
  expectedUpdatedAt: version.required(),
  status: Joi.forbidden(),
  tripType: Joi.forbidden(),
}).min(2).custom((value, helpers) => {
  if (value.destinationLatitude !== undefined || value.destinationLongitude !== undefined) {
    if ((value.destinationLatitude == null) !== (value.destinationLongitude == null)) {
      return helpers.message('destinationLatitude và destinationLongitude phải đi theo cặp');
    }
  }
  if (value.minAge && value.maxAge && value.minAge > value.maxAge) {
    return helpers.message('Độ tuổi tối thiểu không được lớn hơn độ tuổi tối đa');
  }
  return value;
});

const updateStatusSchema = Joi.object({
  status: Joi.string().valid('UPCOMING', 'ONGOING', 'COMPLETED').required(),
  expectedUpdatedAt: version.required(),
});

const cancelTripSchema = Joi.object({
  expectedUpdatedAt: version,
  reason: Joi.string().trim().max(500).allow(null, ''),
});

const joinTripSchema = Joi.object({
  inviteCode: Joi.string().trim().uppercase().length(6).pattern(/^[A-F0-9]{6}$/).required(),
});

const inviteCodeSchema = Joi.object({});

const invitationCreateSchema = Joi.object({
  inviteeUserId: uuid.required(),
  expiresInHours: Joi.number().integer().min(1).max(168).default(72),
});

const transferLeaderSchema = Joi.object({
  newLeaderUserId: uuid.required(),
  expectedUpdatedAt: version.required(),
});

const myTripsQuerySchema = Joi.object({
  status: Joi.string().valid('UPCOMING', 'ONGOING', 'COMPLETED', 'CANCELLED'),
  page,
  limit: limit(50),
  includeHistory: Joi.boolean().truthy('true').falsy('false').default(false),
});

const memberListQuerySchema = Joi.object({
  status: Joi.string().valid('ACTIVE', 'LEFT', 'REMOVED').default('ACTIVE'),
  page,
  limit: limit(50),
});

const invitationListQuerySchema = Joi.object({
  status: Joi.string().valid('PENDING', 'ACCEPTED', 'REJECTED', 'REVOKED', 'EXPIRED').default('PENDING'),
  page,
  limit: limit(50),
});

const tripIdParamSchema = Joi.object({ tripId: uuid.required() });
const legacyTripIdParamSchema = Joi.object({ id: uuid.required() });
const kickMemberParamSchema = Joi.object({ tripId: uuid.required(), userId: uuid.required() });
const legacyKickMemberParamSchema = Joi.object({ id: uuid.required(), userId: uuid.required() });
const invitationParamSchema = Joi.object({ invitationId: uuid.required() });
const tripInvitationParamSchema = Joi.object({ tripId: uuid.required(), invitationId: uuid.required() });

module.exports = {
  createTripSchema, updateTripSchema, updateStatusSchema, cancelTripSchema,
  joinTripSchema, inviteCodeSchema, invitationCreateSchema, transferLeaderSchema,
  myTripsQuerySchema, memberListQuerySchema, invitationListQuerySchema,
  tripIdParamSchema, legacyTripIdParamSchema, kickMemberParamSchema,
  legacyKickMemberParamSchema, invitationParamSchema, tripInvitationParamSchema,
};
