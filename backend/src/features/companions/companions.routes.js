const express = require('express');
const router = express.Router();
const companionsController = require('./companions.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const schemaValidate = require('./companions.validation');

router.get('/posted-trips', authenticate, companionsController.getPostedTripIds);

router.get('/feed',
    authenticate,
    validate({ query: schemaValidate.companionFeedQuerySchema }),
    companionsController.getCompanionFeed
);

router.post('/posts',
    authenticate,
    validate({ body: schemaValidate.createCompanionPostSchema }),
    companionsController.createCompanionPost
);

router.get('/posts/:postId',
    authenticate,
    validate({ params: schemaValidate.postIdParamSchema }),
    companionsController.getCompanionPostDetail
);

router.patch('/posts/:postId',
    authenticate,
    validate({
        params: schemaValidate.postIdParamSchema,
        body: schemaValidate.updateCompanionPostSchema
    }),
    companionsController.updateCompanionPost
);

router.delete('/posts/:postId',
    authenticate,
    validate({ params: schemaValidate.postIdParamSchema }),
    companionsController.deleteCompanionPost
);

// Gửi yêu cầu xin tham gia ghép đoàn
router.post('/join-request',
    authenticate,
    validate({ body: schemaValidate.createJoinRequestSchema }),
    companionsController.createJoinRequest
);

// Trưởng nhóm xem các yêu cầu tham gia gửi tới chuyến đi của mình
router.get('/my-requests',
    authenticate,
    validate({ query: schemaValidate.myRequestsQuerySchema }),
    companionsController.getMyReceivedRequests
);

// Người gửi hủy yêu cầu tham gia (Xóa cứng khi còn PENDING)
router.delete('/requests/:requestId',
    authenticate,
    validate({ params: schemaValidate.requestIdParamSchema }),
    companionsController.deleteJoinRequest
);

// Trưởng nhóm xét duyệt yêu cầu (Accept hoặc Reject)
router.put('/requests/:requestId',
    authenticate,
    validate({
        params: schemaValidate.requestIdParamSchema,
        body: schemaValidate.reviewJoinRequestSchema,
    }),
    companionsController.reviewJoinRequest
);

// Alias PATCH cho frontend
router.patch('/requests/:requestId',
    authenticate,
    validate({
        params: schemaValidate.requestIdParamSchema,
        body: schemaValidate.reviewJoinRequestSchema,
    }),
    companionsController.reviewJoinRequest
);

module.exports = router;
