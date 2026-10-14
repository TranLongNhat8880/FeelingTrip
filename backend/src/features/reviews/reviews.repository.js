const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Reviews, Reports, Blocks, Emergency Contacts & SOS
// ============================================================================

/**
 * Lấy trạng thái chuyến đi và kiểm tra người đã từng tham gia.
 *
 * Giữ cả ACTIVE/LEFT/REMOVED để người đã rời vẫn có thể đánh giá sau khi
 * chuyến đi COMPLETED. Không dùng predicate này để cấp quyền sửa chuyến đi.
 * Creator được coi là thành viên kể cả khi dữ liệu cũ chưa có bản ghi
 * tương ứng trong trip_members.
 */
const findTripContext = async ({
    tripId,
    reviewerId,
    revieweeId = null,
}) => {
    const query = `
    SELECT
      t.id,
      t.status,
      (
        t.creator_id = $2
        OR EXISTS (
          SELECT 1
          FROM trip_members reviewer_member
          WHERE reviewer_member.trip_id = t.id
            AND reviewer_member.user_id = $2
        )
      ) AS reviewer_is_member,
      CASE
        WHEN $3::UUID IS NULL THEN NULL
        ELSE (
          t.creator_id = $3
          OR EXISTS (
            SELECT 1
            FROM trip_members reviewee_member
            WHERE reviewee_member.trip_id = t.id
              AND reviewee_member.user_id = $3
          )
        )
      END AS reviewee_is_member
    FROM trips t
    WHERE t.id = $1
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [
        tripId,
        reviewerId,
        revieweeId,
    ]);

    return rows[0] || null;
};

/**
 * Kiểm tra người dùng đã đánh giá cùng đối tượng trong chuyến đi chưa.
 *
 * IS NOT DISTINCT FROM giúp so sánh đúng cả trường hợp reviewee_id = NULL.
 */
const findExistingReview = async ({
    tripId,
    reviewerId,
    revieweeId = null,
}) => {
    const query = `
    SELECT id
    FROM trip_reviews
    WHERE trip_id = $1
      AND reviewer_id = $2
      AND reviewee_id IS NOT DISTINCT FROM $3::UUID
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [
        tripId,
        reviewerId,
        revieweeId,
    ]);

    return rows[0] || null;
};

/**
 * Tạo đánh giá chuyến đi hoặc thành viên.
 *
 * revieweeId = NULL: đánh giá chuyến đi.
 * revieweeId có giá trị: đánh giá thành viên.
 */
const createReview = async ({
    tripId,
    reviewerId,
    revieweeId = null,
    rating,
    comment,
}) => {
    const query = `
    INSERT INTO trip_reviews (
      trip_id,
      reviewer_id,
      reviewee_id,
      rating,
      comment
    )
    VALUES ($1, $2, $3, $4, $5)
    RETURNING
      id,
      trip_id,
      reviewer_id,
      reviewee_id,
      rating,
      comment,
      created_at;
  `;

    const { rows } = await db.query(query, [
        tripId,
        reviewerId,
        revieweeId,
        rating,
        comment,
    ]);

    return rows[0];
};

/**
 * Tìm user để kiểm tra đối tượng báo cáo/chặn.
 */
const findUserById = async (userId) => {
    const query = `
    SELECT id, status
    FROM users
    WHERE id = $1
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [userId]);
    return rows[0] || null;
};

/**
 * Tìm chuyến đi để kiểm tra đối tượng báo cáo.
 */
const findTripById = async (tripId) => {
    const query = `
    SELECT id, creator_id, status
    FROM trips
    WHERE id = $1
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [tripId]);
    return rows[0] || null;
};

/**
 * Tạo báo cáo vi phạm.
 */
const createReport = async ({
    reporterId,
    reportedUserId = null,
    reportedTripId = null,
    reason,
    evidenceImageUrl = null,
}) => {
    const query = `
    INSERT INTO user_reports (
      reporter_id,
      reported_user_id,
      reported_trip_id,
      reason,
      evidence_image_url
    )
    VALUES ($1, $2, $3, $4, $5)
    RETURNING
      id,
      reporter_id,
      reported_user_id,
      reported_trip_id,
      reason,
      evidence_image_url,
      status,
      created_at;
  `;

    const { rows } = await db.query(query, [
        reporterId,
        reportedUserId,
        reportedTripId,
        reason,
        evidenceImageUrl,
    ]);

    return rows[0];
};

/**
 * Chặn người dùng.
 *
 * ON CONFLICT DO NOTHING để hai request đồng thời không tạo lỗi SQL thô.
 */
const createBlock = async ({ blockerId, blockedId }) => {
    const query = `
    INSERT INTO user_blocks (blocker_id, blocked_id)
    VALUES ($1, $2)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING
    RETURNING blocker_id, blocked_id, created_at;
  `;

    const { rows } = await db.query(query, [blockerId, blockedId]);
    return rows[0] || null;
};

/**
 * Bỏ chặn người dùng.
 */
const deleteBlock = async ({ blockerId, blockedId }) => {
    const query = `
    DELETE FROM user_blocks
    WHERE blocker_id = $1
      AND blocked_id = $2
    RETURNING blocker_id, blocked_id;
  `;

    const { rows } = await db.query(query, [blockerId, blockedId]);
    return rows[0] || null;
};

/**
 * Danh sách người dùng đã bị chặn.
 */
const findBlockedUsers = async (blockerId) => {
    const query = `
    SELECT
      blocked_user.id,
      blocked_user.full_name,
      blocked_user.nickname,
      blocked_user.avatar_url,
      blocked_user.is_verified,
      user_blocks.created_at AS blocked_at
    FROM user_blocks
    INNER JOIN users blocked_user
      ON blocked_user.id = user_blocks.blocked_id
    WHERE user_blocks.blocker_id = $1
    ORDER BY user_blocks.created_at DESC;
  `;

    const { rows } = await db.query(query, [blockerId]);
    return rows;
};

/**
 * Danh sách liên hệ khẩn cấp của người dùng.
 */
const findEmergencyContacts = async (userId) => {
    const query = `
    SELECT
      id,
      full_name,
      phone,
      relationship,
      created_at
    FROM emergency_contacts
    WHERE user_id = $1
    ORDER BY created_at DESC, id DESC;
  `;

    const { rows } = await db.query(query, [userId]);
    return rows;
};

/**
 * Tạo liên hệ khẩn cấp.
 */
const createEmergencyContact = async ({
    userId,
    fullName,
    phone,
    relationship,
}) => {
    const query = `
    INSERT INTO emergency_contacts (
      user_id,
      full_name,
      phone,
      relationship
    )
    VALUES ($1, $2, $3, $4)
    RETURNING
      id,
      full_name,
      phone,
      relationship,
      created_at;
  `;

    const { rows } = await db.query(query, [
        userId,
        fullName,
        phone,
        relationship,
    ]);

    return rows[0];
};

/**
 * Cập nhật liên hệ khẩn cấp thuộc sở hữu của user.
 */
const updateEmergencyContact = async ({
    contactId,
    userId,
    contactData,
}) => {
    const columnMap = {
        fullName: 'full_name',
        phone: 'phone',
        relationship: 'relationship',
    };

    const updates = [];
    const values = [contactId, userId];

    for (const [field, column] of Object.entries(columnMap)) {
        if (contactData[field] !== undefined) {
            values.push(contactData[field]);
            updates.push(`${column} = $${values.length}`);
        }
    }

    if (updates.length === 0) {
        return null;
    }

    const query = `
    UPDATE emergency_contacts
    SET ${updates.join(', ')}
    WHERE id = $1
      AND user_id = $2
    RETURNING
      id,
      full_name,
      phone,
      relationship,
      created_at;
  `;

    const { rows } = await db.query(query, values);
    return rows[0] || null;
};

/**
 * Xóa liên hệ khẩn cấp thuộc sở hữu của user.
 */
const deleteEmergencyContact = async ({ contactId, userId }) => {
    const query = `
    DELETE FROM emergency_contacts
    WHERE id = $1
      AND user_id = $2
    RETURNING id;
  `;

    const { rows } = await db.query(query, [contactId, userId]);
    return rows[0] || null;
};

/**
 * Tạo cảnh báo SOS.
 */
const createSos = async ({
    userId,
    tripId = null,
    latitude,
    longitude,
    message,
}) => {
    const query = `
    INSERT INTO sos_alerts (
      user_id,
      trip_id,
      latitude,
      longitude,
      message
    )
    VALUES ($1, $2, $3, $4, $5)
    RETURNING
      id,
      user_id,
      trip_id,
      latitude,
      longitude,
      message,
      status,
      created_at,
      resolved_at;
  `;

    const { rows } = await db.query(query, [
        userId,
        tripId,
        latitude,
        longitude,
        message,
    ]);

    return rows[0];
};

/**
 * Lấy SOS theo ID và chủ sở hữu.
 */
const findSosByIdForUser = async ({ sosId, userId }) => {
    const query = `
    SELECT
      id,
      user_id,
      trip_id,
      latitude,
      longitude,
      message,
      status,
      created_at,
      resolved_at
    FROM sos_alerts
    WHERE id = $1
      AND user_id = $2
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [sosId, userId]);
    return rows[0] || null;
};

/**
 * Kết thúc một SOS đang ACTIVE.
 */
const updateSosStatus = async ({ sosId, userId, status }) => {
    const query = `
    UPDATE sos_alerts
    SET
      status = $3,
      resolved_at = CURRENT_TIMESTAMP
    WHERE id = $1
      AND user_id = $2
      AND status = 'ACTIVE'
    RETURNING
      id,
      user_id,
      trip_id,
      latitude,
      longitude,
      message,
      status,
      created_at,
      resolved_at;
  `;

    const { rows } = await db.query(query, [
        sosId,
        userId,
        status,
    ]);

    return rows[0] || null;
};

module.exports = {
    findTripContext,
    findExistingReview,
    createReview,
    findUserById,
    findTripById,
    createReport,
    createBlock,
    deleteBlock,
    findBlockedUsers,
    findEmergencyContacts,
    createEmergencyContact,
    updateEmergencyContact,
    deleteEmergencyContact,
    createSos,
    findSosByIdForUser,
    updateSosStatus,
};
