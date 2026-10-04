const reviewsRepository = require('./reviews.repository');
const apiError = require('../../shared/utils/apiError.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// SERVICE: Reviews, Reports, Blocks, Emergency Contacts & SOS
// ============================================================================

const mapReview = (review) => ({
    id: review.id,
    tripId: review.trip_id,
    reviewerId: review.reviewer_id,
    revieweeId: review.reviewee_id,
    rating: review.rating,
    comment: review.comment,
    createdAt: review.created_at,
});

const mapReport = (report) => ({
    id: report.id,
    reporterId: report.reporter_id,
    reportedUserId: report.reported_user_id,
    reportedTripId: report.reported_trip_id,
    reason: report.reason,
    evidenceImageUrl: report.evidence_image_url,
    status: report.status,
    createdAt: report.created_at,
});

const mapEmergencyContact = (contact) => ({
    id: contact.id,
    fullName: contact.full_name,
    phone: contact.phone,
    relationship: contact.relationship,
    createdAt: contact.created_at,
});

const mapSos = (sos) => ({
    id: sos.id,
    userId: sos.user_id,
    tripId: sos.trip_id,
    latitude: sos.latitude,
    longitude: sos.longitude,
    message: sos.message,
    status: sos.status,
    createdAt: sos.created_at,
    resolvedAt: sos.resolved_at,
});

/**
 * Kiểm tra điều kiện chung trước khi tạo đánh giá.
 */
const validateReviewContext = async ({
    tripId,
    reviewerId,
    revieweeId = null,
}) => {
    if (revieweeId !== null && reviewerId === revieweeId) {
        throw apiError(
            HTTP_STATUS.BAD_REQUEST,
            'Bạn không thể tự đánh giá chính mình'
        );
    }

    const trip = await reviewsRepository.findTripContext({
        tripId,
        reviewerId,
        revieweeId,
    });

    if (!trip) {
        throw apiError(HTTP_STATUS.NOT_FOUND, 'Không tìm thấy chuyến đi');
    }

    if (!trip.reviewer_is_member) {
        throw apiError(
            HTTP_STATUS.FORBIDDEN,
            'Bạn không phải thành viên của chuyến đi này'
        );
    }

    if (trip.status !== 'COMPLETED') {
        throw apiError(
            HTTP_STATUS.CONFLICT,
            'Chỉ có thể đánh giá sau khi chuyến đi đã hoàn thành'
        );
    }

    if (revieweeId !== null && !trip.reviewee_is_member) {
        throw apiError(
            HTTP_STATUS.BAD_REQUEST,
            'Người được đánh giá không tham gia chuyến đi này'
        );
    }

    const existingReview = await reviewsRepository.findExistingReview({
        tripId,
        reviewerId,
        revieweeId,
    });

    if (existingReview) {
        throw apiError(
            HTTP_STATUS.CONFLICT,
            revieweeId === null
                ? 'Bạn đã đánh giá chuyến đi này'
                : 'Bạn đã đánh giá thành viên này trong chuyến đi'
        );
    }
};

/**
 * Tạo review và chuyển lỗi unique DB thành lỗi nghiệp vụ rõ ràng.
 */
const createReviewSafely = async ({
    tripId,
    reviewerId,
    revieweeId = null,
    rating,
    comment,
}) => {
    try {
        const review = await reviewsRepository.createReview({
            tripId,
            reviewerId,
            revieweeId,
            rating,
            comment: comment === '' ? null : comment,
        });

        return mapReview(review);
    } catch (error) {
        if (error.code === '23505') {
            throw apiError(
                HTTP_STATUS.CONFLICT,
                revieweeId === null
                    ? 'Bạn đã đánh giá chuyến đi này'
                    : 'Bạn đã đánh giá thành viên này trong chuyến đi'
            );
        }

        throw error;
    }
};

/**
 * Đánh giá một thành viên cùng chuyến đi.
 */
const reviewMember = async ({
    reviewerId,
    tripId,
    revieweeId,
    rating,
    comment,
}) => {
    await validateReviewContext({
        tripId,
        reviewerId,
        revieweeId,
    });

    return createReviewSafely({
        tripId,
        reviewerId,
        revieweeId,
        rating,
        comment,
    });
};

/**
 * Đánh giá trải nghiệm chung của chuyến đi.
 */
const reviewTrip = async ({
    reviewerId,
    tripId,
    rating,
    comment,
}) => {
    await validateReviewContext({
        tripId,
        reviewerId,
        revieweeId: null,
    });

    return createReviewSafely({
        tripId,
        reviewerId,
        revieweeId: null,
        rating,
        comment,
    });
};

/**
 * Gửi báo cáo vi phạm.
 */
const createReport = async ({
    reporterId,
    reportedUserId,
    reportedTripId,
    reason,
    evidenceImageUrl,
}) => {
    if (reportedUserId === reporterId) {
        throw apiError(
            HTTP_STATUS.BAD_REQUEST,
            'Bạn không thể báo cáo chính tài khoản của mình'
        );
    }

    if (reportedUserId) {
        const reportedUser = await reviewsRepository.findUserById(reportedUserId);

        if (!reportedUser) {
            throw apiError(
                HTTP_STATUS.NOT_FOUND,
                'Không tìm thấy người dùng bị báo cáo'
            );
        }
    }

    if (reportedTripId) {
        const reportedTrip = await reviewsRepository.findTripById(reportedTripId);

        if (!reportedTrip) {
            throw apiError(
                HTTP_STATUS.NOT_FOUND,
                'Không tìm thấy chuyến đi bị báo cáo'
            );
        }
    }

    const report = await reviewsRepository.createReport({
        reporterId,
        reportedUserId: reportedUserId || null,
        reportedTripId: reportedTripId || null,
        reason,
        evidenceImageUrl: evidenceImageUrl || null,
    });

    return mapReport(report);
};

/**
 * Chặn người dùng.
 */
const blockUser = async ({ blockerId, blockedUserId }) => {
    if (blockerId === blockedUserId) {
        throw apiError(
            HTTP_STATUS.BAD_REQUEST,
            'Bạn không thể tự chặn chính mình'
        );
    }

    const blockedUser = await reviewsRepository.findUserById(blockedUserId);

    if (!blockedUser) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Không tìm thấy người dùng cần chặn'
        );
    }

    const block = await reviewsRepository.createBlock({
        blockerId,
        blockedId: blockedUserId,
    });

    if (!block) {
        throw apiError(
            HTTP_STATUS.CONFLICT,
            'Người dùng này đã nằm trong danh sách chặn'
        );
    }

    return {
        blockedUserId: block.blocked_id,
        blockedAt: block.created_at,
    };
};

/**
 * Bỏ chặn người dùng.
 */
const unblockUser = async ({ blockerId, blockedUserId }) => {
    const deleted = await reviewsRepository.deleteBlock({
        blockerId,
        blockedId: blockedUserId,
    });

    if (!deleted) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Người dùng không nằm trong danh sách chặn'
        );
    }

    return {
        blockedUserId: deleted.blocked_id,
    };
};

/**
 * Danh sách người dùng đã chặn.
 */
const getBlockedUsers = async (userId) => {
    const users = await reviewsRepository.findBlockedUsers(userId);

    return users.map((user) => ({
        id: user.id,
        fullName: user.full_name,
        nickname: user.nickname,
        avatarUrl: user.avatar_url,
        isVerified: user.is_verified,
        blockedAt: user.blocked_at,
    }));
};

/**
 * Danh sách liên hệ khẩn cấp.
 */
const getEmergencyContacts = async (userId) => {
    const contacts = await reviewsRepository.findEmergencyContacts(userId);
    return contacts.map(mapEmergencyContact);
};

/**
 * Thêm liên hệ khẩn cấp.
 */
const createEmergencyContact = async ({
    userId,
    fullName,
    phone,
    relationship,
}) => {
    const contact = await reviewsRepository.createEmergencyContact({
        userId,
        fullName,
        phone,
        relationship: relationship === '' || relationship === undefined
            ? null
            : relationship,
    });

    return mapEmergencyContact(contact);
};

/**
 * Cập nhật liên hệ khẩn cấp.
 */
const updateEmergencyContact = async ({
    contactId,
    userId,
    contactData,
}) => {
    const normalizedData = { ...contactData };

    if (normalizedData.relationship === '') {
        normalizedData.relationship = null;
    }

    const contact = await reviewsRepository.updateEmergencyContact({
        contactId,
        userId,
        contactData: normalizedData,
    });

    if (!contact) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Không tìm thấy người liên hệ khẩn cấp'
        );
    }

    return mapEmergencyContact(contact);
};

/**
 * Xóa liên hệ khẩn cấp.
 */
const deleteEmergencyContact = async ({ contactId, userId }) => {
    const deleted = await reviewsRepository.deleteEmergencyContact({
        contactId,
        userId,
    });

    if (!deleted) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Không tìm thấy người liên hệ khẩn cấp'
        );
    }

    return {
        id: deleted.id,
    };
};

/**
 * Kích hoạt SOS.
 *
 * Nếu có tripId, người gửi phải tham gia chuyến đi đó.
 */
const createSos = async ({
    userId,
    tripId,
    latitude,
    longitude,
    message,
}) => {
    if (tripId) {
        const trip = await reviewsRepository.findTripContext({
            tripId,
            reviewerId: userId,
            revieweeId: null,
        });

        if (!trip) {
            throw apiError(HTTP_STATUS.NOT_FOUND, 'Không tìm thấy chuyến đi');
        }

        if (!trip.reviewer_is_member) {
            throw apiError(
                HTTP_STATUS.FORBIDDEN,
                'Bạn không phải thành viên của chuyến đi này'
            );
        }
    }

    const sos = await reviewsRepository.createSos({
        userId,
        tripId: tripId || null,
        latitude,
        longitude,
        message: message === '' || message === undefined ? null : message,
    });

    return mapSos(sos);
};

/**
 * Chuyển SOS từ ACTIVE sang RESOLVED hoặc FALSE_ALARM.
 */
const updateSosStatus = async ({ sosId, userId, status }) => {
    const existingSos = await reviewsRepository.findSosByIdForUser({
        sosId,
        userId,
    });

    if (!existingSos) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Không tìm thấy cảnh báo SOS'
        );
    }

    if (existingSos.status !== 'ACTIVE') {
        throw apiError(
            HTTP_STATUS.CONFLICT,
            'Cảnh báo SOS này đã được kết thúc'
        );
    }

    const updatedSos = await reviewsRepository.updateSosStatus({
        sosId,
        userId,
        status,
    });

    if (!updatedSos) {
        throw apiError(
            HTTP_STATUS.CONFLICT,
            'Trạng thái SOS vừa được thay đổi bởi một yêu cầu khác'
        );
    }

    return mapSos(updatedSos);
};

module.exports = {
    reviewMember,
    reviewTrip,
    createReport,
    blockUser,
    unblockUser,
    getBlockedUsers,
    getEmergencyContacts,
    createEmergencyContact,
    updateEmergencyContact,
    deleteEmergencyContact,
    createSos,
    updateSosStatus,
};