const express = require('express');
const router = express.Router();
const authController = require('./auth.controller');

// ============================================================================
// ROUTES: Authentication (/api/v1/auth)
// Định nghĩa các endpoint xác thực, đăng nhập và bảo mật
// ============================================================================

// Đăng ký tài khoản & Xác thực OTP qua Email
router.post('/register', authController.register);
router.post('/verify-otp', authController.verifyOtp);
router.post('/resend-otp', authController.resendOtp);
router.post('/send-otp', authController.resendOtp); // Alias cho frontend Flutter

// Đăng nhập
router.post('/login', authController.login);

// Quên mật khẩu & Đặt lại mật khẩu
router.post('/forgot-password', authController.forgotPassword);
router.post('/forgot-pass', authController.forgotPassword); // Alias cho frontend Flutter
router.post('/reset-password', authController.resetPassword);

module.exports = router;
