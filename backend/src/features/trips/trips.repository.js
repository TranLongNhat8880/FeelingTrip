const crypto = require('crypto');
const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Trips
// Giao tiếp với cơ sở dữ liệu cho các bảng trips, trip_members, trip_invitations
// ============================================================================

/**
 * @description Tạo mã mời ngẫu nhiên 6 ký tự.
 */
const generateInviteCode = () => crypto.randomBytes(3).toString('hex').toUpperCase();

/**
 * @description Lấy thông tin chuyến đi và khóa dòng để chuẩn bị update.
 */
const lockTrip = async (client, tripId) => {
  const { rows: [row] } = await client.query('SELECT * FROM trips WHERE id = $1 FOR UPDATE', [tripId]);
  return row || null;
};

/**
 * @description Lấy trạng thái thành viên của một user trong chuyến đi.
 */
const getMembership = async (client, tripId, userId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trip_members WHERE trip_id = $1 AND user_id = $2${forUpdate ? ' FOR UPDATE' : ''}`,
    [tripId, userId]);
  return row || null;
};

/**
 * @description Tạo chuyến đi mới và tự động gán quyền trưởng nhóm cho người tạo.
 */
const createTrip = async (client, userId, data) => {
  const { rows: [trip] } = await client.query(`
    INSERT INTO trips (
      creator_id, name, destination, start_date, end_date, estimated_budget,
      cover_image_url, description, privacy_type, status
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'UPCOMING')
    RETURNING *`, [userId, data.name, data.destination, data.startDate, data.endDate,
    data.estimatedBudget ?? 0, data.coverImageUrl || null, data.description || null,
    data.privacyType || 'PRIVATE']);
  await client.query(`
    INSERT INTO trip_members (trip_id,user_id,role,membership_status)
    VALUES ($1,$2,'LEADER','ACTIVE')`, [trip.id, userId]);
  return trip;
};

/**
 * @description Lấy danh sách chuyến đi của user (có phân trang và lọc trạng thái).
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
 * @description Lấy chi tiết chuyến đi (chỉ dành cho thành viên nhóm).
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
 * @description Lấy danh sách thành viên của chuyến đi (có phân trang).
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
 * @description Đếm số lượng thành viên trong chuyến đi theo trạng thái.
 */
const countMembersByStatus = async (tripId, status, client = db) => {
  const { rows: [row] } = await client.query(
    'SELECT COUNT(*)::int AS total FROM trip_members WHERE trip_id=$1 AND membership_status=$2',
    [tripId, status]);
  return row.total;
};

/**
 * @description Lấy thông tin hiển thị cơ bản của một thành viên.
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
 * @description Cập nhật các thông tin chung của chuyến đi.
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
 * @description Kiểm tra xem có ngày lịch trình nào bị lố thời gian khi rút ngắn chuyến đi không.
 */
const hasItineraryOutsideRange = async (client, tripId, durationDays) => {
  const { rowCount } = await client.query(
    'SELECT 1 FROM itineraries WHERE trip_id=$1 AND day_number>$2 LIMIT 1', [tripId, durationDays]);
  return rowCount > 0;
};

/**
 * @description Cập nhật lại ngày tháng thực tế cho lịch trình sau khi đổi ngày bắt đầu.
 */
const refreshItineraryDates = async (client, tripId) => {
  await client.query(`
    UPDATE itineraries i SET trip_date=t.start_date + (i.day_number - 1)
    FROM trips t WHERE t.id=i.trip_id AND t.id=$1`, [tripId]);
};

/**
 * @description Cập nhật trạng thái chuyến đi (sắp tới, đang diễn ra, đã kết thúc).
 */
const setTripStatus = async (client, tripId, status) => {
  const { rows: [row] } = await client.query(
    'UPDATE trips SET status=$2 WHERE id=$1 RETURNING *', [tripId, status]);
  return row;
};

/**
 * @description Hủy chuyến đi và vô hiệu hóa tất cả các mã mời/lời mời.
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
 * @description Lấy thông tin chuyến đi qua mã mời và khóa dòng để kiểm tra.
 */
const findTripByInviteCodeForUpdate = async (client, inviteCode) => {
  const { rows: [row] } = await client.query(
    'SELECT * FROM trips WHERE invite_code=$1 FOR UPDATE', [inviteCode]);
  return row || null;
};

/**
 * @description Thêm người mới vào chuyến đi hoặc kích hoạt lại thành viên cũ.
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
 * @description Đánh dấu mã mời đã được sử dụng.
 */
const consumeInviteCode = (client, tripId) => client.query(
  "UPDATE trips SET invite_code_status='USED' WHERE id=$1 AND invite_code_status='ACTIVE'", [tripId]);

/**
 * @description Đổi trạng thái thành viên (khi tự rời đi hoặc bị kick).
 */
const markMembership = async (client, tripId, userId, status, removedBy = null) => {
  const { rows: [row] } = await client.query(`
    UPDATE trip_members SET membership_status=$3::varchar,
      left_at=CASE WHEN $3::varchar='LEFT' THEN NOW() ELSE NULL END,
      removed_at=CASE WHEN $3::varchar='REMOVED' THEN NOW() ELSE NULL END,
      removed_by=CASE WHEN $3::varchar='REMOVED' THEN $4::uuid ELSE NULL END
    WHERE trip_id=$1 AND user_id=$2 AND membership_status='ACTIVE'
    RETURNING *`, [tripId, userId, status, removedBy]);
  return row || null;
};

/**
 * @description Kiểm tra thành viên có khoản chia tiền nào chưa thanh toán xong không.
 */
const hasOutstandingDebts = async (client, tripId, userId) => {
  // 1. Kiểm tra các settlement đang mở (PENDING hoặc REPORTED)
  const { rowCount } = await client.query(`
    SELECT 1 FROM settlements WHERE trip_id=$1 AND status IN ('PENDING','REPORTED')
      AND (from_user_id=$2 OR to_user_id=$2) LIMIT 1`, [tripId, userId]);
  if (rowCount > 0) return true;

  // 2. Kiểm tra các khoản chi tiêu chưa quyết toán trong chuyến đi
  const { rows } = await client.query(`
    WITH ledger AS (
      SELECT payer_id AS user_id, amount AS delta
        FROM expenses WHERE trip_id = $1
      UNION ALL
      SELECT es.user_id, -es.amount_owed
        FROM expense_splits es JOIN expenses e ON e.id = es.expense_id WHERE e.trip_id = $1
      UNION ALL SELECT from_user_id, amount FROM settlements WHERE trip_id = $1 AND status = 'PAID'
      UNION ALL SELECT to_user_id, -amount FROM settlements WHERE trip_id = $1 AND status = 'PAID'
    )
    SELECT COALESCE(SUM(delta), 0) AS balance
    FROM ledger WHERE user_id = $2`, [tripId, userId]);

  return rows.length > 0 && Number(rows[0].balance) < 0;
};

/**
 * @description Chuyển quyền trưởng nhóm cho một thành viên khác.
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
 * @description Tạo và cấp mã mời mới cho chuyến đi.
 */
const generateNewInviteCode = async (client, tripId) => {
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateInviteCode();
    const { rows: [row] } = await client.query(`
      UPDATE trips SET invite_code=$2, invite_code_status='ACTIVE'
      WHERE id=$1 AND NOT EXISTS (SELECT 1 FROM trips WHERE invite_code=$2 AND id<>$1)
      RETURNING *`, [tripId, code]);
    if (row) return row;
  }
  return null;
};

/**
 * @description Thu hồi mã mời hiện tại của chuyến đi.
 */
const revokeInviteCode = async (client, tripId) => {
  const { rows: [row] } = await client.query(`
    UPDATE trips SET invite_code_status=CASE WHEN invite_code_status='ACTIVE' THEN 'REVOKED' ELSE invite_code_status END
    WHERE id=$1 RETURNING *`, [tripId]);
  return row;
};

/**
 * @description Kiểm tra thông tin tài khoản của người được mời.
 */
const findUserForInvitation = async (client, userId) => {
  const { rows: [row] } = await client.query(
    "SELECT id,status FROM users WHERE id=$1", [userId]);
  return row || null;
};

/**
 * @description Kiểm tra tài khoản user đã xác minh chưa.
 */
const isUserVerified = async (client, userId) => {
  const { rows: [row] } = await client.query(
    "SELECT (UPPER(COALESCE(verification_status, '')) = 'VERIFIED' OR is_verified = TRUE) AS verified FROM users WHERE id=$1", [userId]);
  return Boolean(row && row.verified);
};

/**
 * @description Đánh dấu các lời mời đã hết thời gian hiệu lực.
 */
const expireInvitations = (client, conditionsSql, params) => client.query(`
  UPDATE trip_invitations SET status='EXPIRED'
  WHERE status='PENDING' AND expires_at<=NOW() AND ${conditionsSql}`, params);

/**
 * @description Gửi lời mời trực tiếp đến một user.
 */
const createInvitation = async (client, tripId, inviterId, inviteeId, expiresInHours) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO trip_invitations (trip_id,inviter_id,invitee_id,expires_at)
    VALUES ($1,$2,$3,NOW() + ($4 * INTERVAL '1 hour')) RETURNING id`,
    [tripId, inviterId, inviteeId, expiresInHours]);
  return row;
};

/**
 * @description Câu query gốc để lấy thông tin chi tiết của lời mời.
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
 * @description Lấy thông tin chi tiết của một lời mời cụ thể.
 */
const findInvitation = async (client, invitationId) => {
  const { rows: [row] } = await client.query(`${invitationSelect} WHERE ti.id=$1`, [invitationId]);
  return row || null;
};

/**
 * @description Khóa dòng lời mời để xử lý chấp nhận/từ chối an toàn.
 */
const lockInvitation = async (client, invitationId) => {
  const { rows: [locked] } = await client.query(
    'SELECT * FROM trip_invitations WHERE id=$1 FOR UPDATE', [invitationId]);
  if (!locked) return null;
  return findInvitation(client, invitationId);
};

/**
 * @description Lấy danh sách lời mời (có phân trang và lọc).
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
 * @description Cập nhật trạng thái của lời mời (chấp nhận, từ chối, thu hồi).
 */
const setInvitationStatus = async (client, invitationId, status) => {
  await client.query(`
    UPDATE trip_invitations SET status=$2::varchar,
      responded_at=CASE WHEN $2::varchar IN ('ACCEPTED','REJECTED') THEN NOW() ELSE responded_at END,
      revoked_at=CASE WHEN $2::varchar='REVOKED' THEN NOW() ELSE revoked_at END
    WHERE id=$1`, [invitationId, status]);
  return findInvitation(client, invitationId);
};

/**
 * @description Tạo thông báo mới cho một user.
 */
const notify = async (client, userId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    VALUES ($1,$2,$3,'TRIP_UPDATE',$4::jsonb)`,
    [userId, title, message, JSON.stringify(data)]);
};

/**
 * @description Gửi thông báo cho tất cả các thành viên đang hoạt động trong chuyến đi.
 */
const notifyActiveMembers = async (client, tripId, actorId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    SELECT tm.user_id,$3::varchar,$4::text,'TRIP_UPDATE',$5::jsonb FROM trip_members tm
    WHERE tm.trip_id=$1 AND tm.membership_status='ACTIVE' AND tm.user_id<>$2`,
    [tripId, actorId, title, message, JSON.stringify(data)]);
};

module.exports = {
  generateInviteCode, lockTrip, getMembership, createTrip, findMyTrips,
  findTripForMember, findSafeMembers, countMembersByStatus, findMemberProjection, updateTrip,
  hasItineraryOutsideRange, refreshItineraryDates, setTripStatus, cancelTrip,
  findTripByInviteCodeForUpdate,
  activateMembership, consumeInviteCode, markMembership, hasOutstandingDebts,
  transferLeader, generateNewInviteCode, revokeInviteCode, findUserForInvitation, isUserVerified,
  expireInvitations, createInvitation, findInvitation, lockInvitation,
  listInvitations, setInvitationStatus, notify, notifyActiveMembers,
};
