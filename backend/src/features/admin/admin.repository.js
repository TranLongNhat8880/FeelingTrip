const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Admin Portal
// Tầng thao tác trực tiếp với Database (viết các câu lệnh SQL tại đây)
// ============================================================================

/**
 * Lấy danh sách người dùng với phân trang và bộ lọc
 */
const getUsersList = async ({ limit = 20, offset = 0, search, role, status }) => {
  const conditions = [];
  const params = [];

  if (search) {
    params.push(`%${search}%`);
    conditions.push(`(u.email ILIKE $${params.length} OR u.full_name ILIKE $${params.length})`);
  }

  if (role) {
    params.push(role);
    conditions.push(`u.role = $${params.length}`);
  }

  if (status) {
    params.push(status);
    conditions.push(`u.status = $${params.length}`);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

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
  if (status === 'BANNED') {
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

module.exports = {
  getUsersList,
  updateUserStatus,
  getPendingEkycList,
  findUserById,
  approveUserEkyc,
  rejectUserEkyc,
};
