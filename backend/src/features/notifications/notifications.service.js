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
const createNotification = async ({ recipientId, title, message, type, data = {} }) => {
  return notificationsRepository.createNotification({ recipientId, title, message, type, data });
};

const getNotifications = async ({ userId, limit, page, type, isRead, sortBy }) => {
  const offset = (page - 1) * limit;
  return notificationsRepository.getNotifications({
    userId, limit, offset, type, isRead, sortBy
  });
};

const markReadNotification = async ({ notificationId, userId }) => {
  return notificationsRepository.markReadNotification({ notificationId, userId });
}

const markAllReadNotification = async ({ userId }) => {
  return notificationsRepository.markAllReadNotification({ userId });
}

const deleteNotification = async ({ notificationId, userId }) => {
  return notificationsRepository.deleteNotification({ notificationId, userId });
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
