const service = require('./trips.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');

const run = (handler) => async (req, res, next) => {
  try { return await handler(req, res); }
  catch (error) {
    if (error.status) return sendError(res, error.message, error.status, error.data || null);
    return next(error);
  }
};

// ============================================================================
// CONTROLLER: Trips
// Quản lý nghiệp vụ liên quan đến chuyến đi và thành viên
// ============================================================================

/**
 * [POST] /api/v1/trips
 * Tạo chuyến đi mới
 */
const createTrip = run(async (req, res) => sendSuccess(
  res, await service.createTrip(req.user.id, req.body), 'Tạo chuyến đi thành công', 201));

/**
 * [GET] /api/v1/trips/my-trips
 * Lấy danh sách chuyến đi của người dùng
 */
const getMyTrips = run(async (req, res) => sendSuccess(
  res, await service.getMyTrips(req.user.id, req.query), 'Lấy danh sách chuyến đi thành công'));

/**
 * [GET] /api/v1/trips/:tripId
 * Lấy thông tin chi tiết của chuyến đi
 */
const getTripDetail = run(async (req, res) => sendSuccess(
  res, await service.getTripDetail(req.params.tripId, req.user.id), 'Lấy chi tiết chuyến đi thành công'));

/**
 * [PATCH] /api/v1/trips/:tripId
 * Cập nhật thông tin chuyến đi
 */
const updateTrip = run(async (req, res) => sendSuccess(
  res, await service.updateTrip(req.params.tripId, req.user.id, req.body), 'Cập nhật chuyến đi thành công'));

/**
 * [PATCH] /api/v1/trips/:tripId/status
 * Cập nhật trạng thái chuyến đi
 */
const transitionStatus = run(async (req, res) => sendSuccess(
  res, await service.transitionStatus(req.params.tripId, req.user.id, req.body), 'Cập nhật trạng thái thành công'));

/**
 * [DELETE] /api/v1/trips/:tripId
 * Hủy chuyến đi (chỉ dành cho Leader)
 */
const deleteTrip = run(async (req, res) => sendSuccess(
  res, await service.deleteTrip(req.params.tripId, req.user.id, req.body), 'Hủy chuyến đi thành công'));

/**
 * [POST] /api/v1/trips/join-by-code
 * Tham gia nhóm bằng mã mời (invite code)
 */
const joinByCode = run(async (req, res) => sendSuccess(
  res, await service.joinTrip(req.user.id, req.body.inviteCode), 'Tham gia chuyến đi thành công', 201));

/**
 * [POST] /api/v1/trips/:id/join
 * (Legacy) Tham gia nhóm bằng mã mời
 */
const legacyJoin = run(async (req, res) => sendSuccess(
  res, await service.joinTrip(req.user.id, req.body.inviteCode, req.params.id), 'Tham gia chuyến đi thành công', 201));

/**
 * [GET] /api/v1/trips/:tripId/members
 * Lấy danh sách thành viên trong chuyến đi
 */
const getMembers = run(async (req, res) => sendSuccess(
  res, await service.getMembers(req.params.tripId, req.user.id, req.query), 'Lấy danh sách thành viên thành công'));

/**
 * [POST] /api/v1/trips/:tripId/leave
 * Rời khỏi chuyến đi hiện tại
 */
const leaveTrip = run(async (req, res) => sendSuccess(
  res, await service.leaveTrip(req.params.tripId, req.user.id), 'Rời chuyến đi thành công'));

/**
 * [DELETE] /api/v1/trips/:tripId/members/:userId
 * Xóa thành viên khỏi nhóm (chỉ dành cho Leader)
 */
const kickMember = run(async (req, res) => sendSuccess(
  res, await service.kickMember(req.params.tripId, req.params.userId, req.user.id), 'Đã loại thành viên'));

/**
 * [POST] /api/v1/trips/:tripId/leader-transfer
 * Chuyển quyền Leader cho thành viên khác
 */
const transferLeader = run(async (req, res) => sendSuccess(
  res, await service.transferLeader(req.params.tripId, req.user.id, req.body), 'Chuyển trưởng nhóm thành công'));

/**
 * [POST] /api/v1/trips/:tripId/invite-code
 * Sinh mã mời mới cho chuyến đi
 */
const generateInviteCode = run(async (req, res) => sendSuccess(
  res, await service.generateInviteCode(req.params.tripId, req.user.id),
  'Sinh mã mời thành công', 201));

/**
 * [DELETE] /api/v1/trips/:tripId/invite-code
 * Thu hồi mã mời
 */
const revokeInviteCode = run(async (req, res) => sendSuccess(
  res, await service.revokeInviteCode(req.params.tripId, req.user.id), 'Thu hồi mã mời thành công'));

/**
 * [POST] /api/v1/trips/:tripId/invitations
 * Gửi lời mời tham gia chuyến đi
 */
const sendInvitation = run(async (req, res) => sendSuccess(
  res, await service.sendInvitation(req.params.tripId, req.user.id, req.body), 'Gửi lời mời thành công', 201));

/**
 * [GET] /api/v1/trips/:tripId/invitations
 * Xem danh sách lời mời của chuyến đi
 */
const listTripInvitations = run(async (req, res) => sendSuccess(
  res, await service.listTripInvitations(req.params.tripId, req.user.id, req.query), 'Lấy lời mời thành công'));

/**
 * [GET] /api/v1/trips/invitations/me
 * Xem danh sách lời mời cá nhân của tôi
 */
const listMyInvitations = run(async (req, res) => sendSuccess(
  res, await service.listMyInvitations(req.user.id, req.query), 'Lấy lời mời của tôi thành công'));

/**
 * [POST] /api/v1/trips/invitations/:invitationId/accept
 * Chấp nhận lời mời tham gia
 */
const acceptInvitation = run(async (req, res) => sendSuccess(
  res, await service.acceptInvitation(req.params.invitationId, req.user.id), 'Chấp nhận lời mời thành công', 201));

/**
 * [POST] /api/v1/trips/invitations/:invitationId/reject
 * Từ chối lời mời tham gia
 */
const rejectInvitation = run(async (req, res) => sendSuccess(
  res, await service.rejectInvitation(req.params.invitationId, req.user.id), 'Từ chối lời mời thành công'));

/**
 * [DELETE] /api/v1/trips/:tripId/invitations/:invitationId
 * Thu hồi lời mời đã gửi
 */
const revokeInvitation = run(async (req, res) => sendSuccess(
  res, await service.revokeInvitation(req.params.tripId, req.params.invitationId, req.user.id), 'Thu hồi lời mời thành công'));

module.exports = {
  createTrip, getMyTrips, getTripDetail, updateTrip, transitionStatus, deleteTrip,
  joinByCode, legacyJoin, getMembers, leaveTrip, kickMember, transferLeader,
  generateInviteCode, revokeInviteCode, sendInvitation, listTripInvitations,
  listMyInvitations, acceptInvitation, rejectInvitation, revokeInvitation,
};
