const db = require('../../config/database');
const apiError = require('../../shared/utils/apiError.util');
const repo = require('./trips.repository');
const serializer = require('./trips.serializer');

// ============================================================================
// SERVICE: Trips
// Xử lý logic nghiệp vụ cho chuyến đi (tạo, cập nhật, thành viên, lời mời)
// ============================================================================

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} actual
 * @param {string} expected
 */
const sameVersion = (actual, expected) =>
  new Date(actual).getTime() === new Date(expected).getTime();

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} startDate
 * @param {string} endDate
 */
const durationDays = (startDate, endDate) => {
  const start = Date.parse(`${startDate}T00:00:00Z`);
  const end = Date.parse(`${endDate}T00:00:00Z`);
  return Math.round((end - start) / 86400000) + 1;
};

/**
 * @description Xử lý thao tác thành viên đối với chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 * @param {string} leaderOnly
 */
const requireMember = async (client, tripId, userId, leaderOnly = false) => {
  const membership = await repo.getMembership(client, tripId, userId, true);
  if (!membership || membership.membership_status !== 'ACTIVE') {
    throw apiError(404, 'Không tìm thấy chuyến đi');
  }
  if (leaderOnly && membership.role !== 'LEADER') {
    throw apiError(403, 'Chỉ trưởng nhóm được thực hiện thao tác này');
  }
  return membership;
};

/**
 * @description Định dạng dữ liệu đầu ra cho chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} client
 */
const tripDetail = async (tripId, userId, client = db) => {
  const trip = await repo.findTripForMember(tripId, userId, client);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  const members = await repo.findSafeMembers(tripId, client);
  return serializer.detail(trip, members, trip.member_role === 'LEADER');
};

/**
 * @description Tạo mới chuyến đi.
 * @param {string} userId
 * @param {object} data
 */
const createTrip = (userId, data) => db.transaction(async client => {
  const trip = await repo.createTrip(client, userId, data);
  return tripDetail(trip.id, userId, client);
});

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} userId
 * @param {object} query
 */
const getMyTrips = async (userId, query) => {
  const result = await repo.findMyTrips(userId, query);
  return {
    items: result.rows.map(serializer.summary),
    pagination: serializer.pagination(query.page, query.limit, result.total),
  };
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 */
const getTripDetail = (tripId, userId) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId);
  if (trip.invite_code_status === 'ACTIVE' && trip.invite_code_expires_at <= new Date()) {
    await repo.expireInviteCode(client, tripId);
  }
  return tripDetail(tripId, userId, client);
});

/**
 * @description Cập nhật chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} data
 */
const updateTrip = (tripId, userId, data) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (['COMPLETED', 'CANCELLED'].includes(trip.status)) {
    throw apiError(409, 'Chuyến đi không còn cho phép chỉnh sửa');
  }
  if (!sameVersion(trip.updated_at, data.expectedUpdatedAt)) {
    throw apiError(409, 'Chuyến đi đã được cập nhật bởi yêu cầu khác');
  }
  if (data.privacyType === 'PUBLIC' && trip.privacy_type !== 'PUBLIC'
      && !(await repo.isUserVerified(client, userId))) {
    throw apiError(403, 'Trưởng nhóm phải xác minh danh tính trước khi công khai chuyến đi');
  }
  const startDate = data.startDate || trip.start_date;
  const endDate = data.endDate || trip.end_date;
  const duration = durationDays(startDate, endDate);
  if (!Number.isFinite(duration) || duration < 1) throw apiError(400, 'Khoảng ngày không hợp lệ');
  if (await repo.hasItineraryOutsideRange(client, tripId, duration)) {
    throw apiError(409, 'Khoảng ngày mới loại bỏ ngày lịch trình đã tồn tại');
  }
  const updated = await repo.updateTrip(client, tripId, data);
  if (data.startDate !== undefined || data.endDate !== undefined) {
    await repo.refreshItineraryDates(client, tripId);
  }
  return tripDetail(updated.id, userId, client);
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} data
 */
const transitionStatus = (tripId, userId, data) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (trip.status === data.status) return tripDetail(tripId, userId, client);
  if (!sameVersion(trip.updated_at, data.expectedUpdatedAt)) {
    throw apiError(409, 'Chuyến đi đã được cập nhật bởi yêu cầu khác');
  }
  const allowed = { UPCOMING: ['ONGOING'], ONGOING: ['COMPLETED'] };
  if (!(allowed[trip.status] || []).includes(data.status)) {
    throw apiError(409, 'Chuyển trạng thái chuyến đi không hợp lệ');
  }
  await repo.setTripStatus(client, tripId, data.status);
  return tripDetail(tripId, userId, client);
});

/**
 * @description Xóa chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} data
 */
const deleteTrip = (tripId, userId, data = {}) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (trip.status === 'CANCELLED') return tripDetail(tripId, userId, client);
  if (data.expectedUpdatedAt && !sameVersion(trip.updated_at, data.expectedUpdatedAt)) {
    throw apiError(409, 'Chuyến đi đã được cập nhật bởi yêu cầu khác');
  }
  await repo.cancelTrip(client, tripId);
  await repo.notifyActiveMembers(client, tripId, userId, 'Chuyến đi đã bị hủy', trip.name, { tripId });
  return tripDetail(tripId, userId, client);
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} userId
 * @param {string} inviteCode
 * @param {string} expectedTripId
 */
const joinTrip = async (userId, inviteCode, expectedTripId = null) => {
  const result = await db.transaction(async client => {
    if (!(await repo.hasActiveBankhub(client, userId))) {
      throw apiError(403, 'Bạn cần liên kết tài khoản BankHub đang hoạt động');
    }
    const trip = await repo.findTripByInviteCodeForUpdate(client, inviteCode);
    if (!trip || (expectedTripId && trip.id !== expectedTripId)) throw apiError(400, 'Mã mời không hợp lệ');
    if (trip.invite_code_status === 'ACTIVE' && trip.invite_code_expires_at <= new Date()) {
      await repo.expireInviteCode(client, trip.id);
      return { expired: true, message: 'Mã mời đã hết hạn' };
    }
    if (trip.invite_code_status !== 'ACTIVE') throw apiError(409, 'Mã mời không còn hiệu lực');
    if (trip.privacy_type !== 'PRIVATE' || !['UPCOMING', 'ONGOING'].includes(trip.status)) {
      throw apiError(409, 'Chuyến đi không cho phép tham gia bằng mã');
    }
    const current = await repo.getMembership(client, trip.id, userId, true);
    if (current && current.membership_status === 'ACTIVE') throw apiError(409, 'Bạn đã là thành viên');
    await repo.activateMembership(client, trip.id, userId);
    await repo.consumeInviteCode(client, trip.id);
    const joined = await repo.findTripForMember(trip.id, userId, client);
    const membership = await repo.findMemberProjection(client, trip.id, userId);
    return { trip: serializer.summary(joined), membership: serializer.member(membership) };
  });
  if (result.expired) throw apiError(409, result.message);
  return result;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} query
 */
const getMembers = (tripId, userId, query) => db.transaction(async client => {
  await requireMember(client, tripId, userId);
  const caller = await repo.getMembership(client, tripId, userId);
  if (query.status !== 'ACTIVE' && caller.role !== 'LEADER') {
    throw apiError(403, 'Chỉ trưởng nhóm được xem lịch sử thành viên');
  }
  const rows = await repo.findSafeMembers(tripId, client, query);
  const total = await repo.countMembersByStatus(tripId, query.status, client);
  return { items: rows.map(serializer.member), pagination: serializer.pagination(query.page, query.limit, total) };
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 */
const leaveTrip = (tripId, userId) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  const membership = await requireMember(client, tripId, userId);
  if (membership.role === 'LEADER') throw apiError(409, 'Trưởng nhóm phải chuyển quyền hoặc hủy chuyến');
  const financialAccessRequired = await repo.hasOutstandingDebts(client, tripId, userId);
  await repo.markMembership(client, tripId, userId, 'LEFT');
  const changed = await repo.findMemberProjection(client, tripId, userId);
  return { membership: serializer.member(changed), financialAccessRequired };
});

/**
 * @description Xóa chuyến đi.
 * @param {string} tripId
 * @param {string} targetUserId
 * @param {string} userId
 */
const kickMember = (tripId, targetUserId, userId) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (targetUserId === userId) throw apiError(400, 'Không thể tự loại chính mình');
  const target = await repo.getMembership(client, tripId, targetUserId, true);
  if (!target || target.membership_status !== 'ACTIVE' || target.role === 'LEADER') {
    throw apiError(404, 'Không tìm thấy thành viên');
  }
  const financialAccessRequired = await repo.hasOutstandingDebts(client, tripId, targetUserId);
  await repo.markMembership(client, tripId, targetUserId, 'REMOVED', userId);
  const changed = await repo.findMemberProjection(client, tripId, targetUserId);
  await repo.notify(client, targetUserId, 'Bạn đã bị loại khỏi chuyến đi', trip.name, { tripId });
  return { membership: serializer.member(changed), financialAccessRequired };
});

/**
 * @description Xử lý phân quyền Trưởng nhóm cho chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} data
 */
const transferLeader = (tripId, userId, data) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (['COMPLETED', 'CANCELLED'].includes(trip.status)) throw apiError(409, 'Không thể chuyển trưởng nhóm');
  if (!sameVersion(trip.updated_at, data.expectedUpdatedAt)) throw apiError(409, 'Chuyến đi đã được cập nhật');
  if (data.newLeaderUserId === userId) throw apiError(400, 'Người nhận phải khác trưởng nhóm hiện tại');
  const target = await repo.getMembership(client, tripId, data.newLeaderUserId, true);
  if (!target || target.membership_status !== 'ACTIVE') throw apiError(404, 'Không tìm thấy thành viên');
  await repo.transferLeader(client, tripId, userId, data.newLeaderUserId);
  await repo.notify(client, data.newLeaderUserId, 'Bạn là trưởng nhóm mới', trip.name, { tripId });
  return tripDetail(tripId, data.newLeaderUserId, client);
});

/**
 * @description Xử lý lời mời tham gia chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {string} expiresInHours
 */
const generateInviteCode = (tripId, userId, expiresInHours) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (trip.privacy_type !== 'PRIVATE' || !['UPCOMING', 'ONGOING'].includes(trip.status)) {
    throw apiError(409, 'Chuyến đi không cho phép tạo mã mời');
  }
  const updated = await repo.generateNewInviteCode(client, tripId, expiresInHours);
  if (!updated) throw apiError(500, 'Không tạo được mã mời duy nhất');
  return {
    inviteCode: updated.invite_code,
    status: updated.invite_code_status,
    expiresAt: updated.invite_code_expires_at,
  };
});

/**
 * @description Xử lý lời mời tham gia chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 */
const revokeInviteCode = (tripId, userId) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (trip.invite_code_status === 'ACTIVE' && trip.invite_code_expires_at <= new Date()) {
    await repo.expireInviteCode(client, tripId);
    return { status: 'EXPIRED', expiresAt: trip.invite_code_expires_at };
  }
  const updated = await repo.revokeInviteCode(client, tripId);
  return { status: updated.invite_code_status, expiresAt: updated.invite_code_expires_at };
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} data
 */
const sendInvitation = (tripId, userId, data) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  if (trip.privacy_type !== 'PRIVATE' || !['UPCOMING', 'ONGOING'].includes(trip.status)) {
    throw apiError(409, 'Chuyến đi không cho phép gửi lời mời');
  }
  if (data.inviteeUserId === userId) throw apiError(400, 'Không thể tự mời chính mình');
  const invitee = await repo.findUserForInvitation(client, data.inviteeUserId);
  if (!invitee || invitee.status !== 'ACTIVE') throw apiError(404, 'Không tìm thấy người nhận');
  const membership = await repo.getMembership(client, tripId, data.inviteeUserId, true);
  if (membership && membership.membership_status === 'ACTIVE') throw apiError(409, 'Người dùng đã là thành viên');
  await repo.expireInvitations(client, 'trip_id=$1 AND invitee_id=$2', [tripId, data.inviteeUserId]);
  let created;
  try {
    created = await repo.createInvitation(client, tripId, userId, data.inviteeUserId, data.expiresInHours);
  } catch (error) {
    if (error.code === '23505') throw apiError(409, 'Lời mời đang chờ đã tồn tại');
    throw error;
  }
  await repo.notify(client, data.inviteeUserId, 'Lời mời tham gia chuyến đi', trip.name,
    { tripId, invitationId: created.id });
  return serializer.invitation(await repo.findInvitation(client, created.id));
});

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} query
 */
const listTripInvitations = (tripId, userId, query) => db.transaction(async client => {
  const trip = await repo.lockTrip(client, tripId);
  if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
  await requireMember(client, tripId, userId, true);
  await repo.expireInvitations(client, 'trip_id=$1', [tripId]);
  const result = await repo.listInvitations(client, { tripId, ...query });
  return { items: result.rows.map(row => serializer.invitation(row)),
    pagination: serializer.pagination(query.page, query.limit, result.total) };
});

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} userId
 * @param {object} query
 */
const listMyInvitations = (userId, query) => db.transaction(async client => {
  await repo.expireInvitations(client, 'invitee_id=$1', [userId]);
  const result = await repo.listInvitations(client, { inviteeId: userId, ...query });
  return { items: result.rows.map(row => serializer.invitation(row, false)),
    pagination: serializer.pagination(query.page, query.limit, result.total) };
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} invitationId
 * @param {string} userId
 * @param {string} action
 */
const actOnInvitation = async (invitationId, userId, action) => {
  const result = await db.transaction(async client => {
    const initial = await repo.findInvitation(client, invitationId);
    if (!initial || initial.invitee_id !== userId) throw apiError(404, 'Không tìm thấy lời mời');
    const trip = await repo.lockTrip(client, initial.trip_id);
    const membership = await repo.getMembership(client, initial.trip_id, userId, true);
    const invitation = await repo.lockInvitation(client, invitationId);
    if (!trip || !invitation || invitation.invitee_id !== userId) throw apiError(404, 'Không tìm thấy lời mời');
    if (invitation.status !== 'PENDING') throw apiError(409, 'Lời mời không còn hiệu lực');
    if (invitation.expires_at <= new Date()) {
      await repo.setInvitationStatus(client, invitationId, 'EXPIRED');
      return { expired: true, message: 'Lời mời đã hết hạn' };
    }
    if (action === 'REJECTED') {
      const rejected = await repo.setInvitationStatus(client, invitationId, 'REJECTED');
      await repo.notify(client, invitation.inviter_id, 'Lời mời đã bị từ chối', trip.name,
        { tripId: trip.id, invitationId });
      return serializer.invitation(rejected, false);
    }
    if (!(await repo.hasActiveBankhub(client, userId))) throw apiError(403, 'Bạn cần liên kết BankHub');
    if (!['UPCOMING', 'ONGOING'].includes(trip.status) || trip.privacy_type !== 'PRIVATE') {
      throw apiError(409, 'Chuyến đi không còn nhận thành viên');
    }
    if (membership && membership.membership_status === 'ACTIVE') throw apiError(409, 'Bạn đã là thành viên');
    await repo.activateMembership(client, trip.id, userId);
    const accepted = await repo.setInvitationStatus(client, invitationId, 'ACCEPTED');
    await repo.notify(client, invitation.inviter_id, 'Lời mời đã được chấp nhận', trip.name,
      { tripId: trip.id, invitationId });
    return serializer.invitation(accepted, false);
  });
  if (result.expired) throw apiError(409, result.message);
  return result;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} tripId
 * @param {string} invitationId
 * @param {string} userId
 */
const revokeInvitation = async (tripId, invitationId, userId) => {
  const result = await db.transaction(async client => {
    const trip = await repo.lockTrip(client, tripId);
    if (!trip) throw apiError(404, 'Không tìm thấy chuyến đi');
    await requireMember(client, tripId, userId, true);
    const invitation = await repo.lockInvitation(client, invitationId);
    if (!invitation || invitation.trip_id !== tripId) throw apiError(404, 'Không tìm thấy lời mời');
    if (invitation.status !== 'PENDING') throw apiError(409, 'Lời mời không còn hiệu lực');
    if (invitation.expires_at <= new Date()) {
      await repo.setInvitationStatus(client, invitationId, 'EXPIRED');
      return { expired: true, message: 'Lời mời đã hết hạn' };
    }
    const revoked = await repo.setInvitationStatus(client, invitationId, 'REVOKED');
    await repo.notify(client, invitation.invitee_id, 'Lời mời đã được thu hồi', trip.name,
      { tripId, invitationId });
    return serializer.invitation(revoked);
  });
  if (result.expired) throw apiError(409, result.message);
  return result;
};

module.exports = {
  createTrip, getMyTrips, getTripDetail, updateTrip, transitionStatus, deleteTrip,
  joinTrip, getMembers, leaveTrip, kickMember, transferLeader,
  generateInviteCode, revokeInviteCode, sendInvitation, listTripInvitations,
  listMyInvitations, acceptInvitation: (id, userId) => actOnInvitation(id, userId, 'ACCEPTED'),
  rejectInvitation: (id, userId) => actOnInvitation(id, userId, 'REJECTED'), revokeInvitation,
};
