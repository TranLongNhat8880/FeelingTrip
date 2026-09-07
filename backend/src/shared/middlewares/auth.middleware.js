const { verifyToken } = require('../utils/token.util');
const { sendError } = require('../utils/response.util');
const db = require('../../config/database');

module.exports = async (req, res, next) => {
  const match = /^Bearer ([^\s]+)$/i.exec(req.headers.authorization || '');
  if (!match) return sendError(res, 'Token không hợp lệ', 401);
  let decoded;
  try { decoded = verifyToken(match[1]); }
  catch { return sendError(res, 'Token hết hạn hoặc không hợp lệ', 401); }
  if (!decoded || typeof decoded.id !== 'string' || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(decoded.id)) {
    return sendError(res, 'Token không hợp lệ', 401);
  }
  try {
    const { rows: [user] } = await db.query(
      'SELECT id, email, role, status, is_email_verified, token_version FROM users WHERE id = $1', [decoded.id]);
    if (!user || decoded.tokenVersion !== user.token_version) return sendError(res, 'Vui lòng đăng nhập lại', 401);
    if (user.status !== 'ACTIVE' || !user.is_email_verified) return sendError(res, 'Tài khoản bị khóa hoặc chưa xác thực email', 403);
    req.user = { id: user.id, email: user.email, role: user.role };
    next();
  } catch (error) { next(error); }
};
