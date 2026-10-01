const express = require('express');
const router = express.Router();
const notificationsController = require('./notifications.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const schemaValidate = require('./notifications.validation');

router.get('/',
  authenticate,
  validate({ query: schemaValidate.getNotificationsQuerySchema }),
  notificationsController.getNotifications
);
router.get('/unread-count',
  authenticate,
  notificationsController.getUnreadCount
);
router.put('/read-all',
  authenticate,
  notificationsController.markAllReadNotification
);
router.put('/:id/read',
  authenticate,
  validate({ params: schemaValidate.notificationIdParamSchema }),
  notificationsController.markReadNotification
);
router.delete('/',
  authenticate,
  notificationsController.deleteAllNotifications
);
router.delete('/:id',
  authenticate,
  validate({ params: schemaValidate.notificationIdParamSchema }),
  notificationsController.deleteNotification
);
module.exports = router;
