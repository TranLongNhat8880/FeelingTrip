const db = require('../../config/database');
const apiError = require('../../shared/utils/apiError.util');

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

const googleError = (status, message, code) => Object.assign(apiError(status, message), { code });

const findOrCreateGoogleUser = async (identity, { termsAccepted, termsVersion }) => {
  try {
    return await db.transaction(async client => {
      // Lock absent identities too, so simultaneous first sign-ins create one user.
      const keys = [`google:${identity.googleId}`, `email:${identity.email}`].sort();
      for (const key of keys) {
        await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [key]);
      }
      const { rows } = await client.query(
        'SELECT * FROM users WHERE google_id=$1 OR LOWER(email)=$2 FOR UPDATE',
        [identity.googleId, identity.email],
      );
      let user = rows.find(row => row.google_id === identity.googleId) || rows[0];
      if (user && user.status !== 'ACTIVE') {
        throw googleError(403, 'Tài khoản đã bị khóa', 'ACCOUNT_BANNED');
      }
      if (user && user.google_id !== identity.googleId) {
        if (user.google_id || !user.is_email_verified || !identity.authoritativeEmail) {
          throw googleError(409,
            'Email này đã có tài khoản. Vui lòng đăng nhập bằng mật khẩu và xác thực email trước; email ngoài Gmail/Google Workspace cần liên kết riêng.',
            'GOOGLE_ACCOUNT_CONFLICT');
        }
      }
      if (!user && !identity.authoritativeEmail) {
        throw googleError(409,
          'Email ngoài Gmail/Google Workspace cần đăng ký và xác thực email bằng OTP. Vui lòng dùng đăng ký bằng email.',
          'GOOGLE_EMAIL_VERIFICATION_REQUIRED');
      }
      if (!user || !user.terms_accepted_at || !user.terms_version) {
        if (termsAccepted !== true || termsVersion !== '1.0') {
          throw googleError(409, 'Vui lòng đồng ý Điều khoản sử dụng để tiếp tục.', 'GOOGLE_TERMS_REQUIRED');
        }
      }
      if (!user) {
        const created = await client.query(`
          INSERT INTO users(email,google_id,full_name,is_email_verified,terms_version,terms_accepted_at)
          VALUES($1,$2,$3,true,$4,NOW()) RETURNING *`,
        [identity.email, identity.googleId, identity.fullName, termsVersion]);
        return created.rows[0];
      }
      const updated = await client.query(`UPDATE users SET google_id=$2,
        terms_version=COALESCE(terms_version,$3),
        terms_accepted_at=COALESCE(terms_accepted_at,NOW()), updated_at=NOW()
        WHERE id=$1 RETURNING *`, [user.id, identity.googleId, termsVersion || '1.0']);
      return updated.rows[0];
    });
  } catch (error) {
    if (error.code === '23505') {
      throw googleError(409, 'Thông tin tài khoản vừa thay đổi. Vui lòng thử đăng nhập lại.', 'GOOGLE_ACCOUNT_CONFLICT');
    }
    throw error;
  }
};

module.exports = {
  findUserByEmail,
  findUserById,
  createUser,
  updateEmailVerified,
  updatePassword,
  findOrCreateGoogleUser,
};
