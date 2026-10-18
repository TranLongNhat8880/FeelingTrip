const reviewsRepository = require('./reviews.repository');
const apiError = require('../../shared/utils/apiError.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// SERVICE: Reviews, Reports, Blocks
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
 * Gửi báo cáo vi phạm, không yêu cầu chuyến đi COMPLETED.
 * Có tripId: kiểm tra quyền theo bối cảnh chuyến đi tại BE, không tin UI.
 * Không có tripId: giữ luồng báo cáo tài khoản độc lập hiện có.
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
        const reportedTrip = await reviewsRepository.findReportTripContext({
            tripId: reportedTripId,
            reporterId,
            reportedUserId: reportedUserId || null,
        });

        if (!reportedTrip) {
            throw apiError(
                HTTP_STATUS.NOT_FOUND,
                'Không tìm thấy chuyến đi bị báo cáo'
            );
        }

        if (reportedUserId) {
            // A public trip/post grants the right to report its content, not
            // the right to submit a member-specific accusation in that trip.
            if (reportedTrip.reporter_was_member !== true) {
                throw apiError(HTTP_STATUS.FORBIDDEN,
                    'Bạn phải đang hoặc từng tham gia chuyến đi để báo cáo thành viên trong chuyến');
            }
            if (reportedTrip.reported_user_was_member !== true) {
                throw apiError(HTTP_STATUS.BAD_REQUEST,
                    'Người bị báo cáo không phải người đang hoặc từng tham gia chuyến đi này');
            }
        } else if (reportedTrip.reporter_was_member !== true &&
            reportedTrip.is_publicly_reportable !== true) {
            throw apiError(HTTP_STATUS.FORBIDDEN,
                'Chỉ người đang hoặc từng tham gia mới được báo cáo chuyến đi riêng tư chưa có bài tuyển công khai');
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

const getTripReviews = async ({ tripId, page = 1, limit = 20 }) => {
    const result = await reviewsRepository.findPublicTripReviews({ tripId, page, limit });
    if (!result) {
        throw apiError(HTTP_STATUS.NOT_FOUND, 'Không tìm thấy lịch trình công khai đã hoàn thành');
    }
    const total = Number(result.review_count);
    return {
        tripId: result.trip_id,
        averageRating: Number(result.average_rating),
        reviewCount: total,
        items: result.items.map(review => ({
            id: review.id,
            tripId: result.trip_id,
            rating: review.rating,
            comment: review.comment,
            createdAt: review.created_at,
            reviewer: {
                id: review.reviewer.id,
                displayName: review.reviewer.displayName,
                avatarUrl: review.reviewer.avatarUrl,
            },
        })),
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
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
