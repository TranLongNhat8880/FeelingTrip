const authService = require('./auth.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: Authentication
// Tiếp nhận Request từ Client, gọi Service và trả Response chuẩn
// ============================================================================

/**
 * [POST] /api/v1/auth/register
 * Đăng ký tài khoản mới và gửi mã OTP qua email
 */
const register = async (req, res, next) => {
  try {
    const { email, password, fullName, phone } = req.body;
    const result = await authService.register({ email, password, fullName, phone });
    return sendSuccess(res, result.user, result.message, HTTP_STATUS.CREATED);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/auth/verify-otp
 * Xác thực mã OTP và kích hoạt tài khoản
 */
const verifyOtp = async (req, res, next) => {
  try {
    const { email, otp } = req.body;
    const result = await authService.verifyOtp({ email, otp });
    return sendSuccess(res, { token: result.token, user: result.user }, result.message, HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/auth/resend-otp
 * Gửi lại mã OTP tới email
 */
const resendOtp = async (req, res, next) => {
  try {
    const { email, type } = req.body;
    const result = await authService.resendOtp({ email, type });
    return sendSuccess(res, null, result.message, HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/auth/login
 * Đăng nhập bằng email và mật khẩu
 */
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await authService.login({ email, password });
    return sendSuccess(res, { token: result.token, user: result.user }, result.message, HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/auth/forgot-password
 * Yêu cầu gửi OTP đặt lại mật khẩu
 */
const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    const result = await authService.forgotPassword({ email });
    return sendSuccess(res, null, result.message, HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/auth/reset-password
 * Nhập mã OTP và đặt mật khẩu mới
 */
const resetPassword = async (req, res, next) => {
  try {
    const { email, otp, newPassword } = req.body;
    const result = await authService.resetPassword({ email, otp, newPassword });
    return sendSuccess(res, null, result.message, HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

module.exports = {
  register,
  verifyOtp,
  resendOtp,
  login,
  forgotPassword,
  resetPassword,
};
