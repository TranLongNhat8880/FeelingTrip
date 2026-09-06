const authRepository = require('./auth.repository');
const { hashPassword, comparePassword } = require('../../shared/utils/hash.util');
const { generateToken } = require('../../shared/utils/token.util');
const { sendOtpEmail } = require('../../shared/services/email.service');

// ============================================================================
// SERVICE: Authentication
// Xử lý toàn bộ logic nghiệp vụ xác thực, mã OTP, mật khẩu và JWT Token
// ============================================================================

// Bộ nhớ lưu mã OTP tạm thời (TTL = 5 phút)
// Key: email (in thường), Value: { otp, expiresAt, type }
const otpStore = new Map();

/**
 * Sinh mã OTP 6 chữ số ngẫu nhiên
 */
const generateOtpCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Lưu mã OTP vào bộ nhớ tạm thời
 */
const saveOtp = (email, otp, type = 'VERIFY_EMAIL') => {
  const cleanEmail = email.toLowerCase().trim();
  const expiresAt = Date.now() + 5 * 60 * 1000; // 5 phút
  otpStore.set(cleanEmail, { otp, expiresAt, type });
};

/**
 * Kiểm tra mã OTP
 */
const verifyOtpCode = (email, inputOtp, expectedType = 'VERIFY_EMAIL') => {
  const cleanEmail = email.toLowerCase().trim();
  const record = otpStore.get(cleanEmail);

  if (!record) {
    return { valid: false, message: 'Mã OTP không tồn tại hoặc đã hết hạn. Vui lòng yêu cầu mã mới.' };
  }

  if (Date.now() > record.expiresAt) {
    otpStore.delete(cleanEmail);
    return { valid: false, message: 'Mã OTP đã hết hạn (chỉ có hiệu lực trong 5 phút). Vui lòng lấy mã mới.' };
  }

  if (record.otp !== inputOtp.toString().trim()) {
    return { valid: false, message: 'Mã OTP không chính xác. Vui lòng kiểm tra lại.' };
  }

  if (expectedType && record.type !== expectedType) {
    return { valid: false, message: 'Loại mã xác thực không hợp lệ.' };
  }

  // OTP hợp lệ -> Xóa khỏi store để tránh dùng lại
  otpStore.delete(cleanEmail);
  return { valid: true };
};

/**
 * 1. ĐĂNG KÝ TÀI KHOẢN MỚI
 */
const register = async ({ email, password, fullName, phone }) => {
  if (!email || !password || !fullName) {
    const error = new Error('Vui lòng điền đầy đủ email, mật khẩu và họ tên');
    error.status = 400;
    throw error;
  }

  if (password.length < 6) {
    const error = new Error('Mật khẩu phải có độ dài tối thiểu 6 ký tự');
    error.status = 400;
    throw error;
  }

  // Kiểm tra email đã tồn tại hay chưa
  const existingUser = await authRepository.findUserByEmail(email);
  if (existingUser) {
    const error = new Error('Email này đã được sử dụng. Vui lòng chọn email khác hoặc đăng nhập.');
    error.status = 400;
    throw error;
  }

  // Băm mật khẩu bằng bcrypt
  const passwordHash = await hashPassword(password);

  // Tạo người dùng trong cơ sở dữ liệu
  const newUser = await authRepository.createUser({
    email: email.toLowerCase().trim(),
    passwordHash,
    fullName: fullName.trim(),
    phone: phone ? phone.trim() : null,
  });

  // Sinh mã OTP 6 số và lưu vào store
  const otp = generateOtpCode();
  saveOtp(email, otp, 'VERIFY_EMAIL');

  // Gửi email OTP xác thực tài khoản qua Gmail SMTP
  try {
    await sendOtpEmail(newUser.email, otp);
  } catch (mailError) {
    console.error('Lỗi khi gửi email OTP:', mailError);
    // Không chặn luồng đăng ký nếu gửi mail gặp sự cố tạm thời, user có thể bấm gửi lại OTP
  }

  return {
    user: {
      id: newUser.id,
      email: newUser.email,
      fullName: newUser.full_name,
      phone: newUser.phone,
      role: newUser.role,
      isEmailVerified: newUser.is_email_verified,
    },
    message: 'Đăng ký tài khoản thành công! Mã OTP đã được gửi tới email của bạn.',
  };
};

/**
 * 2. XÁC THỰC MÃ OTP (KÍCH HOẠT TÀI KHOẢN)
 */
const verifyOtp = async ({ email, otp }) => {
  if (!email || !otp) {
    const error = new Error('Vui lòng cung cấp email và mã OTP');
    error.status = 400;
    throw error;
  }

  const otpCheck = verifyOtpCode(email, otp, 'VERIFY_EMAIL');
  if (!otpCheck.valid) {
    const error = new Error(otpCheck.message);
    error.status = 400;
    throw error;
  }

  const user = await authRepository.findUserByEmail(email);
  if (!user) {
    const error = new Error('Tài khoản không tồn tại trên hệ thống');
    error.status = 404;
    throw error;
  }

  // Cập nhật trạng thái đã xác thực email trong Database
  const updatedUser = await authRepository.updateEmailVerified(user.id, true);

  // Sinh ngay JWT Token để người dùng được đăng nhập luôn
  const token = generateToken({
    id: updatedUser.id,
    email: updatedUser.email,
    role: updatedUser.role,
  });

  return {
    token,
    user: {
      id: updatedUser.id,
      email: updatedUser.email,
      fullName: updatedUser.full_name,
      role: updatedUser.role,
      isEmailVerified: updatedUser.is_email_verified,
    },
    message: 'Xác thực tài khoản thành công! Bạn đã đăng nhập vào hệ thống.',
  };
};

/**
 * 3. GỬI LẠI MÃ OTP
 */
const resendOtp = async ({ email, type = 'VERIFY_EMAIL' }) => {
  if (!email) {
    const error = new Error('Vui lòng cung cấp địa chỉ email');
    error.status = 400;
    throw error;
  }

  const user = await authRepository.findUserByEmail(email);
  if (!user) {
    const error = new Error('Không tìm thấy tài khoản với email này');
    error.status = 404;
    throw error;
  }

  if (type === 'VERIFY_EMAIL' && user.is_email_verified) {
    const error = new Error('Tài khoản này đã được xác thực email trước đó');
    error.status = 400;
    throw error;
  }

  const otp = generateOtpCode();
  saveOtp(email, otp, type);

  await sendOtpEmail(user.email, otp);

  return {
    message: 'Mã OTP mới đã được gửi tới email của bạn. Vui lòng kiểm tra hộp thư đến.',
  };
};

/**
 * 4. ĐĂNG NHẬP
 */
const login = async ({ email, password }) => {
  if (!email || !password) {
    const error = new Error('Vui lòng nhập đầy đủ email và mật khẩu');
    error.status = 400;
    throw error;
  }

  const user = await authRepository.findUserByEmail(email);
  if (!user) {
    const error = new Error('Email hoặc mật khẩu không chính xác');
    error.status = 401;
    throw error;
  }

  if (!user.password_hash) {
    const error = new Error('Tài khoản này được đăng ký thông qua Google. Vui lòng chọn Đăng nhập bằng Google.');
    error.status = 400;
    throw error;
  }

  const isPasswordMatch = await comparePassword(password, user.password_hash);
  if (!isPasswordMatch) {
    const error = new Error('Email hoặc mật khẩu không chính xác');
    error.status = 401;
    throw error;
  }

  if (user.status === 'BANNED') {
    const error = new Error('Tài khoản của bạn đã bị khóa do vi phạm chính sách cộng đồng.');
    error.status = 403;
    throw error;
  }

  // Sinh thẻ bài bảo mật JWT Access Token
  const token = generateToken({
    id: user.id,
    email: user.email,
    role: user.role,
  });

  return {
    token,
    user: {
      id: user.id,
      email: user.email,
      fullName: user.full_name,
      nickname: user.nickname,
      phone: user.phone,
      avatarUrl: user.avatar_url,
      role: user.role,
      isEmailVerified: user.is_email_verified,
      isVerified: user.is_verified,
      verificationStatus: user.verification_status,
      bankBin: user.bank_bin,
      bankName: user.bank_name,
      bankAccountNumber: user.bank_account_number,
      bankAccountName: user.bank_account_name,
    },
    message: 'Đăng nhập thành công',
  };
};

/**
 * 5. QUÊN MẬT KHẨU (GỬI OTP ĐẶT LẠI)
 */
const forgotPassword = async ({ email }) => {
  if (!email) {
    const error = new Error('Vui lòng nhập địa chỉ email của bạn');
    error.status = 400;
    throw error;
  }

  const user = await authRepository.findUserByEmail(email);
  if (!user) {
    const error = new Error('Không tìm thấy tài khoản nào khớp với email này');
    error.status = 404;
    throw error;
  }

  const otp = generateOtpCode();
  saveOtp(email, otp, 'FORGOT_PASSWORD');

  await sendOtpEmail(user.email, otp);

  return {
    message: 'Mã OTP đặt lại mật khẩu đã được gửi tới email của bạn.',
  };
};

/**
 * 6. ĐẶT LẠI MẬT KHẨU MỚI BẰNG OTP
 */
const resetPassword = async ({ email, otp, newPassword }) => {
  if (!email || !otp || !newPassword) {
    const error = new Error('Vui lòng cung cấp email, mã OTP và mật khẩu mới');
    error.status = 400;
    throw error;
  }

  if (newPassword.length < 6) {
    const error = new Error('Mật khẩu mới phải có ít nhất 6 ký tự');
    error.status = 400;
    throw error;
  }

  const otpCheck = verifyOtpCode(email, otp, 'FORGOT_PASSWORD');
  if (!otpCheck.valid) {
    const error = new Error(otpCheck.message);
    error.status = 400;
    throw error;
  }

  const user = await authRepository.findUserByEmail(email);
  if (!user) {
    const error = new Error('Tài khoản không tồn tại');
    error.status = 404;
    throw error;
  }

  const passwordHash = await hashPassword(newPassword);
  await authRepository.updatePassword(user.id, passwordHash);

  return {
    message: 'Đặt lại mật khẩu thành công! Bạn có thể đăng nhập bằng mật khẩu mới.',
  };
};

module.exports = {
  register,
  verifyOtp,
  resendOtp,
  login,
  forgotPassword,
  resetPassword,
  otpStore, // Export để tiện kiểm thử nếu cần
};
