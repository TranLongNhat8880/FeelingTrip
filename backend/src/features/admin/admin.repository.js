const db = require("../../config/database");

/**
 * Lấy danh sách người dùng với phân trang và bộ lọc
 */
const getUsersList = async ({
  limit = 20,
  offset = 0,
  search,
  role,
  status,
}) => {
  const conditions = [];
  const params = [];

  if (search) {
    params.push(`%${search}%`);
    conditions.push(
      `(u.email ILIKE $${params.length} OR u.full_name ILIKE $${params.length})`,
    );
  }

  if (role) {
    params.push(role);
    conditions.push(`u.role = $${params.length}`);
  }

  if (status) {
    params.push(status);
    conditions.push(`u.status = $${params.length}`);
  }

  const whereClause =
    conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

  const countQuery = `
    SELECT COUNT(*)::int AS total
    FROM users u
    ${whereClause}
  `;
  const { rows: countRows } = await db.query(countQuery, params);
  const total = countRows[0]?.total || 0;

  const dataParams = [...params];
  dataParams.push(limit);
  const limitPlaceholder = `$${dataParams.length}`;
  dataParams.push(offset);
  const offsetPlaceholder = `$${dataParams.length}`;

  const dataQuery = `
    SELECT
      u.id,
      u.full_name,
      u.email,
      u.phone,
      u.avatar_url,
      u.role,
      u.status,
      u.is_verified,
      u.verification_status,
      u.created_at,
      u.updated_at
    FROM users u
    ${whereClause}
    ORDER BY u.created_at DESC, u.id DESC
    LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}
  `;

  const { rows } = await db.query(dataQuery, dataParams);
  return { rows, total };
};

/**
 * Cập nhật trạng thái tài khoản (khóa / mở khóa)
 * Khi BANNED → tăng token_version để vô hiệu hóa JWT hiện tại
 */
const updateUserStatus = async (userId, status) => {
  let query;
  if (status === "BANNED") {
    query = `
      UPDATE users
      SET status = $2,
          token_version = COALESCE(token_version, 0) + 1,
          updated_at = NOW()
      WHERE id = $1
      RETURNING id, full_name, email, role, status, token_version, updated_at
    `;
  } else {
    query = `
      UPDATE users
      SET status = $2,
          updated_at = NOW()
      WHERE id = $1
      RETURNING id, full_name, email, role, status, token_version, updated_at
    `;
  }
  const { rows } = await db.query(query, [userId, status]);
  return rows[0] || null;
};

/**
 * Lấy danh sách hồ sơ eKYC đang chờ duyệt
 */
const getPendingEkycList = async ({ limit = 20, offset = 0 }) => {
  const countQuery = `
    SELECT COUNT(*)::int AS total
    FROM users
    WHERE verification_status = 'PENDING'
  `;
  const { rows: countRows } = await db.query(countQuery);
  const total = countRows[0]?.total || 0;

  const dataQuery = `
    SELECT
      id,
      full_name,
      email,
      phone,
      avatar_url,
      cccd_number,
      cccd_front_image,
      cccd_back_image,
      selfie_image,
      verification_status,
      updated_at AS ekyc_submitted_at
    FROM users
    WHERE verification_status = 'PENDING'
    ORDER BY updated_at ASC, id ASC
    LIMIT $1 OFFSET $2
  `;
  const { rows } = await db.query(dataQuery, [limit, offset]);
  return { rows, total };
};

/**
 * Tìm thông tin user theo ID (dùng để kiểm tra trước khi approve/reject)
 */
const findUserById = async (userId) => {
  const query = `
    SELECT id, full_name, email, role, status, is_verified, verification_status
    FROM users
    WHERE id = $1
    LIMIT 1
  `;
  const { rows } = await db.query(query, [userId]);
  return rows[0] || null;
};

/**
 * Duyệt hồ sơ eKYC → VERIFIED
 */
const approveUserEkyc = async (userId) => {
  const query = `
    UPDATE users
    SET
      verification_status = 'VERIFIED',
      is_verified = TRUE,
      verification_rejection_reason = NULL,
      updated_at = NOW()
    WHERE id = $1 AND verification_status = 'PENDING'
    RETURNING id, full_name, email, is_verified, verification_status, updated_at
  `;
  const { rows } = await db.query(query, [userId]);
  return rows[0] || null;
};

/**
 * Từ chối hồ sơ eKYC → REJECTED
 */
const rejectUserEkyc = async (userId, reason) => {
  const query = `
    UPDATE users
    SET
      verification_status = 'REJECTED',
      is_verified = FALSE,
      verification_rejection_reason = $2,
      updated_at = NOW()
    WHERE id = $1 AND verification_status = 'PENDING'
    RETURNING id, full_name, email, is_verified, verification_status, verification_rejection_reason, updated_at
  `;
  const { rows } = await db.query(query, [userId, reason]);
  return rows[0] || null;
};

// Lấy danh sách báo cáo kèm tên người gửi, người bị báo cáo và chuyến đi
const getReports = async ({ page, limit, status, search }) => {
  const params = [];
  const conditions = [];

  if (status) {
    params.push(status);
    conditions.push(`r.status=$${params.length}`);
  }
  if (search) {
    params.push(`%${search}%`);
    conditions.push(
      `(r.reason ILIKE $${params.length} OR target.full_name ILIKE $${params.length} OR t.name ILIKE $${params.length})`,
    );
  }

  const where = conditions.length ? "WHERE " + conditions.join(" AND ") : "";
  const from = `
    FROM user_reports r
    JOIN users sender ON sender.id=r.reporter_id
    LEFT JOIN users target ON target.id=r.reported_user_id
    LEFT JOIN trips t ON t.id=r.reported_trip_id
  `;
  const countQuery = `SELECT COUNT(*)::int AS total ${from} ${where}`;
  const { rows: countRows } = await db.query(countQuery, params);
  const total = countRows[0].total;

  const dataQuery = `
    SELECT r.*, sender.full_name AS reporter_name,
      target.full_name AS target_name, t.name AS trip_name
    ${from} ${where}
    ORDER BY r.created_at ASC, r.id ASC
    LIMIT $${params.length + 1} OFFSET $${params.length + 2}
  `;
  const { rows } = await db.query(dataQuery, [
    ...params,
    limit,
    (page - 1) * limit,
  ]);
  return { rows, total };
};

const getReport = async (id, client = db, lock = false) => {
  const query = `
    SELECT r.*, sender.full_name AS reporter_name, sender.email AS reporter_email,
      target.full_name AS target_name, target.status AS target_status,
      target.role AS target_role, t.name AS trip_name
    FROM user_reports r
    JOIN users sender ON sender.id=r.reporter_id
    LEFT JOIN users target ON target.id=r.reported_user_id
    LEFT JOIN trips t ON t.id=r.reported_trip_id
    WHERE r.id=$1
    ${lock ? "FOR UPDATE OF r" : ""}
  `;
  const { rows } = await client.query(query, [id]);
  return rows[0] || null;
};

const resolveReport = async (id, status, notes, client) => {
  const query = `
    UPDATE user_reports
    SET status=$2, admin_notes=$3
    WHERE id=$1 AND status='PENDING'
    RETURNING *
  `;
  const { rows } = await client.query(query, [id, status, notes]);
  return rows[0] || null;
};

// Lấy mẫu do admin tạo hoặc chuyến cộng đồng đã hoàn thành và công khai
const listTemplates = async (query, publicOnly = false) => {
  const {
    page,
    limit,
    search,
    destination,
    durationDays,
    sortBy,
    status,
    source,
  } = query;
  const community = publicOnly && source === "COMMUNITY";
  const params = [];
  const conditions = community
    ? ["t.status='COMPLETED'", "t.privacy_type='PUBLIC'"]
    : [];

  if (!community && publicOnly) {
    conditions.push("t.is_active=true");
  }
  if (!community && !publicOnly && status) {
    conditions.push(`t.is_active=${status === "ACTIVE" ? "true" : "false"}`);
  }
  if (search) {
    params.push(`%${search}%`);
    conditions.push(
      `(t.name ILIKE $${params.length} OR t.destination ILIKE $${params.length})`,
    );
  }
  if (destination) {
    params.push(destination);
    conditions.push(`LOWER(t.destination)=LOWER($${params.length})`);
  }
  if (durationDays) {
    params.push(durationDays);
    conditions.push(`t.duration_days=$${params.length}`);
  }

  const where = conditions.length ? "WHERE " + conditions.join(" AND ") : "";
  const table = community ? "trips" : "admin_itinerary_templates";
  const countQuery = `SELECT COUNT(*)::int AS total FROM ${table} t ${where}`;
  const { rows: countRows } = await db.query(countQuery, params);
  const total = countRows[0].total;

  let metrics;
  if (community) {
    metrics = `
      t.clone_count AS usage_count,
      (SELECT AVG(r.rating) FROM trip_reviews r
        WHERE r.trip_id=t.id AND r.reviewee_id IS NULL) AS average_rating,
      (SELECT COUNT(*)::int FROM trip_reviews r
        WHERE r.trip_id=t.id AND r.reviewee_id IS NULL) AS review_count
    `;
  } else {
    metrics = `
      (SELECT COUNT(*)::int FROM admin_template_uses u
        WHERE u.template_id=t.id) AS usage_count,
      0 AS average_rating, 0 AS review_count
    `;
  }

  let order = "t.created_at DESC";
  if (sortBy === "usage") {
    order = "usage_count DESC";
  } else if (sortBy === "rating") {
    order = "average_rating DESC NULLS LAST,review_count DESC";
  }

  const dataQuery = `
    SELECT t.*, t.xmin::text AS row_version, ${metrics}
    FROM ${table} t ${where}
    ORDER BY ${order}, t.id DESC
    LIMIT $${params.length + 1} OFFSET $${params.length + 2}
  `;
  const { rows } = await db.query(dataQuery, [
    ...params,
    limit,
    (page - 1) * limit,
  ]);
  return { rows, total };
};

const getTemplate = async (id, client = db, lock = false) => {
  const query = `
    SELECT t.*, t.xmin::text AS row_version,
      (SELECT COUNT(*)::int FROM admin_template_uses u
        WHERE u.template_id=t.id) AS usage_count
    FROM admin_itinerary_templates t
    WHERE t.id=$1
    ${lock ? "FOR UPDATE OF t" : ""}
  `;
  const { rows } = await client.query(query, [id]);
  return rows[0] || null;
};

// Lưu mẫu mới hoặc cập nhật mẫu đang có
const saveTemplate = async (
  id,
  data,
  userId,
  client = db,
  coverImageUrl = null,
  sourceTripId = null,
) => {
  const params = [
    data.name,
    data.destination,
    data.durationDays,
    data.estimatedBudget,
    data.description || null,
    JSON.stringify(data.days),
  ];

  let query;
  if (id) {
    query = `
      UPDATE admin_itinerary_templates
      SET name=$1, destination=$2, duration_days=$3,
        estimated_budget=$4, description=$5, days=$6::jsonb,
        cover_image_url=COALESCE($7,cover_image_url), updated_at=NOW()
      WHERE id=$8
      RETURNING *, xmin::text AS row_version
    `;
    params.push(coverImageUrl, id);
  } else {
    query = `
      INSERT INTO admin_itinerary_templates (
        name, destination, duration_days, estimated_budget, description,
        days, created_by, cover_image_url, source_trip_id
      )
      VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7,$8,$9)
      RETURNING *, xmin::text AS row_version
    `;
    params.push(userId, coverImageUrl, sourceTripId);
  }

  const { rows } = await client.query(query, params);
  return rows[0];
};

const setTemplateStatus = async (id, isActive, client) => {
  const query = `
    UPDATE admin_itinerary_templates
    SET is_active=$2, updated_at=NOW()
    WHERE id=$1
    RETURNING *, xmin::text AS row_version
  `;
  const { rows } = await client.query(query, [id, isActive]);
  return rows[0];
};

const deleteTemplate = async (id, client) => {
  const query = "DELETE FROM admin_itinerary_templates WHERE id=$1";
  return client.query(query, [id]);
};

// Sao chép từng ngày và hoạt động; giữ liên kết tới địa điểm trong kho
const applyTemplate = async (
  template,
  trip,
  userId,
  client,
  community = false,
) => {
  for (const day of template.days) {
    const dayQuery = `
      INSERT INTO itineraries (trip_id, day_number, title, trip_date)
      VALUES ($1,$2,$3,$4::date+($2::int-1))
      RETURNING id
    `;
    const { rows } = await client.query(dayQuery, [
      trip.id,
      day.dayNumber,
      day.title || null,
      trip.start_date,
    ]);
    const saved = rows[0];

    for (let index = 0; index < day.items.length; index++) {
      const item = day.items[index];
      const itemQuery = `
        INSERT INTO itinerary_items (
          itinerary_id, custom_name, custom_address, category, start_time,
          end_time, order_index, note, estimated_cost, place_id, is_completed, location_source
        )
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,false,$11)
      `;
      await client.query(itemQuery, [
        saved.id,
        item.customName,
        item.customAddress || null,
        item.category,
        item.startTime,
        item.endTime,
        index,
        item.note || null,
        item.estimatedCost,
        item.placeId || null,
        item.placeId ? 'CATALOG' : 'MANUAL',
      ]);
    }
  }

  if (community) {
    await client.query(
      "UPDATE trips SET clone_count=clone_count+1 WHERE id=$1",
      [template.id],
    );
  } else {
    const query = `
      INSERT INTO admin_template_uses (template_id, trip_id, user_id)
      VALUES ($1,$2,$3)
    `;
    await client.query(query, [template.id, trip.id, userId]);
  }
};

const getCommunityTemplateData = async (id, client = db, lock = false) => {
  const tripQuery = `
    SELECT t.*, t.xmin::text AS row_version, t.clone_count AS usage_count,
      (SELECT AVG(r.rating) FROM trip_reviews r
        WHERE r.trip_id=t.id AND r.reviewee_id IS NULL) AS average_rating,
      (SELECT COUNT(*)::int FROM trip_reviews r
        WHERE r.trip_id=t.id AND r.reviewee_id IS NULL) AS review_count
    FROM trips t
    WHERE t.id=$1 AND t.status='COMPLETED' AND t.privacy_type='PUBLIC'
    ${lock ? "FOR SHARE OF t" : ""}
  `;
  const { rows: trips } = await client.query(tripQuery, [id]);
  const trip = trips[0];
  if (!trip) {
    return null;
  }

  const dayQuery =
    "SELECT * FROM itineraries WHERE trip_id=$1 ORDER BY day_number";
  const { rows: days } = await client.query(dayQuery, [id]);
  const itemQuery = `
    SELECT item.* FROM itinerary_items item
    JOIN itineraries day ON day.id=item.itinerary_id
    WHERE day.trip_id=$1
    ORDER BY day.day_number, item.order_index, item.start_time, item.id
  `;
  const { rows: items } = await client.query(itemQuery, [id]);

  trip.days = days.map((day) => ({
    dayNumber: day.day_number,
    title: day.title,
    items: items
      .filter((item) => item.itinerary_id === day.id)
      .map((item) => ({
        placeId: item.place_id,
        customName: item.custom_name,
        customAddress: item.custom_address,
        category: item.category,
        startTime: item.start_time?.slice(0, 5),
        endTime: item.end_time?.slice(0, 5),
        note: item.note,
        estimatedCost: Number(item.estimated_cost || 0),
      })),
  }));

  return trip;
};

const getActiveTemplatePlaces = async (ids, client) => {
  const query = `
    SELECT id, name, address, category FROM places
    WHERE id=ANY($1::uuid[]) AND is_active=true
    FOR SHARE
  `;
  const { rows } = await client.query(query, [ids]);
  return rows;
};

// Lấy thông tin liên quan để admin đối chiếu báo cáo
const getReportContext = async (report) => {
  let user = null;
  let trip = null;
  let posts = [];

  if (report.reported_user_id) {
    const query = `
      SELECT id, full_name, nickname, avatar_url, status,
        is_verified, verification_status, created_at
      FROM users WHERE id=$1
    `;
    const { rows } = await db.query(query, [report.reported_user_id]);
    user = rows[0] || null;
  }

  if (report.reported_trip_id) {
    const query = `
      SELECT id, name, destination, start_date, end_date, status,
        privacy_type, estimated_budget, cover_image_url
      FROM trips WHERE id=$1
    `;
    const { rows } = await db.query(query, [report.reported_trip_id]);
    trip = rows[0] || null;
  }

  if (trip) {
    const query = `
      SELECT id, title, content, status, gender_preference,
        target_members_count, current_members_count
      FROM companion_posts WHERE trip_id=$1
      ORDER BY created_at DESC
    `;
    const { rows } = await db.query(query, [trip.id]);
    posts = rows;
  }

  return { user, trip, posts };
};

// Ưu tiên hiển thị bài tuyển có báo cáo đang chờ xử lý
const getModerationPosts = async ({ page, limit, search }) => {
  const params = search ? [`%${search}%`] : [];
  const where = `
    WHERE cp.status IN ('OPEN','FULL')
    ${search ? "AND (cp.title ILIKE $1 OR t.name ILIKE $1 OR t.destination ILIKE $1)" : ""}
  `;
  const from = `
    FROM companion_posts cp
    JOIN trips t ON t.id=cp.trip_id
    JOIN users u ON u.id=cp.creator_id
    ${where}
  `;
  const countQuery = `SELECT COUNT(*)::int AS total ${from}`;
  const { rows: countRows } = await db.query(countQuery, params);
  const total = countRows[0].total;

  const dataQuery = `
    SELECT cp.id, cp.trip_id, cp.title, cp.content, cp.status,
      t.name AS trip_name, t.destination, u.full_name AS creator_name,
      (SELECT COUNT(*)::int FROM user_reports r
        WHERE r.reported_trip_id=t.id AND r.status='PENDING') AS report_count
    ${from}
    ORDER BY report_count DESC, cp.created_at DESC, cp.id DESC
    LIMIT $${params.length + 1} OFFSET $${params.length + 2}
  `;
  const { rows } = await db.query(dataQuery, [
    ...params,
    limit,
    (page - 1) * limit,
  ]);
  return { rows, total };
};

const getModerationPost = async (id, client = db) => {
  const query = `
    SELECT cp.*, t.name AS trip_name, t.destination, u.full_name AS creator_name
    FROM companion_posts cp
    JOIN trips t ON t.id=cp.trip_id
    JOIN users u ON u.id=cp.creator_id
    WHERE cp.id=$1
  `;
  const { rows } = await client.query(query, [id]);
  return rows[0] || null;
};

const lockModerationTrip = async (id, client) => {
  return client.query("SELECT id FROM trips WHERE id=$1 FOR UPDATE", [id]);
};

const hideModerationPost = async (id, client) => {
  const query = `
    UPDATE companion_posts SET status='CLOSED', updated_at=NOW()
    WHERE id=$1
  `;
  return client.query(query, [id]);
};

const getModerationLeader = async (tripId, client) => {
  const query = `
    SELECT user_id FROM trip_members
    WHERE trip_id=$1 AND role='LEADER' AND membership_status='ACTIVE'
  `;
  const { rows } = await client.query(query, [tripId]);
  return rows[0]?.user_id;
};

module.exports = {
  getReportContext,
  getModerationPosts,
  getModerationPost,
  lockModerationTrip,
  hideModerationPost,
  getModerationLeader,
  getActiveTemplatePlaces,
  getCommunityTemplateData,
  getReports,
  getReport,
  resolveReport,
  listTemplates,
  getTemplate,
  saveTemplate,
  setTemplateStatus,
  deleteTemplate,
  applyTemplate,
  getUsersList,
  updateUserStatus,
  getPendingEkycList,
  findUserById,
  approveUserEkyc,
  rejectUserEkyc,
};
