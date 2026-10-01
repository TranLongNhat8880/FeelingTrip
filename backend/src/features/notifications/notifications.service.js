const notificationsRepository = require('./notifications.repository');

/**
 * Tạo thông báo mới cho người dùng (Dùng nội bộ giữa các Service)
 * 
 * @param {Object} params - Thông tin tạo thông báo
 * @param {string} params.recipientId - ID của người nhận thông báo (UUID)
 * @param {string} params.title - Tiêu đề thông báo
 * @param {string} params.message - Nội dung chi tiết thông báo
 * @param {('INVITE'|'REQUEST'|'BILL'|'TRIP_UPDATE'|'SYSTEM')} params.type - Loại thông báo
 * @param {Object} [params.data={}] - Dữ liệu mở rộng đính kèm (ví dụ: { tripId, billId })
 * @param {Object} [client=null] - DB client nếu thực hiện trong Transaction (tùy chọn)
 * 
 * @returns {Promise<Object>} Object thông báo vừa được tạo trong Database
 * 
 * @example
 * await notificationsService.createNotification({
 *   recipientId: memberId,
 *   title: 'Lời mời chuyến đi',
 *   message: 'Bạn được mời tham gia chuyến đi Đà Lạt',
 *   type: 'INVITE',
 *   data: { tripId: '123' }
 * });
 */
const createNotification = async ({ recipientId, title, message, type, data = {} }, client = null) => {
  return notificationsRepository.createNotification({ recipientId, title, message, type, data }, client);
};

const getNotifications = async ({ userId, limit, page, type, isRead, sortBy }) => {
  const offset = (page - 1) * limit;
  return notificationsRepository.getNotifications({
    userId, limit, offset, type, isRead, sortBy
  });
};

const markReadNotification = async ({ notificationId, userId }) => {
  const notification = await notificationsRepository.markReadNotification({ notificationId, userId });
  if (!notification) {
    const error = new Error('Thông báo không tồn tại');
    error.statusCode = 404;
    throw error;
  }
  return notification;
}

const markAllReadNotification = async ({ userId }) => {
  return notificationsRepository.markAllReadNotification({ userId });
}

const deleteNotification = async ({ notificationId, userId }) => {
  const notification = await notificationsRepository.deleteNotification({ notificationId, userId });
  if (!notification) {
    const error = new Error('Thông báo không tồn tại');
    error.statusCode = 404;
    throw error;
  }
  return notification;
}

const deleteAllNotifications = async ({ userId }) => {
  return notificationsRepository.deleteAllNotifications({ userId });
}

const getUnreadCount = async ({ userId }) => {
  const count = await notificationsRepository.getUnreadCount({ userId });
  return { unreadCount: count };
};

module.exports = {
  createNotification,
  getNotifications,
  getUnreadCount,
  markReadNotification,
  markAllReadNotification,
  deleteNotification,
  deleteAllNotifications,
};
