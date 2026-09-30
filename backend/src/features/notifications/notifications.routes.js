const express = require('express');
const router = express.Router();
const notificationsController = require('./notifications.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const { getNotificationsQuerySchema } = require('./notifications.validation');

router.get('/',
  authenticate,
  validate({ query: getNotificationsQuerySchema }),
  notificationsController.getNotifications
);

module.exports = router;
