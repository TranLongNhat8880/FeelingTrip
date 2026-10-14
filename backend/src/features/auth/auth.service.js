const crypto = require('crypto');
const authRepository = require('./auth.repository');
const otpRepository = require('./otp.repository');
const { hashPassword, comparePassword } = require('../../shared/utils/hash.util');
const { generateToken } = require('../../shared/utils/token.util');
const emailService = require('../../shared/services/email.service');
const apiError = require('../../shared/utils/apiError.util');

const publicUser = (u) => ({
  id: u.id, email: u.email, fullName: u.full_name, nickname: u.nickname,
  phone: u.phone, avatarUrl: u.avatar_url, role: u.role,
  isEmailVerified: u.is_email_verified, isVerified: u.is_verified,
  verificationStatus: u.verification_status, bankBin: u.bank_bin,
  bankName: u.bank_name, bankAccountNumber: u.bank_account_number,
  bankAccountName: u.bank_account_name,
});
const session = (user) => ({
  token: generateToken({ id: user.id, email: user.email, role: user.role, tokenVersion: user.token_version }),
  user: publicUser(user),
});
const sendCode = async (user, type) => {
  const otp = crypto.randomInt(100000, 1000000).toString();
  await otpRepository.issue(user.id, type, await hashPassword(otp));
  console.log(`[AUTH OTP] Mã OTP cho ${user.email} (${type}): ${otp}`);
  try { await emailService.sendOtpEmail(user.email, otp, type); }
  catch (error) {
    console.error('OTP email delivery failed', {
      message: error.message,
      code: error.code || 'UNKNOWN',
      command: error.command,
      responseCode: error.responseCode,
    });
    throw apiError(503, 'Chưa gửi được email. Vui lòng thử gửi lại OTP sau 60 giây.');
  }
};
const register = async ({ email, password, fullName, phone, termsAccepted, termsVersion }) => {
  if (termsAccepted !== true || termsVersion !== '1.0') {
    throw apiError(400, 'Vui lòng đồng ý với Điều khoản sử dụng phiên bản hiện tại');
  }
  email = email.trim().toLowerCase();
  if (await authRepository.findUserByEmail(email)) throw apiError(409, 'Email đã được sử dụng');
  const user = await authRepository.createUser({
    email, passwordHash: await hashPassword(password), fullName: fullName.trim(), phone, termsVersion,
  });
  let emailSent = true;
  try { await sendCode(user, 'VERIFY_EMAIL'); }
  catch (error) {
    if (error.status !== 503) throw error;
    emailSent = false;
  }
  return {
    user: { ...publicUser(user), emailSent },
    message: emailSent ? 'Đăng ký thành công. Vui lòng kiểm tra email để xác thực.'
      : 'Tài khoản đã được tạo nhưng chưa gửi được email. Vui lòng gửi lại OTP sau 60 giây.',
  };
};
const verifyOtp = async ({ email, otp }) => {
  const result = await otpRepository.consume(email.trim(), 'VERIFY_EMAIL', otp);
  if (result.error) throw apiError(400, result.error);
  return { ...session(result.user), message: 'Xác thực thành công' };
};
const resendOtp = async ({ email, type = 'VERIFY_EMAIL' }) => {
  if (type === 'FORGOT_PASSWORD') return forgotPassword({ email });
  const user = await authRepository.findUserByEmail(email.trim());
  if (!user || user.status !== 'ACTIVE') throw apiError(400, 'Tài khoản không khả dụng');
  if (user.is_email_verified) throw apiError(409, 'Email đã được xác thực');
  await sendCode(user, type);
  return { message: 'OTP mới đã được gửi' };
};
const login = async ({ email, password }) => {
  const user = await authRepository.findUserByEmail(email.trim());
  if (!user?.password_hash || !await comparePassword(password, user.password_hash)) throw apiError(401, 'Email hoặc mật khẩu không chính xác');
  if (user.status !== 'ACTIVE') throw apiError(403, 'Tài khoản đã bị khóa');
  if (!user.is_email_verified) {
    const error = apiError(403, 'Vui lòng xác thực email trước khi đăng nhập');
    error.code = 'EMAIL_NOT_VERIFIED';
    throw error;
  }
  return { ...session(user), message: 'Đăng nhập thành công' };
};
const forgotPassword = async ({ email }) => {
  const user = await authRepository.findUserByEmail(email.trim());
  if (user?.status === 'ACTIVE') await sendCode(user, 'FORGOT_PASSWORD');
  return { message: 'Nếu tài khoản khả dụng, mã đặt lại mật khẩu đã được gửi.' };
};
const resetPassword = async ({ email, otp, newPassword }) => {
  const result = await otpRepository.consume(email.trim(), 'FORGOT_PASSWORD', otp, await hashPassword(newPassword));
  if (result.error) throw apiError(400, result.error);
  return { message: 'Đã đặt lại mật khẩu. Vui lòng đăng nhập lại.' };
};
module.exports = { register, verifyOtp, resendOtp, login, forgotPassword, resetPassword };
