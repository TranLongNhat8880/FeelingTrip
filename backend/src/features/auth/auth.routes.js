const express = require('express');
const router = express.Router();
const rateLimit = require('../../shared/middlewares/rateLimit.middleware');
router.use(rateLimit('auth', 40, 900));
const authController = require('./auth.controller');
const validate = require('../../shared/middlewares/validate.middleware');
const {
  registerSchema,
  verifyOtpSchema,
  loginSchema,
  resendOtpSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
} = require('./auth.validation');

// ============================================================================
// ROUTES: Authentication (/api/v1/auth)
// Định nghĩa các endpoint xác thực, đăng nhập và bảo mật
// ============================================================================

// Đăng ký tài khoản & Xác thực OTP qua Email
router.post('/register', validate(registerSchema), authController.register);
router.post('/verify-otp', validate(verifyOtpSchema), authController.verifyOtp);
router.post('/resend-otp', validate(resendOtpSchema), authController.resendOtp);
router.post('/send-otp', validate(resendOtpSchema), authController.resendOtp); // Alias cho frontend Flutter

// Đăng nhập
router.post('/login', validate(loginSchema), authController.login);

// Quên mật khẩu & Đặt lại mật khẩu
router.post('/forgot-password', validate(forgotPasswordSchema), authController.forgotPassword);
router.post('/forgot-pass', validate(forgotPasswordSchema), authController.forgotPassword); // Alias cho frontend Flutter
router.post('/reset-password', validate(resetPasswordSchema), authController.resetPassword);

module.exports = router;
