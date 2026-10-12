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

// Public library routes require login, but do not require ADMIN.
const v = require('./admin.validation');
const upload = require('../../shared/middlewares/upload.middleware');
const parseTemplateDays = (req,res,next)=>{
  if(typeof req.body.days==='string'){
    try {req.body.days=JSON.parse(req.body.days);} catch(_){return res.status(400).json({success:false,message:'Danh sách ngày không hợp lệ'});}
  }
  next();
};
router.get('/library',authenticate,validate({query:v.templateQuerySchema}),adminController.listPublicTemplates);
router.post('/library/community/:id/apply',authenticate,validate({params:adminIdParamSchema,body:v.templateApplySchema}),adminController.applyCommunityPlan);
router.get('/library/community/:id',authenticate,validate({params:adminIdParamSchema}),adminController.getCommunityPlan);
router.get('/library/templates/:id',authenticate,validate({params:adminIdParamSchema}),adminController.getPublicTemplate);
router.post('/library/templates/:id/apply',authenticate,validate({params:adminIdParamSchema,body:v.templateApplySchema}),adminController.applyTemplate);

router.get('/reports',authenticate,authorize(ROLES.ADMIN),validate({query:v.reportQuerySchema}),adminController.getReports);
router.get('/reports/:id',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema}),adminController.getReport);
router.put('/reports/:id/resolve',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema,body:v.resolveReportSchema}),adminController.resolveReport);
router.get('/templates',authenticate,authorize(ROLES.ADMIN),validate({query:v.templateQuerySchema}),adminController.listTemplates);
router.post('/templates/from-community/:id',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema}),adminController.importCommunityTemplate);
router.post('/templates',authenticate,authorize(ROLES.ADMIN),upload.single('coverImage'),parseTemplateDays,validate({body:v.templateBodySchema}),adminController.createTemplate);
router.get('/templates/:id',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema}),adminController.getTemplate);
router.put('/templates/:id',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema}),upload.single('coverImage'),parseTemplateDays,validate({body:v.templateUpdateSchema}),adminController.updateTemplate);
router.put('/templates/:id/status',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema,body:v.templateStatusSchema}),adminController.setTemplateStatus);
router.delete('/templates/:id',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema,query:v.templateDeleteQuerySchema}),adminController.deleteTemplate);

router.get('/moderation/posts',authenticate,authorize(ROLES.ADMIN),validate({query:v.moderationQuerySchema}),adminController.getModerationPosts);
router.get('/moderation/posts/:id',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema}),adminController.getModerationPost);
router.put('/moderation/posts/:id',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema,body:v.moderatePostSchema}),adminController.moderatePost);
router.put('/reports/:id/warn',authenticate,authorize(ROLES.ADMIN),validate({params:adminIdParamSchema,body:v.warnReportSchema}),adminController.warnReportedUser);
module.exports = router;
