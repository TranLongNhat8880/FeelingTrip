const db = require('../../config/database');
const { comparePassword } = require('../../shared/utils/hash.util');
const apiError = require('../../shared/utils/apiError.util');

/**
 * Issues a new OTP for a user and purpose with a 5-minute expiration.
 * Enforces a 60-second cooldown between consecutive sends for the same purpose.
 *
 * @param {string} userId - User UUID
 * @param {'VERIFY_EMAIL' | 'FORGOT_PASSWORD'} purpose - OTP usage scope
 * @param {string} otpHash - Bcrypt hash of the OTP code
 */
const issue = (userId, purpose, otpHash) =>
  db.transaction(async (client) => {
    // Lock the user row to prevent race conditions during activation or suspension
    const { rows: [user] } = await client.query(
      'SELECT id, status FROM users WHERE id = $1 FOR UPDATE',
      [userId]
    );

    if (!user || user.status !== 'ACTIVE') {
      throw apiError(403, 'Tài khoản không khả dụng');
    }

    // Check resend cooldown (60 seconds)
    const { rows: [existing] } = await client.query(
      'SELECT sent_at FROM auth_otps WHERE user_id = $1 AND purpose = $2',
      [userId, purpose]
    );

    if (existing && Date.now() - new Date(existing.sent_at).getTime() < 60000) {
      throw apiError(429, 'Vui lòng chờ 60 giây trước khi gửi lại OTP');
    }

    const upsertQuery = `
      INSERT INTO auth_otps (user_id, purpose, otp_hash, expires_at, sent_at, attempts)
      VALUES ($1, $2, $3, NOW() + INTERVAL '5 minutes', NOW(), 0)
      ON CONFLICT (user_id, purpose) DO UPDATE SET
        otp_hash = $3,
        expires_at = NOW() + INTERVAL '5 minutes',
        sent_at = NOW(),
        attempts = 0
    `;

    await client.query(upsertQuery, [userId, purpose, otpHash]);
  });

/**
 * Validates and atomically consumes an OTP code.
 * - Increments attempt counter on incorrect entry (persisted even on failure).
 * - Enforces maximum 5 attempts.
 * - On success: activates email or updates password & revokes existing JWTs atomically.
 *
 * @param {string} email - User email address
 * @param {'VERIFY_EMAIL' | 'FORGOT_PASSWORD'} purpose - OTP purpose
 * @param {string} otp - Plaintext OTP provided by user
 * @param {string} [newPasswordHash] - Required for FORGOT_PASSWORD flow
 * @returns {Promise<{ user?: object, error?: string }>}
 */
const consume = (email, purpose, otp, newPasswordHash) =>
  db.transaction(async (client) => {
    const { rows: [user] } = await client.query(
      'SELECT * FROM users WHERE LOWER(email) = LOWER($1) FOR UPDATE',
      [email]
    );

    if (!user || user.status !== 'ACTIVE') {
      return { error: 'Tài khoản hoặc OTP không hợp lệ' };
    }

    const { rows: [record] } = await client.query(
      'SELECT * FROM auth_otps WHERE user_id = $1 AND purpose = $2 FOR UPDATE',
      [user.id, purpose]
    );

    if (!record || record.attempts >= 5 || new Date(record.expires_at) <= new Date()) {
      return { error: 'OTP hết hạn hoặc vượt quá số lần thử' };
    }

    const isMatch = await comparePassword(otp, record.otp_hash);
    if (!isMatch) {
      await client.query(
        'UPDATE auth_otps SET attempts = attempts + 1 WHERE user_id = $1 AND purpose = $2',
        [user.id, purpose]
      );
      return { error: 'OTP không chính xác' };
    }

    // OTP is valid - perform user update
    const updateSql =
      purpose === 'VERIFY_EMAIL'
        ? 'UPDATE users SET is_email_verified = TRUE WHERE id = $1 RETURNING *'
        : 'UPDATE users SET password_hash = $2, token_version = token_version + 1 WHERE id = $1 RETURNING *';

    const updateParams =
      purpose === 'VERIFY_EMAIL' ? [user.id] : [user.id, newPasswordHash];

    const { rows: [updatedUser] } = await client.query(updateSql, updateParams);

    // Delete used OTP record
    await client.query(
      'DELETE FROM auth_otps WHERE user_id = $1 AND purpose = $2',
      [user.id, purpose]
    );

    return { user: updatedUser };
  });

module.exports = {
  issue,
  consume,
};
