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

const getReports = async (req,res,next)=>{
  try {const data=await adminService.getReports(req.query);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const getReport = async (req,res,next)=>{
  try {const data=await adminService.getReport(req.params.id);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const resolveReport = async (req,res,next)=>{
  try {const data=await adminService.resolveReport(req.params.id, req.body);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const listTemplates = async (req,res,next)=>{
  try {const data=await adminService.listTemplates(req.query);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const listPublicTemplates = async (req,res,next)=>{
  try {const data=await adminService.listTemplates(req.query, true);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const getTemplate = async (req,res,next)=>{
  try {const data=await adminService.getTemplate(req.params.id);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const getPublicTemplate = async (req,res,next)=>{
  try {const data=await adminService.getTemplate(req.params.id, true);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const createTemplate = async (req,res,next)=>{
  try {const data=await adminService.createTemplate(req.body, req.user.id, req.file?.path);return sendSuccess(res,data,'Đã cập nhật dữ liệu',201);}
  catch(error){next(error);}
};

const updateTemplate = async (req,res,next)=>{
  try {const data=await adminService.updateTemplate(req.params.id, req.body, req.user.id, req.file?.path);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const setTemplateStatus = async (req,res,next)=>{
  try {const data=await adminService.setTemplateStatus(req.params.id, req.body);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const deleteTemplate = async (req,res,next)=>{
  try {const data=await adminService.deleteTemplate(req.params.id, req.query.expectedVersion);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const applyTemplate = async (req,res,next)=>{
  try {const data=await adminService.applyTemplate(req.params.id, req.body.tripId, req.user.id);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const getCommunityPlan = async (req,res,next)=>{
  try {const data=await adminService.getCommunityPlan(req.params.id);return sendSuccess(res,data,'Đã cập nhật dữ liệu',200);}
  catch(error){next(error);}
};

const importCommunityTemplate = async (req,res,next)=>{
  try {const data=await adminService.importCommunityTemplate(req.params.id, req.user.id);return sendSuccess(res,data,'Đã cập nhật dữ liệu',201);}
  catch(error){next(error);}
};

const applyCommunityPlan = async (req,res,next)=>{
  try{return sendSuccess(res,await adminService.applyCommunityPlan(req.params.id,req.body.tripId,req.user.id));}catch(error){next(error);}
};

const getModerationPosts = async(req,res,next)=>{
  try{return sendSuccess(res,await adminService.getModerationPosts(req.query),'Danh sách bài tuyển',200);}catch(error){next(error);}
};
const getModerationPost = async(req,res,next)=>{
  try{return sendSuccess(res,await adminService.getModerationPost(req.params.id),'Chi tiết bài tuyển',200);}catch(error){next(error);}
};
const moderatePost = async(req,res,next)=>{
  try{return sendSuccess(res,await adminService.moderatePost(req.params.id,req.body),'Đã xử lý bài tuyển',200);}catch(error){next(error);}
};
const warnReportedUser = async(req,res,next)=>{
  try{return sendSuccess(res,await adminService.warnReportedUser(req.params.id,req.body.reason),'Đã cảnh cáo',200);}catch(error){next(error);}
};

module.exports = {
  getModerationPosts,getModerationPost,moderatePost,warnReportedUser,
  applyCommunityPlan,
  getReports, getReport, resolveReport, listTemplates, listPublicTemplates, getTemplate, getPublicTemplate, createTemplate, updateTemplate, setTemplateStatus, deleteTemplate, applyTemplate, getCommunityPlan, importCommunityTemplate,
  getUsersList,
  updateUserStatus,
  getPendingEkycList,
  approveUserEkyc,
  rejectUserEkyc,
};
