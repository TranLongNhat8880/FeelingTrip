const express = require('express');
const router = express.Router();
const adminController = require('./admin.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const authorize = require('../../shared/middlewares/role.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const { ROLES } = require('../../shared/constants/roles');
const {
  updateUserStatusSchema,
  rejectEkycSchema,
  adminIdParamSchema,
  getUsersQuerySchema,
  getEkycPendingQuerySchema,
} = require('./admin.validation');

// ============================================================================
// ROUTES: Admin Portal
// Tất cả routes đều yêu cầu authenticate + authorize(ADMIN)
// ============================================================================

// ----- Quản lý người dùng -----

// GET /api/v1/admin/users — Lấy danh sách tài khoản (phân trang, tìm kiếm)
router.get(
  '/users',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ query: getUsersQuerySchema }),
  adminController.getUsersList
);

// PUT /api/v1/admin/users/:id/status — Khóa / Mở khóa tài khoản
router.put(
  '/users/:id/status',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, body: updateUserStatusSchema }),
  adminController.updateUserStatus
);

// ----- Quản lý eKYC -----

// GET /api/v1/admin/ekyc/pending — Danh sách hồ sơ chờ duyệt
router.get(
  '/ekyc/pending',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ query: getEkycPendingQuerySchema }),
  adminController.getPendingEkycList
);

// PUT /api/v1/admin/ekyc/:id/approve — Duyệt hồ sơ eKYC
router.put(
  '/ekyc/:id/approve',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema }),
  adminController.approveUserEkyc
);

// PUT /api/v1/admin/ekyc/:id/reject — Từ chối hồ sơ eKYC
router.put(
  '/ekyc/:id/reject',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, body: rejectEkycSchema }),
  adminController.rejectUserEkyc
);

module.exports = router;
