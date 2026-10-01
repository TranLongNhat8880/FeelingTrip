const db = require('../../config/database');

const createNotification = async ({ recipientId, title, message, type, data = {} }, client = null) => {
  const query = `INSERT INTO notifications (user_id, title, message, type, data)
                 VALUES ($1, $2, $3, $4, $5)
                 RETURNING *
  `;
  const executor = client || db;
  const { rows } = await executor.query(query, [recipientId, title, message, type, data]);
  return rows[0];
}
  
const getNotifications = async (filters) => {
  const { userId, limit = 20, offset = 0, type, isRead, sortBy } = filters;

  const conditions = ['user_id = $1'];
  const params = [userId];

  if (type !== undefined) {
    params.push(type);
    conditions.push(`type = $${params.length}`);
  }

  if (isRead !== undefined) {
    params.push(isRead);
    conditions.push(`is_read = $${params.length}`);
  }

  // Whitelist sortBy để chặn SQL Injection và thêm id DESC để ổn định phân trang
  const ALLOWED_SORT = {
    createdAt: 'created_at DESC, id DESC',
    isRead: 'is_read ASC, created_at DESC, id DESC',
  };
  const orderClause = ALLOWED_SORT[sortBy] || 'created_at DESC, id DESC';

  params.push(limit, offset);
  const limitIndex = params.length - 1;
  const offsetIndex = params.length;

  const query = `
    SELECT * FROM notifications
    WHERE ${conditions.join(' AND ')}
    ORDER BY ${orderClause}
    LIMIT $${limitIndex} OFFSET $${offsetIndex}
  `;

  const result = await db.query(query, params);
  return result.rows;
}

const markReadNotification = async ({ notificationId, userId }) => {
  const query = `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING *`;
  const { rows } = await db.query(query, [notificationId, userId]);
  return rows[0];
}

const markAllReadNotification = async ({ userId }) => {
  const query = `UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false RETURNING *`;
  const { rows } = await db.query(query, [userId]);
  return rows; 
}

const deleteNotification = async ({ notificationId, userId }) => {
  const query = `DELETE FROM notifications WHERE id = $1 AND user_id = $2 RETURNING *`;
  const { rows } = await db.query(query, [notificationId, userId]);
  return rows[0];
}

const deleteAllNotifications = async ({ userId }) => {
  const query = `DELETE FROM notifications WHERE user_id = $1 RETURNING *`;
  const { rows } = await db.query(query, [userId]);
  return rows;
}

const getUnreadCount = async ({ userId }) => {
  const query = `
    SELECT COUNT(*) AS count
    FROM notifications
    WHERE user_id = $1 AND is_read = false
  `;
  const { rows } = await db.query(query, [userId]);
  return parseInt(rows[0].count, 10);
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
