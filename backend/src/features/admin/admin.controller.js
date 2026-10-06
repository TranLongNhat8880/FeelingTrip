const adminService = require('./admin.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: Admin Portal
// Tiếp nhận Request, gọi Service và trả Response
// ============================================================================

/**
 * GET /api/v1/admin/users
 * Lấy danh sách tài khoản người dùng (phân trang, tìm kiếm, lọc)
 */
const getUsersList = async (req, res, next) => {
  try {
    const { page, limit, search, role, status } = req.query;
    const result = await adminService.getUsersList({ page, limit, search, role, status });
    return sendSuccess(res, result, 'Lấy danh sách người dùng thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

/**
 * PUT /api/v1/admin/users/:id/status
 * Khóa hoặc mở khóa tài khoản người dùng
 */
const updateUserStatus = async (req, res, next) => {
  try {
    const { id: userId } = req.params;
    const adminId = req.user.id;
    const { status, reason } = req.body;
    const result = await adminService.updateUserStatus({ adminId, userId, status, reason });
    const message = status === 'BANNED' ? 'Khóa tài khoản thành công' : 'Mở khóa tài khoản thành công';
    return sendSuccess(res, result, message, HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

/**
 * GET /api/v1/admin/ekyc/pending
 * Lấy danh sách hồ sơ CCCD đang chờ duyệt
 */
const getPendingEkycList = async (req, res, next) => {
  try {
    const { page, limit } = req.query;
    const result = await adminService.getPendingEkycList({ page, limit });
    return sendSuccess(res, result, 'Lấy danh sách hồ sơ eKYC chờ duyệt thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

/**
 * PUT /api/v1/admin/ekyc/:id/approve
 * Duyệt hồ sơ eKYC, cấp tích xanh xác minh
 */
const approveUserEkyc = async (req, res, next) => {
  try {
    const { id: userId } = req.params;
    const result = await adminService.approveUserEkyc(userId);
    return sendSuccess(res, result, 'Duyệt hồ sơ xác minh thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

/**
 * PUT /api/v1/admin/ekyc/:id/reject
 * Từ chối hồ sơ eKYC
 */
const rejectUserEkyc = async (req, res, next) => {
  try {
    const { id: userId } = req.params;
    const { reason } = req.body;
    const result = await adminService.rejectUserEkyc(userId, reason);
    return sendSuccess(res, result, 'Từ chối hồ sơ xác minh thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

module.exports = {
  getUsersList,
  updateUserStatus,
  getPendingEkycList,
  approveUserEkyc,
  rejectUserEkyc,
};
