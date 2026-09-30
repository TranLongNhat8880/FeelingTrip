const notificationsRepository = require('./notifications.repository');

const getNotifications = async ({ userId, limit, page, type, is_read, sort_by }) => {
  const offset = (page - 1) * limit;
  return notificationsRepository.getNotifications({
    userId, limit, offset, type, is_read, sort_by
  });
};
module.exports = {
    getNotifications
};
