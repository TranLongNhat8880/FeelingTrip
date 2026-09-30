const db = require('../../config/database');

const getNotifications = async (filters) => {
  const { userId, limit = 20, offset = 0, type, is_read, sort_by } = filters;

  const conditions = ['user_id = $1'];
  const params = [userId];

  if (type !== undefined) {
    params.push(type);
    conditions.push(`type = $${params.length}`);
  }

  if (is_read !== undefined) {
    params.push(is_read);
    conditions.push(`is_read = $${params.length}`);
  }

  // Whitelist sort_by để chặn SQL Injection
  // Không cho phép client tự truyền chuỗi SQL bất kỳ vào ORDER BY
  const ALLOWED_SORT = {
    created_at: 'created_at DESC',
    is_read: 'is_read ASC, created_at DESC', // chưa đọc (false=0) lên đầu 
  };
  const orderClause = ALLOWED_SORT[sort_by] || 'created_at DESC';

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
};

module.exports = {
  getNotifications,
};
