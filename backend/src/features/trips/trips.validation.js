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

const createTripSchema = Joi.object({
  name: Joi.string().trim().min(2).max(255),
  destination: Joi.string().trim().min(2).max(255).required(),
  startDate: date.required(),
  endDate: date.required(),
  estimatedBudget: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER).default(0),
  coverImageUrl: Joi.string().uri().allow(null, ''),
  description: Joi.string().trim().max(2000).allow(null, ''),
  privacyType: Joi.string().valid('PRIVATE', 'PUBLIC').default('PRIVATE'),
  status: Joi.forbidden(),
  creatorId: Joi.forbidden(),
  inviteCode: Joi.forbidden(),
  tripType: Joi.forbidden(),
}).custom((value, helpers) => value.endDate < value.startDate
  ? helpers.error('date.range') : value).messages({ 'date.range': 'Ngày kết thúc không thể trước ngày khởi hành' });

const updateTripSchema = Joi.object({
  name: Joi.string().trim().min(2).max(255),
  destination: Joi.string().trim().min(2).max(255),
  startDate: date,
  endDate: date,
  estimatedBudget: Joi.number().integer().min(0).max(Number.MAX_SAFE_INTEGER),
  coverImageUrl: Joi.string().uri().allow(null, ''),
  description: Joi.string().trim().max(2000).allow(null, ''),
  privacyType: Joi.string().valid('PRIVATE', 'PUBLIC'),
  expectedUpdatedAt: version.required(),
  status: Joi.forbidden(),
  tripType: Joi.forbidden(),
}).min(2);

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
