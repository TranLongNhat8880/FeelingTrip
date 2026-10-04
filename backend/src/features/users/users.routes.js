const express = require('express');

const usersController = require('./users.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const upload = require('../../shared/middlewares/upload.middleware');

const {
    updateProfileSchema,
    ekycVerifySchema,
    userIdParamSchema,
} = require('./users.validation');

const router = express.Router();

// ============================================================================
// ROUTES: User Profile & eKYC
// ============================================================================

/**
 * Bank Hub giữ nguyên luồng do Nhật triển khai.
 *
 * Endpoints thực tế:
 * /api/v1/users/me/bank/...
 */
router.use('/me/bank', require('../bankhub/bankhub.routes'));

/**
 * Lấy hồ sơ của người dùng đang đăng nhập.
 */
router.get(
    '/profile',
    authenticate,
    usersController.getProfile
);

/**
 * Cập nhật hồ sơ và/hoặc avatar.
 *
 * Có thể gửi:
 * - application/json nếu chỉ cập nhật thông tin chữ.
 * - multipart/form-data nếu có ảnh avatar.
 *
 * Tên multipart field của ảnh: avatar
 */
router.put(
    '/profile',
    authenticate,
    upload.single('avatar'),
    validate({ body: updateProfileSchema }),
    usersController.updateProfile
);

/**
 * Nộp hoặc nộp lại hồ sơ eKYC bằng multipart/form-data.
 *
 * Các field:
 * - cccdNumber: text
 * - cccdFrontImage: file
 * - cccdBackImage: file
 * - selfieImage: file
 */
router.post(
    '/ekyc-verify',
    authenticate,
    upload.fields([
        { name: 'cccdFrontImage', maxCount: 1 },
        { name: 'cccdBackImage', maxCount: 1 },
        { name: 'selfieImage', maxCount: 1 },
    ]),
    validate({ body: ekycVerifySchema }),
    usersController.submitEkyc
);

/**
 * Điểm tín nhiệm là dữ liệu công khai nên không yêu cầu đăng nhập.
 */
router.get(
    '/trust-score/:id',
    validate({ params: userIdParamSchema }),
    usersController.getTrustScore
);

module.exports = router;