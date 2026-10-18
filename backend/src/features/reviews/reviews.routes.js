const express = require('express');

const reviewsController = require('./reviews.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const upload = require('../../shared/middlewares/upload.middleware');

const {
    reviewMemberSchema,
    reviewTripSchema,
    tripReviewsQuerySchema,
    reportSchema,
    blockUserSchema,
    idParamSchema,
} = require('./reviews.validation');

const router = express.Router();

// Toàn bộ chức năng reviews/safety yêu cầu đăng nhập.
router.use(authenticate);

// ============================================================================
// REVIEWS
// ============================================================================

router.post(
    '/member',
    validate({ body: reviewMemberSchema }),
    reviewsController.reviewMember
);

router.post(
    '/trip',
    validate({ body: reviewTripSchema }),
    reviewsController.reviewTrip
);

router.get(
    '/trip/:id',
    validate({ params: idParamSchema, query: tripReviewsQuerySchema }),
    reviewsController.getTripReviews
);

// ============================================================================
// REPORTS
// ============================================================================

/**
 * Có thể gửi JSON nếu không có ảnh.
 *
 * Nếu có ảnh bằng chứng, dùng multipart/form-data:
 * - reportedUserId: Text, không bắt buộc
 * - reportedTripId: Text, không bắt buộc
 * - reason: Text
 * - evidence: File, không bắt buộc
 */
router.post(
    '/report',
    upload.single('evidence'),
    validate({ body: reportSchema }),
    reviewsController.createReport
);

// ============================================================================
// BLOCKS
// ============================================================================

router.post(
    '/block',
    validate({ body: blockUserSchema }),
    reviewsController.blockUser
);

router.get(
    '/blocked-users',
    reviewsController.getBlockedUsers
);

router.delete(
    '/block/:id',
    validate({ params: idParamSchema }),
    reviewsController.unblockUser
);

module.exports = router;
