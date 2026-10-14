const crypto = require('crypto');
const db = require('../../config/database');
const { sendError } = require('../utils/response.util');

/**
 * Database-backed rate limiting middleware.
 * Counters survive process restarts and work safely across multi-instance clusters.
 *
 * @param {string} scope - Rate limit namespace (e.g. 'auth_login', 'auth_resend_otp')
 * @param {number} limit - Maximum allowed requests within the time window
 * @param {number} [windowSeconds=900] - Sliding time window in seconds (defaults to 15 mins)
 * @returns {import('express').RequestHandler}
 */
const rateLimit = (scope, limit, windowSeconds = 900) => async (req, res, next) => {
  try {
    // Generate deterministic hash key based on scope and client IP
    const clientIp = req.ip || req.socket.remoteAddress || 'unknown';
    const key = crypto
      .createHash('sha256')
      .update(`${scope}:${clientIp}`)
      .digest('hex');

    const query = `
      INSERT INTO request_limits (key, hits, expires_at)
      VALUES ($1, 1, NOW() + $2 * INTERVAL '1 second')
      ON CONFLICT (key) DO UPDATE SET
        hits = CASE
          WHEN request_limits.expires_at <= NOW() THEN 1
          ELSE request_limits.hits + 1
        END,
        expires_at = CASE
          WHEN request_limits.expires_at <= NOW() THEN NOW() + $2 * INTERVAL '1 second'
          ELSE request_limits.expires_at
        END
      RETURNING hits, expires_at
    `;

    const { rows } = await db.query(query, [key, windowSeconds]);
    const { hits, expires_at: expiresAt } = rows[0];

    if (hits > limit) {
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((new Date(expiresAt).getTime() - Date.now()) / 1000)
      );

      res.set('Retry-After', String(retryAfterSeconds));
      return sendError(res, 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.', 429);
    }

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = rateLimit;
