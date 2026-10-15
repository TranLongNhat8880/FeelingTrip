const reviewsService = require('./reviews.service');
const { sendSuccess } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: Reviews, Reports, Blocks
// ============================================================================

/**
 * [POST] /api/v1/reviews/member
 */
const reviewMember = async (req, res, next) => {
    try {
        const result = await reviewsService.reviewMember({
            reviewerId: req.user.id,
            tripId: req.body.tripId,
            revieweeId: req.body.revieweeId,
            rating: req.body.rating,
            comment: req.body.comment,
        });

        return sendSuccess(
            res,
            result,
            'Đánh giá thành viên thành công',
            HTTP_STATUS.CREATED
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/reviews/trip
 */
const reviewTrip = async (req, res, next) => {
    try {
        const result = await reviewsService.reviewTrip({
            reviewerId: req.user.id,
            tripId: req.body.tripId,
            rating: req.body.rating,
            comment: req.body.comment,
        });

        return sendSuccess(
            res,
            result,
            'Đánh giá chuyến đi thành công',
            HTTP_STATUS.CREATED
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/reviews/report
 *
 * Ảnh bằng chứng đã được Cloudinary upload vào req.file.
 */
const createReport = async (req, res, next) => {
    try {
        const result = await reviewsService.createReport({
            reporterId: req.user.id,
            reportedUserId: req.body.reportedUserId,
            reportedTripId: req.body.reportedTripId,
            reason: req.body.reason,
            evidenceImageUrl: req.file?.path,
        });

        return sendSuccess(
            res,
            result,
            'Đã gửi báo cáo vi phạm',
            HTTP_STATUS.CREATED
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/reviews/block
 */
const blockUser = async (req, res, next) => {
    try {
        const result = await reviewsService.blockUser({
            blockerId: req.user.id,
            blockedUserId: req.body.blockedUserId,
        });

        return sendSuccess(
            res,
            result,
            'Đã chặn người dùng',
            HTTP_STATUS.CREATED
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [DELETE] /api/v1/reviews/block/:id
 */
const unblockUser = async (req, res, next) => {
    try {
        const result = await reviewsService.unblockUser({
            blockerId: req.user.id,
            blockedUserId: req.params.id,
        });

        return sendSuccess(
            res,
            result,
            'Đã bỏ chặn người dùng',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [GET] /api/v1/reviews/blocked-users
 */
const getBlockedUsers = async (req, res, next) => {
    try {
        const result = await reviewsService.getBlockedUsers(req.user.id);

        return sendSuccess(
            res,
            result,
            'Lấy danh sách người dùng bị chặn thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

const getTripReviews = async (req, res, next) => {
    try {
        const result = await reviewsService.getTripReviews({
            tripId: req.params.id,
            page: req.query.page,
            limit: req.query.limit,
        });
        return sendSuccess(res, result, 'Đánh giá lịch trình cộng đồng', HTTP_STATUS.OK);
    } catch (error) { next(error); }
};

module.exports = {
    reviewMember,
    reviewTrip,
    getTripReviews,
    createReport,
    blockUser,
    unblockUser,
    getBlockedUsers,
};
