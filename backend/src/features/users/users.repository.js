const db = require('../../config/database');

// ============================================================================
// REPOSITORY: User Profile & eKYC
// Chỉ thực hiện truy vấn DB; nghiệp vụ và mapping response nằm ở service.
// ============================================================================

const PROFILE_COLUMNS = `
  id,
  email,
  full_name,
  nickname,
  phone,
  avatar_url,
  bio,
  gender,
  dob,
  role,
  is_email_verified,
  is_verified,
  verification_status,
  verification_rejection_reason,
  (
    cccd_number IS NOT NULL
    AND cccd_front_image IS NOT NULL
    AND cccd_back_image IS NOT NULL
    AND selfie_image IS NOT NULL
  ) AS has_ekyc_documents,
  bank_bin,
  bank_name,
  bank_account_number,
  bank_account_name,
  created_at,
  updated_at
`;

/**
 * Lấy hồ sơ cá nhân của chính người dùng.
 *
 * Không trả password_hash, token_version, ảnh CCCD hoặc số CCCD đầy đủ.
 */
const findProfileById = async (userId) => {
    const query = `
    SELECT ${PROFILE_COLUMNS}
    FROM users
    WHERE id = $1
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [userId]);
    return rows[0] || null;
};

/**
 * Cập nhật các trường hồ sơ được service cho phép.
 *
 * Tên cột được lấy từ whitelist cố định, không lấy trực tiếp từ request,
 * tránh việc client tự chọn cột SQL cần cập nhật.
 */
const updateProfile = async (userId, profileData) => {
    const columnMap = {
        fullName: 'full_name',
        nickname: 'nickname',
        phone: 'phone',
        avatarUrl: 'avatar_url',
        bio: 'bio',
        gender: 'gender',
        dob: 'dob',
    };

    const updates = [];
    const values = [userId];

    for (const [field, column] of Object.entries(columnMap)) {
        if (profileData[field] !== undefined) {
            values.push(profileData[field]);
            updates.push(`${column} = $${values.length}`);
        }
    }

    if (updates.length === 0) {
        return findProfileById(userId);
    }

    const query = `
    UPDATE users
    SET
      ${updates.join(', ')},
      updated_at = CURRENT_TIMESTAMP
    WHERE id = $1
    RETURNING id;
  `;

    const { rows } = await db.query(query, values);

    if (!rows[0]) {
        return null;
    }

    return findProfileById(userId);
};

/**
 * Nộp hoặc nộp lại hồ sơ eKYC.
 *
 * Chỉ cho phép chuyển:
 * - UNVERIFIED -> PENDING
 * - REJECTED   -> PENDING
 *
 * Điều kiện nằm ngay trong UPDATE để hai request đồng thời không thể
 * cùng nộp thành công.
 */
const submitEkyc = async ({
    userId,
    cccdNumber,
    cccdFrontImage,
    cccdBackImage,
    selfieImage,
}) => {
    const query = `
    UPDATE users
    SET
      cccd_number = $2,
      cccd_front_image = $3,
      cccd_back_image = $4,
      selfie_image = $5,
      verification_status = 'PENDING',
      verification_rejection_reason = NULL,
      is_verified = FALSE,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = $1
      AND verification_status IN ('UNVERIFIED', 'REJECTED')
    RETURNING
      id,
      verification_status,
      verification_rejection_reason,
      is_verified,
      updated_at;
  `;

    const values = [
        userId,
        cccdNumber,
        cccdFrontImage,
        cccdBackImage,
        selfieImage,
    ];

    const { rows } = await db.query(query, values);
    return rows[0] || null;
};

/**
 * Lấy thông tin tín nhiệm công khai của một người dùng đang hoạt động.
 *
 * Chỉ tính các đánh giá thành viên:
 * trip_reviews.reviewee_id = user cần xem.
 * Các đánh giá chuyến đi có reviewee_id = NULL nên không bị tính vào.
 */
const findTrustScoreByUserId = async (userId) => {
    const query = `
    SELECT
      u.id,
      u.full_name,
      u.nickname,
      u.avatar_url,
      u.bio,
      u.is_verified,
      u.created_at,
      COALESCE(
        ROUND(AVG(tr.rating)::NUMERIC, 2),
        0
      )::DOUBLE PRECISION AS trust_score,
      COUNT(tr.id)::INTEGER AS review_count
    FROM users u
    LEFT JOIN trip_reviews tr
      ON tr.reviewee_id = u.id
    WHERE u.id = $1
      AND u.status = 'ACTIVE'
    GROUP BY
      u.id,
      u.full_name,
      u.nickname,
      u.avatar_url,
      u.bio,
      u.is_verified,
      u.created_at
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [userId]);
    return rows[0] || null;
};

module.exports = {
    findProfileById,
    updateProfile,
    submitEkyc,
    findTrustScoreByUserId,
};