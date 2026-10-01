const notificationsService = require('./notifications.service');
const { sendSuccess } = require('../../shared/utils/response.util');

const getNotifications = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const {
      limit,
      page,
      type,
      isRead,
      sortBy
    } = req.query;

    const result = await notificationsService.getNotifications({
      userId,
      limit,
      page,
      type,
      isRead,
      sortBy
    });

    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

const markReadNotification = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const notificationId = req.params.id;
    const result = await notificationsService.markReadNotification({ notificationId, userId });
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

const markAllReadNotification = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const result = await notificationsService.markAllReadNotification({ userId });
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

const deleteNotification = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const notificationId = req.params.id;
    const result = await notificationsService.deleteNotification({ notificationId, userId });
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

const deleteAllNotifications = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const result = await notificationsService.deleteAllNotifications({ userId });
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

const getUnreadCount = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const result = await notificationsService.getUnreadCount({ userId });
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getNotifications,
  getUnreadCount,
  markReadNotification,
  markAllReadNotification,
  deleteNotification,
  deleteAllNotifications,
};
