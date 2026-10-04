const crypto = require('crypto');
const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Trips
// Giao tiếp với cơ sở dữ liệu cho các bảng trips, trip_members, trip_invitations
// ============================================================================

/**
 * @description Xử lý lời mời tham gia chuyến đi.
 */
const generateInviteCode = () => crypto.randomBytes(3).toString('hex').toUpperCase();

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} tripId
 */
const lockTrip = async (client, tripId) => {
  const { rows: [row] } = await client.query('SELECT * FROM trips WHERE id = $1 FOR UPDATE', [tripId]);
  return row || null;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 * @param {string} forUpdate
 */
const getMembership = async (client, tripId, userId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trip_members WHERE trip_id = $1 AND user_id = $2${forUpdate ? ' FOR UPDATE' : ''}`,
    [tripId, userId]);
  return row || null;
};

/**
 * @description Tạo mới chuyến đi.
 * @param {object} client
 * @param {string} userId
 * @param {object} data
 */
const createTrip = async (client, userId, data) => {
  const { rows: [trip] } = await client.query(`
    INSERT INTO trips (
      creator_id, name, destination, start_date, end_date, estimated_budget,
      cover_image_url, description, privacy_type, status
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'PRIVATE','UPCOMING')
    RETURNING *`, [userId, data.name, data.destination, data.startDate, data.endDate,
    data.estimatedBudget ?? 0, data.coverImageUrl || null, data.description || null]);
  await client.query(`
    INSERT INTO trip_members (trip_id,user_id,role,membership_status)
    VALUES ($1,$2,'LEADER','ACTIVE')`, [trip.id, userId]);
  return trip;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} userId
 * @param {string} { status
 * @param {string} page
 * @param {string} limit
 * @param {string} includeHistory }
 */
const findMyTrips = async (userId, { status, page, limit, includeHistory }) => {
  const params = [userId];
  const filters = ['tm.user_id = $1'];
  if (!includeHistory) filters.push("tm.membership_status = 'ACTIVE'");
  if (status) { params.push(status); filters.push(`t.status = $${params.length}`); }
  const where = filters.join(' AND ');
  const { rows: [{ total }] } = await db.query(
    `SELECT COUNT(*)::int AS total FROM trips t JOIN trip_members tm ON tm.trip_id=t.id WHERE ${where}`,
    params);
  params.push(limit, (page - 1) * limit);
  const { rows } = await db.query(`
    SELECT t.*, tm.role AS member_role, tm.membership_status,
      (SELECT COUNT(*)::int FROM trip_members am
       WHERE am.trip_id=t.id AND am.membership_status='ACTIVE') AS member_count
    FROM trips t JOIN trip_members tm ON tm.trip_id=t.id
    WHERE ${where}
    ORDER BY CASE t.status WHEN 'ONGOING' THEN 0 WHEN 'UPCOMING' THEN 1 ELSE 2 END,
      CASE WHEN t.status='UPCOMING' THEN t.start_date END ASC,
      CASE WHEN t.status IN ('COMPLETED','CANCELLED') THEN t.end_date END DESC,
      t.id ASC
    LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows, total };
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} tripId
 * @param {string} userId
 * @param {object} client
 */
const findTripForMember = async (tripId, userId, client = db) => {
  const { rows: [trip] } = await client.query(`
    SELECT t.*, tm.role AS member_role, tm.membership_status,
      (SELECT COUNT(*)::int FROM trip_members am
       WHERE am.trip_id=t.id AND am.membership_status='ACTIVE') AS member_count
    FROM trips t JOIN trip_members tm ON tm.trip_id=t.id
    WHERE t.id=$1 AND tm.user_id=$2 AND tm.membership_status='ACTIVE'`, [tripId, userId]);
  return trip || null;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {string} tripId
 * @param {object} client
 * @param {string} { status
 * @param {string} page
 * @param {string} limit }
 */
const findSafeMembers = async (tripId, client = db, { status = 'ACTIVE', page, limit } = {}) => {
  const params = [tripId, status];
  let paging = '';
  if (page && limit) {
    params.push(limit, (page - 1) * limit);
    paging = ` LIMIT $3 OFFSET $4`;
  }
  const { rows } = await client.query(`
    SELECT tm.user_id, COALESCE(u.nickname,u.full_name) AS display_name, u.avatar_url,
      tm.role, tm.membership_status, tm.joined_at, tm.left_at, tm.removed_at
    FROM trip_members tm JOIN users u ON u.id=tm.user_id
    WHERE tm.trip_id=$1 AND tm.membership_status=$2
    ORDER BY CASE tm.role WHEN 'LEADER' THEN 0 ELSE 1 END, tm.joined_at ASC${paging}`, params);
  return rows;
};

/**
 * @description Xử lý thao tác thành viên đối với chuyến đi.
 * @param {string} tripId
 * @param {string} status
 * @param {object} client
 */
const countMembersByStatus = async (tripId, status, client = db) => {
  const { rows: [row] } = await client.query(
    'SELECT COUNT(*)::int AS total FROM trip_members WHERE trip_id=$1 AND membership_status=$2',
    [tripId, status]);
  return row.total;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 */
const findMemberProjection = async (client, tripId, userId) => {
  const { rows: [row] } = await client.query(`
    SELECT tm.user_id,COALESCE(u.nickname,u.full_name) AS display_name,u.avatar_url,
      tm.role,tm.membership_status,tm.joined_at,tm.left_at,tm.removed_at
    FROM trip_members tm JOIN users u ON u.id=tm.user_id
    WHERE tm.trip_id=$1 AND tm.user_id=$2`, [tripId, userId]);
  return row || null;
};

/**
 * @description Cập nhật chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {object} data
 */
const updateTrip = async (client, tripId, data) => {
  const map = {
    name: 'name', destination: 'destination', startDate: 'start_date', endDate: 'end_date',
    estimatedBudget: 'estimated_budget', coverImageUrl: 'cover_image_url',
    description: 'description', privacyType: 'privacy_type',
  };
  const sets = [];
  const params = [tripId];
  for (const [key, column] of Object.entries(map)) {
    if (data[key] !== undefined) {
      params.push(data[key] === '' ? null : data[key]);
      sets.push(`${column}=$${params.length}`);
    }
  }
  const { rows: [row] } = await client.query(
    `UPDATE trips SET ${sets.join(', ')} WHERE id=$1 RETURNING *`, params);
  return row;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} durationDays
 */
const hasItineraryOutsideRange = async (client, tripId, durationDays) => {
  const { rowCount } = await client.query(
    'SELECT 1 FROM itineraries WHERE trip_id=$1 AND day_number>$2 LIMIT 1', [tripId, durationDays]);
  return rowCount > 0;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} tripId
 */
const refreshItineraryDates = async (client, tripId) => {
  await client.query(`
    UPDATE itineraries i SET trip_date=t.start_date + (i.day_number - 1)
    FROM trips t WHERE t.id=i.trip_id AND t.id=$1`, [tripId]);
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} status
 */
const setTripStatus = async (client, tripId, status) => {
  const { rows: [row] } = await client.query(
    'UPDATE trips SET status=$2 WHERE id=$1 RETURNING *', [tripId, status]);
  return row;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} tripId
 */
const cancelTrip = async (client, tripId) => {
  const { rows: [row] } = await client.query(`
    UPDATE trips SET status='CANCELLED',
      invite_code_status=CASE WHEN invite_code_status='ACTIVE' THEN 'REVOKED' ELSE invite_code_status END
    WHERE id=$1 RETURNING *`, [tripId]);
  await client.query(`
    UPDATE trip_invitations SET status='EXPIRED'
    WHERE trip_id=$1 AND status='PENDING'`, [tripId]);
  return row;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} userId
 */
const hasActiveBankhub = async (client, userId) => {
  const { rowCount } = await client.query(
    'SELECT 1 FROM bankhub_accounts WHERE user_id=$1 AND active=TRUE LIMIT 1', [userId]);
  return rowCount > 0;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} inviteCode
 */
const findTripByInviteCodeForUpdate = async (client, inviteCode) => {
  const { rows: [row] } = await client.query(
    'SELECT * FROM trips WHERE invite_code=$1 FOR UPDATE', [inviteCode]);
  return row || null;
};

/**
 * @description Xử lý lời mời tham gia chuyến đi.
 * @param {object} client
 * @param {string} tripId
 */
const expireInviteCode = (client, tripId) => client.query(
  "UPDATE trips SET invite_code_status='EXPIRED' WHERE id=$1 AND invite_code_status='ACTIVE'", [tripId]);

/**
 * @description Xử lý thao tác thành viên đối với chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 */
const activateMembership = async (client, tripId, userId) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO trip_members (trip_id,user_id,role,membership_status)
    VALUES ($1,$2,'MEMBER','ACTIVE')
    ON CONFLICT (trip_id,user_id) DO UPDATE SET
      role='MEMBER', membership_status='ACTIVE', joined_at=NOW(),
      left_at=NULL, removed_at=NULL, removed_by=NULL
    RETURNING *`, [tripId, userId]);
  return row;
};

/**
 * @description Xử lý lời mời tham gia chuyến đi.
 * @param {object} client
 * @param {string} tripId
 */
const consumeInviteCode = (client, tripId) => client.query(
  "UPDATE trips SET invite_code_status='USED' WHERE id=$1 AND invite_code_status='ACTIVE'", [tripId]);

/**
 * @description Xử lý thao tác thành viên đối với chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 * @param {string} status
 * @param {string} removedBy
 */
const markMembership = async (client, tripId, userId, status, removedBy = null) => {
  const { rows: [row] } = await client.query(`
    UPDATE trip_members SET membership_status=$3,
      left_at=CASE WHEN $3='LEFT' THEN NOW() ELSE NULL END,
      removed_at=CASE WHEN $3='REMOVED' THEN NOW() ELSE NULL END,
      removed_by=CASE WHEN $3='REMOVED' THEN $4::uuid ELSE NULL END
    WHERE trip_id=$1 AND user_id=$2 AND membership_status='ACTIVE'
    RETURNING *`, [tripId, userId, status, removedBy]);
  return row || null;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} userId
 */
const hasOutstandingDebts = async (client, tripId, userId) => {
  const { rowCount } = await client.query(`
    SELECT 1 FROM settlements WHERE trip_id=$1 AND status IN ('PENDING','REPORTED')
      AND (from_user_id=$2 OR to_user_id=$2) LIMIT 1`, [tripId, userId]);
  return rowCount > 0;
};

/**
 * @description Xử lý phân quyền Trưởng nhóm cho chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} oldLeaderId
 * @param {string} newLeaderId
 */
const transferLeader = async (client, tripId, oldLeaderId, newLeaderId) => {
  await client.query(
    "UPDATE trip_members SET role='MEMBER' WHERE trip_id=$1 AND user_id=$2 AND membership_status='ACTIVE'",
    [tripId, oldLeaderId]);
  const { rows: [member] } = await client.query(
    "UPDATE trip_members SET role='LEADER' WHERE trip_id=$1 AND user_id=$2 AND membership_status='ACTIVE' RETURNING *",
    [tripId, newLeaderId]);
  await client.query('UPDATE trips SET updated_at=NOW() WHERE id=$1', [tripId]);
  return member || null;
};

/**
 * @description Xử lý lời mời tham gia chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} expiresInHours
 */
const generateNewInviteCode = async (client, tripId, expiresInHours) => {
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateInviteCode();
    const { rows: [row] } = await client.query(`
      UPDATE trips SET invite_code=$2, invite_code_status='ACTIVE',
        invite_code_expires_at=NOW() + ($3 * INTERVAL '1 hour')
      WHERE id=$1 AND NOT EXISTS (SELECT 1 FROM trips WHERE invite_code=$2 AND id<>$1)
      RETURNING *`, [tripId, code, expiresInHours]);
    if (row) return row;
  }
  return null;
};

/**
 * @description Xử lý lời mời tham gia chuyến đi.
 * @param {object} client
 * @param {string} tripId
 */
const revokeInviteCode = async (client, tripId) => {
  const { rows: [row] } = await client.query(`
    UPDATE trips SET invite_code_status=CASE WHEN invite_code_status='ACTIVE' THEN 'REVOKED' ELSE invite_code_status END
    WHERE id=$1 RETURNING *`, [tripId]);
  return row;
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} userId
 */
const findUserForInvitation = async (client, userId) => {
  const { rows: [row] } = await client.query(
    "SELECT id,status FROM users WHERE id=$1", [userId]);
  return row || null;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} userId
 */
const isUserVerified = async (client, userId) => {
  const { rows: [row] } = await client.query(
    "SELECT verification_status='VERIFIED' AS verified FROM users WHERE id=$1", [userId]);
  return Boolean(row && row.verified);
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} conditionsSql
 * @param {string} params
 */
const expireInvitations = (client, conditionsSql, params) => client.query(`
  UPDATE trip_invitations SET status='EXPIRED'
  WHERE status='PENDING' AND expires_at<=NOW() AND ${conditionsSql}`, params);

/**
 * @description Tạo mới chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} inviterId
 * @param {string} inviteeId
 * @param {string} expiresInHours
 */
const createInvitation = async (client, tripId, inviterId, inviteeId, expiresInHours) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO trip_invitations (trip_id,inviter_id,invitee_id,expires_at)
    VALUES ($1,$2,$3,NOW() + ($4 * INTERVAL '1 hour')) RETURNING id`,
    [tripId, inviterId, inviteeId, expiresInHours]);
  return row;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 */
const invitationSelect = `
  SELECT ti.*, t.name AS trip_name, t.destination AS trip_destination,
    COALESCE(ui.nickname,ui.full_name) AS inviter_name, ui.avatar_url AS inviter_avatar_url,
    COALESCE(ue.nickname,ue.full_name) AS invitee_name, ue.avatar_url AS invitee_avatar_url
  FROM trip_invitations ti
  JOIN trips t ON t.id=ti.trip_id
  JOIN users ui ON ui.id=ti.inviter_id
  JOIN users ue ON ue.id=ti.invitee_id`;

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} invitationId
 */
const findInvitation = async (client, invitationId) => {
  const { rows: [row] } = await client.query(`${invitationSelect} WHERE ti.id=$1`, [invitationId]);
  return row || null;
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} invitationId
 */
const lockInvitation = async (client, invitationId) => {
  const { rows: [locked] } = await client.query(
    'SELECT * FROM trip_invitations WHERE id=$1 FOR UPDATE', [invitationId]);
  if (!locked) return null;
  return findInvitation(client, invitationId);
};

/**
 * @description Lấy thông tin chuyến đi.
 * @param {object} client
 * @param {string} { tripId
 * @param {string} inviteeId
 * @param {string} status
 * @param {string} page
 * @param {string} limit }
 */
const listInvitations = async (client, { tripId, inviteeId, status, page, limit }) => {
  const params = [];
  const where = [];
  if (tripId) { params.push(tripId); where.push(`ti.trip_id=$${params.length}`); }
  if (inviteeId) { params.push(inviteeId); where.push(`ti.invitee_id=$${params.length}`); }
  if (status) { params.push(status); where.push(`ti.status=$${params.length}`); }
  const clause = where.join(' AND ');
  const { rows: [{ total }] } = await client.query(
    `SELECT COUNT(*)::int AS total FROM trip_invitations ti WHERE ${clause}`, params);
  params.push(limit, (page - 1) * limit);
  const { rows } = await client.query(`${invitationSelect} WHERE ${clause}
    ORDER BY ti.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return { rows, total };
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} invitationId
 * @param {string} status
 */
const setInvitationStatus = async (client, invitationId, status) => {
  await client.query(`UPDATE trip_invitations SET status=$2 WHERE id=$1`, [invitationId, status]);
  return findInvitation(client, invitationId);
};

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {object} client
 * @param {string} userId
 * @param {string} title
 * @param {string} message
 * @param {object} data
 */
const notify = async (client, userId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    VALUES ($1,$2,$3,'TRIP_UPDATE',$4::jsonb)`,
    [userId, title, message, JSON.stringify(data)]);
};

/**
 * @description Xử lý thao tác thành viên đối với chuyến đi.
 * @param {object} client
 * @param {string} tripId
 * @param {string} actorId
 * @param {string} title
 * @param {string} message
 * @param {object} data
 */
const notifyActiveMembers = async (client, tripId, actorId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    SELECT tm.user_id,$3,$4,'TRIP_UPDATE',$5::jsonb FROM trip_members tm
    WHERE tm.trip_id=$1 AND tm.membership_status='ACTIVE' AND tm.user_id<>$2`,
    [tripId, actorId, title, message, JSON.stringify(data)]);
};

module.exports = {
  generateInviteCode, lockTrip, getMembership, createTrip, findMyTrips,
  findTripForMember, findSafeMembers, countMembersByStatus, findMemberProjection, updateTrip,
  hasItineraryOutsideRange, refreshItineraryDates, setTripStatus, cancelTrip,
  hasActiveBankhub, findTripByInviteCodeForUpdate, expireInviteCode,
  activateMembership, consumeInviteCode, markMembership, hasOutstandingDebts,
  transferLeader, generateNewInviteCode, revokeInviteCode, findUserForInvitation, isUserVerified,
  expireInvitations, createInvitation, findInvitation, lockInvitation,
  listInvitations, setInvitationStatus, notify, notifyActiveMembers,
};
