const adminRepository = require('./admin.repository');
const notificationsService = require('../notifications/notifications.service');
const apiError = require('../../shared/utils/apiError.util');

// ============================================================================
// SERVICE: Admin Portal
// Xử lý toàn bộ logic nghiệp vụ
// ============================================================================

/**
 * Lấy danh sách người dùng (có phân trang + tìm kiếm + lọc)
 */
const getUsersList = async ({ page = 1, limit = 20, search, role, status }) => {
  const pageNum = parseInt(page, 10) || 1;
  const limitNum = parseInt(limit, 10) || 20;
  const offset = (pageNum - 1) * limitNum;

  const { rows, total } = await adminRepository.getUsersList({
    limit: limitNum,
    offset,
    search,
    role,
    status,
  });

  const users = rows.map((u) => ({
    id: u.id,
    fullName: u.full_name,
    email: u.email,
    phone: u.phone,
    avatarUrl: u.avatar_url,
    role: u.role,
    status: u.status,
    isVerified: u.is_verified,
    verificationStatus: u.verification_status,
    createdAt: u.created_at,
    updatedAt: u.updated_at,
  }));

  const totalPages = Math.ceil(total / limitNum);

  return {
    users,
    pagination: {
      totalItems: total,
      totalPages,
      currentPage: pageNum,
      limit: limitNum,
    },
  };
};

/**
 * Khóa / Mở khóa tài khoản người dùng
 */
const updateUserStatus = async ({ adminId, userId, status, reason }) => {
  // Admin không tự khóa chính mình
  if (adminId === userId) {
    throw apiError(400, 'Quản trị viên không thể tự khóa tài khoản của mình');
  }

  const target = await adminRepository.findUserById(userId);
  if (!target) {
    throw apiError(404, 'Người dùng không tồn tại');
  }

  if (target.role === 'ADMIN') {
    throw apiError(403, 'Không thể thay đổi trạng thái tài khoản quản trị viên khác');
  }

  if (target.status === status) {
    const label = status === 'BANNED' ? 'đã bị khóa' : 'đang hoạt động';
    throw apiError(400, `Tài khoản này ${label} rồi`);
  }

  const updated = await adminRepository.updateUserStatus(userId, status);
  if (!updated) {
    throw apiError(500, 'Cập nhật trạng thái thất bại');
  }

  // Gửi thông báo cho người dùng (không chặn response nếu lỗi)
  const notifTitle = status === 'BANNED' ? 'Tài khoản bị khóa' : 'Tài khoản được mở khóa';
  const notifMessage =
    status === 'BANNED'
      ? `Tài khoản của bạn đã bị khóa${reason ? `: ${reason}` : '. Vui lòng liên hệ hỗ trợ để biết thêm chi tiết'}`
      : 'Tài khoản của bạn đã được mở khóa. Chào mừng bạn trở lại!';

  notificationsService
    .createNotification({
      recipientId: userId,
      title: notifTitle,
      message: notifMessage,
      type: 'SYSTEM',
      data: { status, reason: reason || null },
    })
    .catch(() => {});

  return {
    id: updated.id,
    fullName: updated.full_name,
    email: updated.email,
    role: updated.role,
    status: updated.status,
    updatedAt: updated.updated_at,
  };
};

/**
 * Lấy danh sách hồ sơ eKYC đang chờ duyệt
 */
const getPendingEkycList = async ({ page = 1, limit = 20 }) => {
  const pageNum = parseInt(page, 10) || 1;
  const limitNum = parseInt(limit, 10) || 20;
  const offset = (pageNum - 1) * limitNum;

  const { rows, total } = await adminRepository.getPendingEkycList({
    limit: limitNum,
    offset,
  });

  const profiles = rows.map((u) => ({
    id: u.id,
    fullName: u.full_name,
    email: u.email,
    phone: u.phone,
    avatarUrl: u.avatar_url,
    verificationStatus: u.verification_status,
    cccdNumber: u.cccd_number,
    cccdFrontImage: u.cccd_front_image,
    cccdBackImage: u.cccd_back_image,
    selfieImage: u.selfie_image,
    submittedAt: u.ekyc_submitted_at,
  }));

  const totalPages = Math.ceil(total / limitNum);

  return {
    profiles,
    pagination: {
      totalItems: total,
      totalPages,
      currentPage: pageNum,
      limit: limitNum,
    },
  };
};

/**
 * Duyệt hồ sơ eKYC
 */
const approveUserEkyc = async (userId) => {
  const target = await adminRepository.findUserById(userId);
  if (!target) {
    throw apiError(404, 'Người dùng không tồn tại');
  }

  if (target.verification_status !== 'PENDING') {
    throw apiError(400, `Hồ sơ này không ở trạng thái chờ duyệt (hiện tại: ${target.verification_status})`);
  }

  const updated = await adminRepository.approveUserEkyc(userId);
  if (!updated) {
    throw apiError(409, 'Không thể duyệt hồ sơ, vui lòng thử lại');
  }

  notificationsService
    .createNotification({
      recipientId: userId,
      title: 'Xác minh danh tính thành công',
      message: 'Hồ sơ CCCD của bạn đã được duyệt. Bạn đã được cấp tích xanh xác minh!',
      type: 'SYSTEM',
      data: { verificationStatus: 'VERIFIED' },
    })
    .catch(() => {});

  return {
    id: updated.id,
    fullName: updated.full_name,
    email: updated.email,
    isVerified: updated.is_verified,
    verificationStatus: updated.verification_status,
    updatedAt: updated.updated_at,
  };
};

/**
 * Từ chối hồ sơ eKYC
 */
const rejectUserEkyc = async (userId, reason) => {
  const target = await adminRepository.findUserById(userId);
  if (!target) {
    throw apiError(404, 'Người dùng không tồn tại');
  }

  if (target.verification_status !== 'PENDING') {
    throw apiError(400, `Hồ sơ này không ở trạng thái chờ duyệt (hiện tại: ${target.verification_status})`);
  }

  const updated = await adminRepository.rejectUserEkyc(userId, reason);
  if (!updated) {
    throw apiError(409, 'Không thể từ chối hồ sơ, vui lòng thử lại');
  }

  notificationsService
    .createNotification({
      recipientId: userId,
      title: 'Xác minh danh tính không thành công',
      message: `Hồ sơ CCCD của bạn đã bị từ chối. Lý do: ${reason}`,
      type: 'SYSTEM',
      data: { verificationStatus: 'REJECTED', reason },
    })
    .catch(() => {});

  return {
    id: updated.id,
    fullName: updated.full_name,
    email: updated.email,
    isVerified: updated.is_verified,
    verificationStatus: updated.verification_status,
    rejectionReason: updated.verification_rejection_reason,
    updatedAt: updated.updated_at,
  };
};

module.exports = {
  getUsersList,
  updateUserStatus,
  getPendingEkycList,
  approveUserEkyc,
  rejectUserEkyc,
};
