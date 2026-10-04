const express = require('express');
const controller = require('./trips.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const v = require('./trips.validation');

const router = express.Router();
router.use(authenticate);

const deprecated = replacement => (req, res, next) => {
  res.set('Warning', `299 - "Deprecated API; use ${replacement}"`);
  next();
};

// ============================================================================
// ROUTES: Trips (/api/v1/trips)
// Quản lý chuyến đi, thành viên, lời mời và mã tham gia
// ============================================================================

// Tạo mới chuyến đi và lấy danh sách chuyến đi của tôi
router.post('/', validate(v.createTripSchema), controller.createTrip);
router.get('/my-trips', validate({ query: v.myTripsQuerySchema }), controller.getMyTrips);

// Static invitation routes must stay above /:tripId.
// Quản lý lời mời của tôi và tham gia bằng mã
router.get('/invitations/me', validate({ query: v.invitationListQuerySchema }), controller.listMyInvitations);
router.post('/invitations/:invitationId/accept',
  validate({ params: v.invitationParamSchema }), controller.acceptInvitation);
router.post('/invitations/:invitationId/reject',
  validate({ params: v.invitationParamSchema }), controller.rejectInvitation);
router.post('/join-by-code', validate(v.joinTripSchema), controller.joinByCode);

// Chi tiết, Cập nhật, Thay đổi trạng thái, và Hủy chuyến đi
router.get('/:tripId', validate({ params: v.tripIdParamSchema }), controller.getTripDetail);
router.patch('/:tripId', validate({ params: v.tripIdParamSchema, body: v.updateTripSchema }), controller.updateTrip);
router.patch('/:tripId/status',
  validate({ params: v.tripIdParamSchema, body: v.updateStatusSchema }), controller.transitionStatus);
router.delete('/:tripId',
  validate({ params: v.tripIdParamSchema, body: v.cancelTripSchema }), controller.deleteTrip);

// Quản lý thành viên trong chuyến đi
router.get('/:tripId/members',
  validate({ params: v.tripIdParamSchema, query: v.memberListQuerySchema }), controller.getMembers);
router.post('/:tripId/leave', validate({ params: v.tripIdParamSchema }), controller.leaveTrip);
router.delete('/:tripId/members/:userId',
  validate({ params: v.kickMemberParamSchema }), controller.kickMember);
router.post('/:tripId/leader-transfer',
  validate({ params: v.tripIdParamSchema, body: v.transferLeaderSchema }), controller.transferLeader);

// Sinh mã tham gia nhóm (Invite Code)
router.post('/:tripId/invite-code',
  validate({ params: v.tripIdParamSchema, body: v.inviteCodeSchema }), controller.generateInviteCode);
router.delete('/:tripId/invite-code',
  validate({ params: v.tripIdParamSchema }), controller.revokeInviteCode);

// Quản lý lời mời trực tiếp cho chuyến đi
router.post('/:tripId/invitations',
  validate({ params: v.tripIdParamSchema, body: v.invitationCreateSchema }), controller.sendInvitation);
router.get('/:tripId/invitations',
  validate({ params: v.tripIdParamSchema, query: v.invitationListQuerySchema }), controller.listTripInvitations);
router.delete('/:tripId/invitations/:invitationId',
  validate({ params: v.tripInvitationParamSchema }), controller.revokeInvitation);

// ============================================================================
// TEMPORARY COMPATIBILITY ALIASES
// Các đường dẫn cũ (legacy), gọi cùng service gốc
// ============================================================================
router.put('/:tripId', deprecated('PATCH /api/v1/trips/:tripId'),
  validate({ params: v.tripIdParamSchema, body: v.updateTripSchema }), controller.updateTrip);
router.post('/:id/join', deprecated('POST /api/v1/trips/join-by-code'),
  validate({ params: v.legacyTripIdParamSchema, body: v.joinTripSchema }), controller.legacyJoin);

module.exports = router;
