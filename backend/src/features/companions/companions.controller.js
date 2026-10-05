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
    const post = await companionsService.getCompanionPostDetail({ postId });
    return sendSuccess(res, post, 'Lấy chi tiết bài đăng thành công', HTTP_STATUS.OK);
  } catch (error) {
    console.log(error);
    next(error);
  }
};

module.exports = {
  createCompanionPost,
  updateCompanionPost,
  deleteCompanionPost,
  getCompanionFeed,
  getCompanionPostDetail
};
