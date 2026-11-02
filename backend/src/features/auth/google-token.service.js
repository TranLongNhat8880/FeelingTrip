const { OAuth2Client } = require('google-auth-library');
const apiError = require('../../shared/utils/apiError.util');

const client = new OAuth2Client({ transporterOptions: { timeout: 8000 } });

async function verifyGoogleToken(idToken) {
  const audience = (process.env.GOOGLE_CLIENT_IDS || '').split(',').map(s => s.trim()).filter(Boolean);
  if (!audience.length) throw apiError(503, 'Đăng nhập Google chưa được cấu hình trên server.');
  let payload;
  try {
    const ticket = await client.verifyIdToken({ idToken, audience });
    payload = ticket.getPayload();
  } catch (error) {
    if (error.code || error.response?.status >= 500) {
      throw apiError(503, 'Chưa kết nối được dịch vụ Google. Vui lòng thử lại.');
    }
    throw apiError(401, 'Phiên Google không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.');
  }
  if (typeof payload?.sub !== 'string' || !payload.sub || payload.sub.length > 255 || payload.email_verified !== true ||
      typeof payload.email !== 'string' || !payload.email.includes('@')) {
    throw apiError(401, 'Tài khoản Google chưa có email xác thực hợp lệ.');
  }
  const email = payload.email.trim().toLowerCase();
  return {
    googleId: payload.sub,
    email,
    fullName: (payload.name?.trim() || email.split('@')[0]).slice(0, 100),
    // Google is not authoritative for arbitrary third-party email addresses.
    authoritativeEmail: email.endsWith('@gmail.com') || Boolean(payload.hd),
  };
}

module.exports = { verifyGoogleToken };
