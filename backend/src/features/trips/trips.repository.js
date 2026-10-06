const crypto = require('crypto');
const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Trips
// Giao tiếp với cơ sở dữ liệu cho các bảng trips, trip_members, trip_invitations
// ============================================================================

/**
 * @description Sinh ngẫu nhiên mã mời gồm 6 ký tự HEX viết hoa (ví dụ: "A1B2C3").
 * Không truy vấn DB; việc kiểm tra trùng mã nằm ở generateNewInviteCode.
 */
const generateInviteCode = () => crypto.randomBytes(3).toString('hex').toUpperCase();

/**
 * @description Lấy toàn bộ thông tin một chuyến đi theo id và KHÓA dòng đó (SELECT ... FOR UPDATE).
 * Bảng: trips.
 * Dùng trong transaction để chặn request khác sửa cùng chuyến đi một lúc (tránh race condition).
 * Trả về: object chuyến đi hoặc null nếu không tồn tại.
 */
const lockTrip = async (client, tripId) => {
  const { rows: [row] } = await client.query('SELECT * FROM trips WHERE id = $1 FOR UPDATE', [tripId]);
  return row || null;
};

/**
 * @description Lấy bản ghi thành viên của một người dùng trong một chuyến đi (mọi trạng thái).
 * Bảng: trip_members, lọc theo trip_id + user_id.
 * Nếu forUpdate = true thì khóa dòng (FOR UPDATE) để cập nhật an toàn trong transaction.
 * Trả về: bản ghi trip_members (gồm role, membership_status) hoặc null.
 */
const getMembership = async (client, tripId, userId, forUpdate = false) => {
  const { rows: [row] } = await client.query(
    `SELECT * FROM trip_members WHERE trip_id = $1 AND user_id = $2${forUpdate ? ' FOR UPDATE' : ''}`,
    [tripId, userId]);
  return row || null;
};

/**
 * @description Tạo chuyến đi mới và tự động thêm người tạo làm trưởng nhóm.
 * Bước 1: INSERT vào bảng trips với privacy_type = PRIVATE, status = UPCOMING.
 * Bước 2: INSERT vào bảng trip_members với role = LEADER, membership_status = ACTIVE.
 * Phải gọi trong transaction để 2 câu lệnh cùng thành công hoặc cùng bị hủy.
 * Trả về: object chuyến đi vừa tạo.
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
 * @description Lấy danh sách chuyến đi của người dùng, có lọc và phân trang.
 * Bảng: trips JOIN trip_members.
 * Mặc định chỉ lấy chuyến mà người dùng còn ACTIVE; includeHistory = true thì lấy cả chuyến đã rời/bị loại.
 * Có thể lọc theo trạng thái chuyến đi (status).
 * Câu 1: COUNT(*) để đếm tổng số bản ghi phục vụ phân trang.
 * Câu 2: lấy dữ liệu kèm vai trò của người dùng và số thành viên ACTIVE (member_count).
 * Sắp xếp: ONGOING trước, rồi UPCOMING (ngày bắt đầu gần nhất trước), cuối cùng COMPLETED/CANCELLED (kết thúc gần nhất trước).
 * Phân trang: LIMIT = limit, OFFSET = (page - 1) * limit.
 * Trả về: { rows, total }.
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
 * @description Lấy chi tiết một chuyến đi, chỉ khi người dùng đang là thành viên ACTIVE.
 * Bảng: trips JOIN trip_members.
 * Kèm theo: vai trò của người dùng (member_role) và số thành viên ACTIVE (member_count).
 * Trả về: object chuyến đi hoặc null (không tồn tại hoặc không có quyền xem).
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
 * @description Lấy danh sách thành viên của chuyến đi theo trạng thái (mặc định ACTIVE).
 * Bảng: trip_members JOIN users.
 * Chỉ lấy thông tin an toàn để hiển thị: tên hiển thị (ưu tiên nickname, không có thì full_name), avatar,
 * vai trò, trạng thái và các mốc thời gian. KHÔNG trả về email hay số điện thoại.
 * Sắp xếp: trưởng nhóm lên đầu, sau đó theo thời gian tham gia sớm nhất.
 * Chỉ phân trang (LIMIT/OFFSET) khi có truyền page và limit.
 * Trả về: mảng thành viên.
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
 * @description Đếm số thành viên của chuyến đi theo trạng thái (ACTIVE / LEFT / REMOVED).
 * Bảng: trip_members.
 * Dùng để tính tổng số bản ghi khi phân trang danh sách thành viên.
 * Trả về: số nguyên.
 */
const countMembersByStatus = async (tripId, status, client = db) => {
  const { rows: [row] } = await client.query(
    'SELECT COUNT(*)::int AS total FROM trip_members WHERE trip_id=$1 AND membership_status=$2',
    [tripId, status]);
  return row.total;
};

/**
 * @description Lấy thông tin hiển thị của MỘT thành viên trong chuyến đi (mọi trạng thái).
 * Bảng: trip_members JOIN users.
 * Dùng để trả kết quả sau khi tham gia, rời nhóm hoặc bị loại.
 * Trả về: object thành viên hoặc null.
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
 * @description Cập nhật thông tin chuyến đi, chỉ cập nhật các trường được gửi lên.
 * Bảng: trips.
 * Câu UPDATE được ghép động: trường nào có trong data mới đưa vào SET. Chuỗi rỗng được lưu thành NULL.
 * Tên cột lấy từ danh sách cố định (map) nên không bị SQL injection.
 * Trả về: object chuyến đi sau khi cập nhật.
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
 * @description Kiểm tra chuyến đi có ngày lịch trình nào vượt quá số ngày mới hay không.
 * Bảng: itineraries, điều kiện day_number > durationDays.
 * Dùng khi rút ngắn chuyến đi để không làm mất các ngày đã có lịch trình.
 * Trả về: true nếu có ngày nằm ngoài khoảng mới.
 */
const hasItineraryOutsideRange = async (client, tripId, durationDays) => {
  const { rowCount } = await client.query(
    'SELECT 1 FROM itineraries WHERE trip_id=$1 AND day_number>$2 LIMIT 1', [tripId, durationDays]);
  return rowCount > 0;
};

/**
 * @description Tính lại ngày thực tế (trip_date) cho các ngày lịch trình sau khi đổi ngày bắt đầu.
 * Bảng: itineraries (UPDATE ... FROM trips).
 * Công thức: trip_date = start_date của chuyến đi + (day_number - 1).
 */
const refreshItineraryDates = async (client, tripId) => {
  await client.query(`
    UPDATE itineraries i SET trip_date=t.start_date + (i.day_number - 1)
    FROM trips t WHERE t.id=i.trip_id AND t.id=$1`, [tripId]);
};

/**
 * @description Đổi trạng thái chuyến đi (UPCOMING / ONGOING / COMPLETED).
 * Bảng: trips.
 * Trả về: object chuyến đi sau khi cập nhật.
 */
const setTripStatus = async (client, tripId, status) => {
  const { rows: [row] } = await client.query(
    'UPDATE trips SET status=$2 WHERE id=$1 RETURNING *', [tripId, status]);
  return row;
};

/**
 * @description Hủy chuyến đi (xóa mềm, không xóa dữ liệu).
 * Bước 1: bảng trips, đổi status = CANCELLED; nếu mã mời đang ACTIVE thì chuyển sang REVOKED.
 * Bước 2: bảng trip_invitations, chuyển các lời mời đang PENDING sang EXPIRED.
 * Trả về: object chuyến đi sau khi hủy.
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
 * @description Kiểm tra người dùng đã liên kết tài khoản ngân hàng (Bank Hub) và còn hoạt động hay chưa.
 * Bảng: bankhub_accounts, điều kiện active = TRUE.
 * Dùng trước khi cho tham gia chuyến đi, vì tính năng chia tiền cần tài khoản ngân hàng.
 * Trả về: true / false.
 */
const hasActiveBankhub = async (client, userId) => {
  const { rowCount } = await client.query(
    'SELECT 1 FROM bankhub_accounts WHERE user_id=$1 AND active=TRUE LIMIT 1', [userId]);
  return rowCount > 0;
};

/**
 * @description Tìm chuyến đi theo mã mời và khóa dòng đó (FOR UPDATE).
 * Bảng: trips.
 * Khóa để 2 người không dùng cùng một mã mời cùng lúc.
 * Trả về: object chuyến đi hoặc null.
 */
const findTripByInviteCodeForUpdate = async (client, inviteCode) => {
  const { rows: [row] } = await client.query(
    'SELECT * FROM trips WHERE invite_code=$1 FOR UPDATE', [inviteCode]);
  return row || null;
};

/**
 * @description Đánh dấu mã mời đã hết hạn (ACTIVE -> EXPIRED).
 * Bảng: trips. Chỉ cập nhật khi mã mời đang ACTIVE.
 */
const expireInviteCode = (client, tripId) => client.query(
  "UPDATE trips SET invite_code_status='EXPIRED' WHERE id=$1 AND invite_code_status='ACTIVE'", [tripId]);

/**
 * @description Thêm người dùng vào chuyến đi với vai trò MEMBER, trạng thái ACTIVE.
 * Bảng: trip_members.
 * Dùng INSERT ... ON CONFLICT: nếu người này từng ở trong chuyến (đã rời hoặc bị loại) thì kích hoạt lại
 * bản ghi cũ, đặt lại joined_at và xóa left_at / removed_at / removed_by, thay vì tạo bản ghi trùng.
 * Trả về: bản ghi trip_members sau khi thêm hoặc kích hoạt lại.
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
 * @description Đánh dấu mã mời đã được sử dụng (ACTIVE -> USED). Mỗi mã chỉ dùng được 1 lần.
 * Bảng: trips.
 */
const consumeInviteCode = (client, tripId) => client.query(
  "UPDATE trips SET invite_code_status='USED' WHERE id=$1 AND invite_code_status='ACTIVE'", [tripId]);

/**
 * @description Chuyển trạng thái thành viên khi rời nhóm (LEFT) hoặc bị loại (REMOVED). Đây là xóa mềm.
 * Bảng: trip_members. Chỉ cập nhật thành viên đang ACTIVE.
 * LEFT    -> ghi left_at = NOW().
 * REMOVED -> ghi removed_at = NOW() và removed_by = id người thực hiện.
 * Không xóa bản ghi để giữ lại lịch sử chi tiêu, chia tiền của người đó.
 * Trả về: bản ghi sau khi cập nhật hoặc null.
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
 * @description Kiểm tra người dùng còn khoản nợ chưa thanh toán xong trong chuyến đi hay không.
 * Bảng: settlements (thuộc phân hệ Expenses), trạng thái PENDING hoặc REPORTED,
 * người dùng là người nợ (from_user_id) hoặc người được trả (to_user_id).
 * Dùng khi rời nhóm / bị loại để báo người đó vẫn cần quyền truy cập phần tài chính.
 * Trả về: true nếu còn nợ chưa xong.
 */
const hasOutstandingDebts = async (client, tripId, userId) => {
  const { rowCount } = await client.query(`
    SELECT 1 FROM settlements WHERE trip_id=$1 AND status IN ('PENDING','REPORTED')
      AND (from_user_id=$2 OR to_user_id=$2) LIMIT 1`, [tripId, userId]);
  return rowCount > 0;
};

/**
 * @description Chuyển quyền trưởng nhóm từ người cũ sang người mới.
 * Bước 1: bảng trip_members, hạ trưởng nhóm cũ xuống MEMBER.
 * Bước 2: bảng trip_members, nâng người mới lên LEADER (phải đang ACTIVE).
 * Bước 3: bảng trips, cập nhật updated_at.
 * Bước 1 phải chạy trước vì DB chỉ cho phép mỗi chuyến đi có 1 LEADER đang ACTIVE.
 * Trả về: bản ghi của trưởng nhóm mới hoặc null.
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
 * @description Tạo mã mời mới cho chuyến đi và đặt thời hạn hết hạn.
 * Bảng: trips. Gán invite_code mới, invite_code_status = ACTIVE,
 * invite_code_expires_at = NOW() + số giờ hiệu lực.
 * Điều kiện NOT EXISTS đảm bảo mã không trùng với chuyến đi khác; nếu trùng thì thử lại, tối đa 8 lần.
 * Trả về: object chuyến đi sau khi cập nhật, hoặc null nếu thử 8 lần vẫn trùng.
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
 * @description Thu hồi mã mời đang dùng (ACTIVE -> REVOKED); các trạng thái khác giữ nguyên.
 * Bảng: trips.
 * Trả về: object chuyến đi sau khi cập nhật.
 */
const revokeInviteCode = async (client, tripId) => {
  const { rows: [row] } = await client.query(`
    UPDATE trips SET invite_code_status=CASE WHEN invite_code_status='ACTIVE' THEN 'REVOKED' ELSE invite_code_status END
    WHERE id=$1 RETURNING *`, [tripId]);
  return row;
};

/**
 * @description Lấy id và trạng thái tài khoản (ACTIVE / BANNED) của người được mời.
 * Bảng: users.
 * Dùng để kiểm tra người được mời có tồn tại và không bị khóa.
 * Trả về: { id, status } hoặc null.
 */
const findUserForInvitation = async (client, userId) => {
  const { rows: [row] } = await client.query(
    "SELECT id,status FROM users WHERE id=$1", [userId]);
  return row || null;
};

/**
 * @description Kiểm tra người dùng đã xác minh tài khoản hay chưa (verification_status = VERIFIED).
 * Bảng: users.
 * Trả về: true / false.
 */
const isUserVerified = async (client, userId) => {
  const { rows: [row] } = await client.query(
    "SELECT verification_status='VERIFIED' AS verified FROM users WHERE id=$1", [userId]);
  return Boolean(row && row.verified);
};

/**
 * @description Chuyển các lời mời đang PENDING đã quá hạn (expires_at <= NOW()) sang EXPIRED.
 * Bảng: trip_invitations.
 * conditionsSql là điều kiện lọc thêm do service truyền vào (ví dụ: theo trip_id hoặc invitee_id).
 * Chạy trước khi đọc danh sách lời mời để dữ liệu luôn đúng trạng thái.
 */
const expireInvitations = (client, conditionsSql, params) => client.query(`
  UPDATE trip_invitations SET status='EXPIRED'
  WHERE status='PENDING' AND expires_at<=NOW() AND ${conditionsSql}`, params);

/**
 * @description Tạo lời mời đích danh một người dùng vào chuyến đi.
 * Bảng: trip_invitations. Trạng thái mặc định là PENDING,
 * expires_at = NOW() + số giờ hiệu lực.
 * DB đã có unique index nên mỗi người chỉ có tối đa 1 lời mời PENDING cho một chuyến đi.
 * Trả về: { id } của lời mời vừa tạo.
 */
const createInvitation = async (client, tripId, inviterId, inviteeId, expiresInHours) => {
  const { rows: [row] } = await client.query(`
    INSERT INTO trip_invitations (trip_id,inviter_id,invitee_id,expires_at)
    VALUES ($1,$2,$3,NOW() + ($4 * INTERVAL '1 hour')) RETURNING id`,
    [tripId, inviterId, inviteeId, expiresInHours]);
  return row;
};

/**
 * @description Câu SELECT dùng chung để lấy lời mời kèm thông tin hiển thị.
 * Bảng: trip_invitations JOIN trips (tên, điểm đến)
 * JOIN users 2 lần: ui là người gửi lời mời, ue là người được mời (tên hiển thị + avatar).
 * Các hàm findInvitation, listInvitations sẽ nối thêm WHERE vào câu này.
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
 * @description Lấy chi tiết một lời mời theo id, kèm thông tin chuyến đi, người mời và người được mời.
 * Dùng câu invitationSelect + WHERE ti.id.
 * Trả về: object lời mời hoặc null.
 */
const findInvitation = async (client, invitationId) => {
  const { rows: [row] } = await client.query(`${invitationSelect} WHERE ti.id=$1`, [invitationId]);
  return row || null;
};

/**
 * @description Khóa dòng lời mời (FOR UPDATE) rồi lấy đầy đủ thông tin của lời mời đó.
 * Bảng: trip_invitations.
 * Dùng khi chấp nhận / từ chối / thu hồi để tránh 2 thao tác xử lý cùng một lời mời.
 * Trả về: object lời mời hoặc null.
 */
const lockInvitation = async (client, invitationId) => {
  const { rows: [locked] } = await client.query(
    'SELECT * FROM trip_invitations WHERE id=$1 FOR UPDATE', [invitationId]);
  if (!locked) return null;
  return findInvitation(client, invitationId);
};

/**
 * @description Lấy danh sách lời mời có lọc và phân trang.
 * Lọc theo: tripId (lời mời của một chuyến đi), inviteeId (lời mời gửi tới tôi), status.
 * Câu 1: COUNT(*) để đếm tổng số bản ghi.
 * Câu 2: invitationSelect + WHERE, sắp xếp lời mời mới nhất lên đầu.
 * Phân trang: LIMIT = limit, OFFSET = (page - 1) * limit.
 * Trả về: { rows, total }.
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
 * @description Cập nhật trạng thái lời mời (ACCEPTED / REJECTED / REVOKED).
 * Bảng: trip_invitations.
 * Trả về: lời mời sau khi cập nhật, kèm đầy đủ thông tin hiển thị.
 */
const setInvitationStatus = async (client, invitationId, status) => {
  await client.query(`UPDATE trip_invitations SET status=$2 WHERE id=$1`, [invitationId, status]);
  return findInvitation(client, invitationId);
};

/**
 * @description Gửi thông báo cho MỘT người dùng.
 * Bảng: notifications (thuộc phân hệ Notifications), type = TRIP_UPDATE,
 * data là JSON chứa thông tin kèm theo (tripId, invitationId...).
 * Chạy chung transaction với thao tác chính nên nếu thao tác lỗi thì thông báo cũng không được tạo.
 */
const notify = async (client, userId, title, message, data) => {
  await client.query(`
    INSERT INTO notifications (user_id,title,message,type,data)
    VALUES ($1,$2,$3,'TRIP_UPDATE',$4::jsonb)`,
    [userId, title, message, JSON.stringify(data)]);
};

/**
 * @description Gửi thông báo cho TẤT CẢ thành viên ACTIVE của chuyến đi, trừ người thực hiện thao tác.
 * Bảng: notifications, dùng INSERT ... SELECT từ trip_members.
 * Chỉ cần 1 câu lệnh cho cả nhóm thay vì lặp gửi từng người.
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
