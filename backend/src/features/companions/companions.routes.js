const express = require('express');
const router = express.Router();
const companionsController = require('./companions.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const schemaValidate = require('./companions.validation');

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

module.exports = router;
