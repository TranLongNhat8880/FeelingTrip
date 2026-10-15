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
    createEmergencyContactSchema,
    updateEmergencyContactSchema,
    emergencySosSchema,
    activeSosQuerySchema,
    sosHistoryQuerySchema,
    updateSosStatusSchema,
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

// ============================================================================
// EMERGENCY CONTACTS
// ============================================================================

router.get(
    '/emergency-contacts',
    reviewsController.getEmergencyContacts
);

router.post(
    '/emergency-contacts',
    validate({ body: createEmergencyContactSchema }),
    reviewsController.createEmergencyContact
);

router.put(
    '/emergency-contacts/:id',
    validate({
        params: idParamSchema,
        body: updateEmergencyContactSchema,
    }),
    reviewsController.updateEmergencyContact
);

router.delete(
    '/emergency-contacts/:id',
    validate({ params: idParamSchema }),
    reviewsController.deleteEmergencyContact
);

// ============================================================================
// SOS
// ============================================================================

router.get('/sos/active', validate({ query: activeSosQuerySchema }), reviewsController.getActiveSos);
router.get('/sos/history', validate({ query: sosHistoryQuerySchema }), reviewsController.getSosHistory);

router.post(
    '/sos',
    validate({ body: emergencySosSchema }),
    reviewsController.createSos
);

router.put(
    '/sos/:id/status',
    validate({
        params: idParamSchema,
        body: updateSosStatusSchema,
    }),
    reviewsController.updateSosStatus
);

module.exports = router;
