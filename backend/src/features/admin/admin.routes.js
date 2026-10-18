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

const schemaValidate = require('./admin.validation');
const upload = require('../../shared/middlewares/upload.middleware');

// Form có ảnh gửi danh sách ngày dưới dạng chuỗi JSON
const parseTemplateDays = (req, res, next) => {
  if (typeof req.body.days === 'string') {
    try {
      req.body.days = JSON.parse(req.body.days);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: 'Danh sách ngày không hợp lệ',
      });
    }
  }

  next();
};

// Kho lịch trình cho người dùng đã đăng nhập
router.get(
  '/library',
  authenticate,
  validate({ query: schemaValidate.templateQuerySchema }),
  adminController.listPublicTemplates
);

router.post(
  '/library/community/:id/apply',
  authenticate,
  validate({ params: adminIdParamSchema, body: schemaValidate.templateApplySchema }),
  adminController.applyCommunityPlan
);

router.get(
  '/library/community/:id',
  authenticate,
  validate({ params: adminIdParamSchema }),
  adminController.getCommunityPlan
);

router.get(
  '/library/templates/:id',
  authenticate,
  validate({ params: adminIdParamSchema }),
  adminController.getPublicTemplate
);

router.post(
  '/library/templates/:id/apply',
  authenticate,
  validate({ params: adminIdParamSchema, body: schemaValidate.templateApplySchema }),
  adminController.applyTemplate
);

// Quản lý báo cáo vi phạm
router.get(
  '/reports',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ query: schemaValidate.reportQuerySchema }),
  adminController.getReports
);

router.get(
  '/reports/:id',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema }),
  adminController.getReport
);

router.put(
  '/reports/:id/resolve',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, body: schemaValidate.resolveReportSchema }),
  adminController.resolveReport
);

// Quản lý lịch trình mẫu
router.get(
  '/templates',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ query: schemaValidate.templateQuerySchema }),
  adminController.listTemplates
);

router.post(
  '/templates/from-community/:id',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema }),
  adminController.importCommunityTemplate
);

router.post(
  '/templates',
  authenticate,
  authorize(ROLES.ADMIN),
  upload.single('coverImage'),
  parseTemplateDays,
  validate({ body: schemaValidate.templateBodySchema }),
  adminController.createTemplate
);

router.get(
  '/templates/:id',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema }),
  adminController.getTemplate
);

router.put(
  '/templates/:id',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema }),
  upload.single('coverImage'),
  parseTemplateDays,
  validate({ body: schemaValidate.templateUpdateSchema }),
  adminController.updateTemplate
);

router.put(
  '/templates/:id/status',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, body: schemaValidate.templateStatusSchema }),
  adminController.setTemplateStatus
);

router.delete(
  '/templates/:id',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, query: schemaValidate.templateDeleteQuerySchema }),
  adminController.deleteTemplate
);

// Kiểm duyệt bài tuyển bạn đồng hành
router.get(
  '/moderation/posts',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ query: schemaValidate.moderationQuerySchema }),
  adminController.getModerationPosts
);

router.get(
  '/moderation/posts/:id',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema }),
  adminController.getModerationPost
);

router.put(
  '/moderation/posts/:id',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, body: schemaValidate.moderatePostSchema }),
  adminController.moderatePost
);

// Quản lý báo cáo vi phạm
router.put(
  '/reports/:id/warn',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, body: schemaValidate.warnReportSchema }),
  adminController.warnReportedUser
);

// Xử lý báo cáo chuyến đi và kết luận trong cùng một giao dịch
router.put(
  '/reports/:id/process',
  authenticate,
  authorize(ROLES.ADMIN),
  validate({ params: adminIdParamSchema, body: schemaValidate.processTripReportSchema }),
  adminController.processTripReport
);

module.exports = router;
