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

const db = require('../../config/database');
const pagination = (total,page,limit)=>({totalItems:total,totalPages:Math.ceil(total/limit),currentPage:page,limit});
const mapReport = row=>({id:row.id,reporterId:row.reporter_id,reporterName:row.reporter_name,
  reportedUserId:row.reported_user_id,reportedUserName:row.target_name,reportedUserStatus:row.target_status,reportedUserRole:row.target_role,
  reportedTripId:row.reported_trip_id,reportedTripName:row.trip_name,reason:row.reason,evidenceImageUrl:row.evidence_image_url,
  status:row.status,adminNotes:row.admin_notes,createdAt:row.created_at});
const mapTemplate = (row,community=false)=>({id:row.id,name:row.name,destination:row.destination,
  durationDays:Number(row.duration_days),estimatedBudget:Number(row.estimated_budget||0),description:row.description,
  coverImageUrl:row.cover_image_url,isActive:community?true:row.is_active,source:community?'COMMUNITY':'SYSTEM',
  sourceTripId:row.source_trip_id,usageCount:Number(row.usage_count||0),averageRating:Number(row.average_rating||0),
  reviewCount:Number(row.review_count||0),days:row.days||[],version:row.row_version,createdAt:row.created_at});
const getReports = async query=>{
  const {rows,total}=await adminRepository.getReports(query);
  return {items:rows.map(mapReport),pagination:pagination(total,query.page,query.limit)};
};
const getReport = async id=>{
  const row=await adminRepository.getReport(id);if(!row)throw apiError(404,'Báo cáo không tồn tại');return {...mapReport(row),context:await adminRepository.getReportContext(row)};
};
const resolveReport = async (id,data)=>db.transaction(async client=>{
  const row=await adminRepository.getReport(id,client,true);
  if(!row)throw apiError(404,'Báo cáo không tồn tại');
  if(row.status!=='PENDING')throw apiError(409,'Báo cáo đã được xử lý');
  await adminRepository.resolveReport(id,data.action,data.adminNotes,client);
  await notificationsService.createNotification({recipientId:row.reporter_id,title:'Kết quả báo cáo vi phạm',
    message:data.action==='RESOLVED'?'Báo cáo của bạn đã được quản trị viên xử lý.':data.adminNotes.startsWith('[Chưa đủ bằng chứng]')?'Báo cáo chưa đủ bằng chứng để kết luận vi phạm. Bạn có thể bổ sung bằng chứng qua bộ phận hỗ trợ.':'Báo cáo của bạn đã được xem xét và bác bỏ.',
    type:'SYSTEM',data:{reportId:id,status:data.action}},client);
  return mapReport({...row,status:data.action,admin_notes:data.adminNotes});
});
const listTemplates = async (query,publicOnly=false)=>{
  const {rows,total}=await adminRepository.listTemplates(query,publicOnly);
  return {items:rows.map(row=>mapTemplate(row,publicOnly&&query.source==='COMMUNITY')),pagination:pagination(total,query.page,query.limit)};
};
const getTemplate = async (id,publicOnly=false)=>{
  const row=await adminRepository.getTemplate(id);
  if(!row||(publicOnly&&!row.is_active))throw apiError(404,'Lịch trình mẫu không còn hiển thị');
  return mapTemplate(row);
};
const validateTemplateDays = data=>{
  if(data.days.length!==data.durationDays)throw apiError(400,'Số ngày phải bằng số ngày trong lịch trình');
  for(let i=0;i<data.days.length;i++){
    if(data.days[i].dayNumber!==i+1)throw apiError(400,'Các ngày phải liên tục từ ngày 1');
    const items=data.days[i].items;
    for(let j=1;j<items.length;j++)if(items[j].startTime<items[j-1].endTime)throw apiError(400,'Các hoạt động trong ngày không được trùng giờ và phải theo thứ tự');
  }
};
const checkTemplatePlaces = async (data,client,normalize=false)=>{
  const ids=[...new Set(data.days.flatMap(day=>day.items.map(item=>item.placeId).filter(Boolean)))];
  if(!ids.length)return;
  const places=await adminRepository.getActiveTemplatePlaces(ids,client);
  if(places.length!==ids.length)throw apiError(409,'Có địa điểm đã bị ẩn hoặc không tồn tại. Hãy chọn lại hoặc chuyển hoạt động sang nhập tự do.');
  if(normalize){
    for(const day of data.days)for(const item of day.items){
      if(!item.placeId)continue;
      const place=places.find(place=>place.id===item.placeId);
      item.customName=place.name;item.customAddress=place.address||'';item.category=place.category;
    }
  }
};
const createTemplate = async (data,userId,cover)=>db.transaction(async client=>{
  validateTemplateDays(data);
  await checkTemplatePlaces(data,client,true);
  return mapTemplate(await adminRepository.saveTemplate(null,data,userId,client,cover));
});
const updateTemplate = async (id,data,userId,cover)=>db.transaction(async client=>{
  validateTemplateDays(data);
  const row=await adminRepository.getTemplate(id,client,true);
  if(!row)throw apiError(404,'Lịch trình mẫu không tồn tại');
  if(row.row_version!==data.expectedVersion)throw apiError(409,'Mẫu đã được cập nhật, hãy tải lại');
  await checkTemplatePlaces(data,client,true);
  return mapTemplate(await adminRepository.saveTemplate(id,data,userId,client,cover));
});
const setTemplateStatus = async (id,data)=>db.transaction(async client=>{
  const row=await adminRepository.getTemplate(id,client,true);
  if(!row)throw apiError(404,'Lịch trình mẫu không tồn tại');
  if(row.row_version!==data.expectedVersion)throw apiError(409,'Mẫu đã được cập nhật, hãy tải lại');
  return mapTemplate(await adminRepository.setTemplateStatus(id,data.isActive,client));
});
const deleteTemplate = async (id,version)=>db.transaction(async client=>{
  const row=await adminRepository.getTemplate(id,client,true);
  if(!row)throw apiError(404,'Lịch trình mẫu không tồn tại');
  if(row.row_version!==version)throw apiError(409,'Mẫu đã được cập nhật, hãy tải lại');
  if(Number(row.usage_count)>0)throw apiError(409,'Mẫu đang được sử dụng. Bạn có thể ẩn mẫu thay vì xóa.');
  await adminRepository.deleteTemplate(id,client);return {id};
});
const applyTemplate = async (id,tripId,userId,community=false)=>db.transaction(async client=>{
  // Khóa chuyến đích trước để không ghi đè khi hai yêu cầu cùng sao chép.
  const {rows:[trip]}=await client.query('SELECT * FROM trips WHERE id=$1 FOR UPDATE',[tripId]);
  if(!trip)throw apiError(404,'Chuyến đi không tồn tại');
  const member=(await client.query("SELECT 1 FROM trip_members WHERE trip_id=$1 AND user_id=$2 AND role='LEADER' AND membership_status='ACTIVE'",[tripId,userId])).rows[0];
  if(!member)throw apiError(403,'Chỉ trưởng nhóm hiện tại được sử dụng mẫu');
  if(!['UPCOMING','ONGOING'].includes(trip.status))throw apiError(400,'Chuyến đi đã kết thúc hoặc đã hủy');
  const template=community?await adminRepository.getCommunityTemplateData(id,client,true):await adminRepository.getTemplate(id,client,true);
  if(!template||(!community&&!template.is_active))throw apiError(404,'Lịch trình mẫu không còn hiển thị');
  if(Number(trip.duration_days)!==template.duration_days)throw apiError(400,'Số ngày của chuyến đi phải bằng số ngày của mẫu');
  const exists=(await client.query('SELECT 1 FROM itineraries WHERE trip_id=$1 LIMIT 1',[tripId])).rows[0];
  if(exists)throw apiError(409,'Chuyến đi đã có lịch trình, không thể ghi đè');
  if(community)validateTemplateDays({durationDays:template.duration_days,days:template.days});
  await checkTemplatePlaces(template,client);
  await adminRepository.applyTemplate(template,trip,userId,client,community);
  return {tripId,templateId:id};
});
const getCommunityPlan = async id=>{
  const row=await adminRepository.getCommunityTemplateData(id);
  if(!row)throw apiError(404,'Lịch trình cộng đồng không còn công khai');
  return mapTemplate(row,true);
};
const applyCommunityPlan = async (id,tripId,userId)=>applyTemplate(id,tripId,userId,true);
const importCommunityTemplate = async (id,userId)=>{
  const source=await adminRepository.getCommunityTemplateData(id);
  if(!source)throw apiError(404,'Lịch trình cộng đồng không còn công khai');
  const data={name:source.name,destination:source.destination,durationDays:source.duration_days,estimatedBudget:Number(source.estimated_budget||0),description:source.description,days:source.days};
  const {value,error}=require('./admin.validation').templateBodySchema.validate(data,{stripUnknown:true});
  if(error)throw apiError(422,'Lịch trình nguồn chưa đủ dữ liệu hợp lệ để tạo mẫu');
  validateTemplateDays(value);
  return db.transaction(async client=>{
    await checkTemplatePlaces(value,client);
    return mapTemplate(await adminRepository.saveTemplate(null,value,userId,client,source.cover_image_url,id));
  });
};

const getModerationPosts = async query => {
  const {rows,total}=await adminRepository.getModerationPosts(query);
  return {items:rows,pagination:pagination(total,query.page,query.limit)};
};
const getModerationPost = async id => {
  const row=await adminRepository.getModerationPost(id);
  if(!row)throw apiError(404,'Bài đăng không tồn tại');
  return row;
};
const moderatePost = async (id,data)=>db.transaction(async client=>{
  const existing=await adminRepository.getModerationPost(id,client);
  if(!existing)throw apiError(404,'Bài đăng không tồn tại');
  await adminRepository.lockModerationTrip(existing.trip_id,client);
  const row=await adminRepository.getModerationPost(id,client);
  if(row.status==='CLOSED')throw apiError(409,'Bài đăng đã đóng hoặc đã bị ẩn');
  if(data.action==='HIDE')await adminRepository.hideModerationPost(id,client);
  const leader=await adminRepository.getModerationLeader(row.trip_id,client)||row.creator_id;
  await notificationsService.createNotification({recipientId:leader,title:data.action==='HIDE'?'Bài tuyển đã bị ẩn':'Cảnh cáo bài tuyển',message:data.reason,type:'SYSTEM',data:{postId:id,tripId:row.trip_id,action:data.action}},client);
  return {...row,status:data.action==='HIDE'?'CLOSED':row.status};
});
const warnReportedUser = async (id,reason)=>db.transaction(async client=>{
  const row=await adminRepository.getReport(id,client,true);
  if(!row)throw apiError(404,'Báo cáo không tồn tại');
  if(row.status!=='PENDING')throw apiError(409,'Báo cáo đã được xử lý');
  if(!row.reported_user_id)throw apiError(400,'Báo cáo không gắn với tài khoản cụ thể');
  if(row.target_role==='ADMIN')throw apiError(403,'Không xử lý tài khoản quản trị ở luồng này');
  await notificationsService.createNotification({recipientId:row.reported_user_id,title:'Cảnh cáo từ quản trị viên',message:reason,type:'SYSTEM',data:{reportId:id}},client);
  await adminRepository.resolveReport(id,'RESOLVED',`[Cảnh cáo] ${reason}`,client);
  await notificationsService.createNotification({recipientId:row.reporter_id,title:'Kết quả báo cáo vi phạm',message:'Báo cáo của bạn đã được quản trị viên xử lý.',type:'SYSTEM',data:{reportId:id,status:'RESOLVED'}},client);
  return mapReport(await adminRepository.getReport(id,client));
});

module.exports = {
  getModerationPosts,getModerationPost,moderatePost,warnReportedUser,
  applyCommunityPlan,
  getReports, getReport, resolveReport, listTemplates, getTemplate, createTemplate, updateTemplate, setTemplateStatus, deleteTemplate, applyTemplate, getCommunityPlan, importCommunityTemplate,
  getUsersList,
  updateUserStatus,
  getPendingEkycList,
  approveUserEkyc,
  rejectUserEkyc,
};
