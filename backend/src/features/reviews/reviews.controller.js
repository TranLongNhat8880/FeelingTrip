const reviewsService = require('./reviews.service');
const { sendSuccess } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: Reviews, Reports, Blocks, Emergency Contacts & SOS
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

/**
 * [GET] /api/v1/reviews/emergency-contacts
 */
const getEmergencyContacts = async (req, res, next) => {
    try {
        const result = await reviewsService.getEmergencyContacts(req.user.id);

        return sendSuccess(
            res,
            result,
            'Lấy danh sách liên hệ khẩn cấp thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/reviews/emergency-contacts
 */
const createEmergencyContact = async (req, res, next) => {
    try {
        const result = await reviewsService.createEmergencyContact({
            userId: req.user.id,
            fullName: req.body.fullName,
            phone: req.body.phone,
            relationship: req.body.relationship,
        });

        return sendSuccess(
            res,
            result,
            'Thêm người liên hệ khẩn cấp thành công',
            HTTP_STATUS.CREATED
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [PUT] /api/v1/reviews/emergency-contacts/:id
 */
const updateEmergencyContact = async (req, res, next) => {
    try {
        const result = await reviewsService.updateEmergencyContact({
            contactId: req.params.id,
            userId: req.user.id,
            contactData: req.body,
        });

        return sendSuccess(
            res,
            result,
            'Cập nhật người liên hệ khẩn cấp thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [DELETE] /api/v1/reviews/emergency-contacts/:id
 */
const deleteEmergencyContact = async (req, res, next) => {
    try {
        const result = await reviewsService.deleteEmergencyContact({
            contactId: req.params.id,
            userId: req.user.id,
        });

        return sendSuccess(
            res,
            result,
            'Xóa người liên hệ khẩn cấp thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/reviews/sos
 */
const createSos = async (req, res, next) => {
    try {
        const result = await reviewsService.createSos({
            userId: req.user.id,
            tripId: req.body.tripId,
            latitude: req.body.latitude,
            longitude: req.body.longitude,
            message: req.body.message,
        });

        return sendSuccess(
            res,
            result,
            'Đã ghi nhận SOS; người dùng cần chủ động gọi hoặc gửi tin nhắn',
            HTTP_STATUS.CREATED
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [PUT] /api/v1/reviews/sos/:id/status
 */
const updateSosStatus = async (req, res, next) => {
    try {
        const result = await reviewsService.updateSosStatus({
            sosId: req.params.id,
            userId: req.user.id,
            status: req.body.status,
        });

        return sendSuccess(
            res,
            result,
            req.body.status === 'FALSE_ALARM'
                ? 'Đã đánh dấu cảnh báo là báo nhầm'
                : 'Đã xác nhận người dùng an toàn',
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

const getSosHistory = async (req, res, next) => {
    try {
        const result = await reviewsService.getSosHistory({
            userId: req.user.id,
            limit: req.query.limit,
            offset: req.query.offset,
        });
        return sendSuccess(res, result, 'Lịch sử SOS của bạn', HTTP_STATUS.OK);
    } catch (error) { next(error); }
};

const getActiveSos = async (req, res, next) => {
    try {
        const result = await reviewsService.getActiveSos({ userId: req.user.id, tripId: req.query.tripId });
        return sendSuccess(res, result, 'Trạng thái SOS của bạn', HTTP_STATUS.OK);
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
    getEmergencyContacts,
    createEmergencyContact,
    updateEmergencyContact,
    deleteEmergencyContact,
    createSos,
    getActiveSos,
    getSosHistory,
    updateSosStatus,
};
