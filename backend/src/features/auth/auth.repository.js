const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Authentication
// Thao tác trực tiếp với bảng 'users' trong cơ sở dữ liệu PostgreSQL (Supabase)
// ============================================================================

/**
 * Tìm người dùng theo email (không phân biệt chữ hoa / thường)
 */
const findUserByEmail = async (email) => {
  const queryText = `
    SELECT id, email, password_hash, full_name, nickname, phone, avatar_url,
           role, status, is_email_verified, is_verified, verification_status, token_version,
           bank_bin, bank_name, bank_account_number, bank_account_name,
           created_at, updated_at
    FROM users
    WHERE LOWER(email) = LOWER($1)
    LIMIT 1;
  `;
  const { rows } = await db.query(queryText, [email]);
  return rows[0] || null;
};

/**
 * Tìm người dùng theo ID (UUID)
 */
const findUserById = async (id) => {
  const queryText = `
    SELECT id, email, full_name, nickname, phone, avatar_url, bio, gender, dob,
           bank_bin, bank_name, bank_account_number, bank_account_name,
           role, status, is_email_verified, is_verified, verification_status, token_version,
           created_at, updated_at
    FROM users
    WHERE id = $1
    LIMIT 1;
  `;
  const { rows } = await db.query(queryText, [id]);
  return rows[0] || null;
};

/**
 * Tạo người dùng mới khi đăng ký
 */
const createUser = async ({ email, passwordHash, fullName, phone = null, termsVersion }) => {
  const queryText = `
    INSERT INTO users (email, password_hash, full_name, phone, terms_version, terms_accepted_at, is_email_verified, role, status)
    VALUES ($1, $2, $3, $4, $5, NOW(), false, 'USER', 'ACTIVE')
    RETURNING id, email, full_name, phone, role, status, is_email_verified, is_verified, created_at;
  `;
  const values = [email, passwordHash, fullName, phone, termsVersion];
  const { rows } = await db.query(queryText, values);
  return rows[0];
};

/**
 * Cập nhật trạng thái xác thực email khi nhập đúng OTP
 */
const updateEmailVerified = async (userId, isVerified = true) => {
  const queryText = `
    UPDATE users
    SET is_email_verified = $2, updated_at = CURRENT_TIMESTAMP
    WHERE id = $1
    RETURNING id, email, full_name, role, status, is_email_verified, is_verified, token_version;
  `;
  const { rows } = await db.query(queryText, [userId, isVerified]);
  return rows[0];
};

/**
 * Cập nhật mật khẩu mới (dùng khi quên mật khẩu hoặc đổi mật khẩu)
 */
const updatePassword = async (userId, passwordHash) => {
  const queryText = `
    UPDATE users
    SET password_hash = $2, token_version = token_version + 1, updated_at = CURRENT_TIMESTAMP
    WHERE id = $1
    RETURNING id, email, updated_at;
  `;
  const { rows } = await db.query(queryText, [userId, passwordHash]);
  return rows[0];
};

module.exports = {
  findUserByEmail,
  findUserById,
  createUser,
  updateEmailVerified,
  updatePassword,
};
