const notificationsService = require('./notifications.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');

const getNotifications = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      limit,
      page,
      type,
      is_read,
      sort_by
    } = req.query;

    const result = await notificationsService.getNotifications({
      userId,
      limit,
      page,
      type,
      is_read,
      sort_by
    });

    sendSuccess(res, result);
  } catch (err) {
    sendError(res, err);
  }
};

module.exports = {
  getNotifications
};
