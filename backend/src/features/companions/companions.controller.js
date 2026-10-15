const companionsService = require('./companions.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

const createCompanionPost = async (req, res, next) => {
  try {
    const { tripId, title, content, targetMembersCount, minAge, maxAge, genderPreference, tags } = req.body;
    const userId = req.user.id;
    const newCompanionPost = await companionsService.createCompanionPost({
        tripId,
        userId,
        title,
        content,
        targetMembersCount,
        minAge,
        maxAge,
        genderPreference,
        tags
    });
    return sendSuccess(res, newCompanionPost, 'Tạo bài thành công', HTTP_STATUS.CREATED);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const updateCompanionPost = async (req, res, next) => {
  try {
    const {postId} = req.params;
    const userId = req.user.id;
    const {newCreatorId, title, content, targetMembersCount, minAge, maxAge, genderPreference, tags } = req.body;

    const updatedCompanionPost = await companionsService.updateCompanionPost({
        postId,
        newCreatorId,
        userId,
        title,
        content,
        targetMembersCount,
        minAge,
        maxAge,
        genderPreference,
        tags
    });
    return sendSuccess(res, updatedCompanionPost, 'Cập nhật bài thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const deleteCompanionPost = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const userId = req.user.id;
    const deletedPost = await companionsService.deleteCompanionPost({ postId, userId });
    return sendSuccess(res, deletedPost, 'Xóa bài đăng thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const getCompanionFeed = async (req, res, next) => {
  try {
    const result = await companionsService.getCompanionFeed(req.query);
    return sendSuccess(res, result, 'Lấy bảng tin tìm bạn đồng hành thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const getCompanionPostDetail = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const post = await companionsService.getCompanionPostDetail({ postId, userId: req.user.id });
    return sendSuccess(res, post, 'Lấy chi tiết bài đăng thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const createJoinRequest = async (req, res, next) => {
  try {
    const { postId, introduction } = req.body;
    const userId = req.user.id;
    const newRequest = await companionsService.createJoinRequest({ postId, userId, introduction });
    return sendSuccess(res, newRequest, 'Gửi yêu cầu tham gia thành công', HTTP_STATUS.CREATED);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const deleteJoinRequest = async (req, res, next) => {
  try {
    const { requestId } = req.params;
    const userId = req.user.id;
    const result = await companionsService.deleteJoinRequest({ requestId, userId });
    return sendSuccess(res, result, 'Hủy yêu cầu tham gia thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const reviewJoinRequest = async (req, res, next) => {
  try {
    const { requestId } = req.params;
    const leaderId = req.user.id;
    const { status } = req.body;
    const result = await companionsService.reviewJoinRequest({ requestId, leaderId, status });
    const message = status === 'ACCEPTED' ? 'Chấp thuận yêu cầu tham gia thành công' : 'Từ chối yêu cầu tham gia thành công';
    return sendSuccess(res, result, message, HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const getMyReceivedRequests = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { page, limit, status, postId } = req.query;
    const data = await companionsService.getMyReceivedRequests({ userId, page, limit, status, postId });
    return sendSuccess(res, data, 'Lấy danh sách yêu cầu tham gia thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

const getPostedTripIds = async (req, res, next) => {
  try {
    const tripIds = await companionsService.getPostedTripIds(req.user.id);
    return sendSuccess(res, tripIds, 'Lấy các chuyến đi đã đăng bài', HTTP_STATUS.OK);
  } catch (error) {
    next(error);
  }
};

const getMySentRequests = async (req, res, next) => {
  try {
    const result = await companionsService.getMySentRequests({
      ...req.query,
      userId: req.user.id,
    });
    return sendSuccess(res, result, 'Lấy yêu cầu đã gửi', HTTP_STATUS.OK);
  } catch (error) {
    next(error);
  }
};

const getPublicPostsByUser = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { page, limit } = req.query;
    const result = await companionsService.getPublicPostsByUser({ userId, page, limit });
    return sendSuccess(res, result, 'Bài viết công khai của người dùng', HTTP_STATUS.OK);
  } catch (error) {
    next(error);
  }
};

const getMyPosts = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { page, limit } = req.query;
    const result = await companionsService.getMyPosts(userId, page, limit);
    return sendSuccess(res, result, 'Bài tuyển của tôi', HTTP_STATUS.OK);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getPublicPostsByUser,
  getMyPosts,
  getMySentRequests,
  getPostedTripIds,
  createCompanionPost,
  updateCompanionPost,
  deleteCompanionPost,
  getCompanionFeed,
  getCompanionPostDetail,
  createJoinRequest,
  deleteJoinRequest,
  reviewJoinRequest,
  getMyReceivedRequests,
};
