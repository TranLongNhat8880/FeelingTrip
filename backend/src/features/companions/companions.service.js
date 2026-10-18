const db = require('../../config/database');
const companionsRepository = require('./companions.repository');
const usersRepository = require('../users/users.repository');
const tripRepository = require('../trips/trips.repository');
const notificationsService = require('../notifications/notifications.service');
const apiError = require('../../shared/utils/apiError.util');
const itineraryRepository = require('../itineraries/itineraries.repository');


const isVerifiedUser = (user) => Boolean(
    user && (user.is_verified === true || String(user.verification_status || '').toUpperCase() === 'VERIFIED')
);

const createCompanionPost = async ({
    tripId,
    userId,
    title,
    content,
    targetMembersCount,
    recruitmentCount,
    minAge = null,
    maxAge = null,
    genderPreference = 'ANY',
    tags = []
}) => {
    const user = await usersRepository.findProfileById(userId);
    if (!isVerifiedUser(user)) {
        throw apiError(403, 'Bạn cần xác minh danh tính (eKYC) để đăng bài tuyển bạn đồng hành');
    }

    if (minAge && maxAge && minAge > maxAge) {
        throw apiError(400, 'Độ tuổi tối thiểu không được lớn hơn độ tuổi tối đa');
    }

    return await db.transaction(async (client) => {
        const trip = await companionsRepository.getTripByIdForUpdate(tripId, client);
        if (!trip) {
            throw apiError(404, 'Chuyến đi không tồn tại');
        }

        if (trip.status === 'CANCELLED' || trip.status === 'COMPLETED') {
            throw apiError(400, 'Không thể tạo bài đăng cho chuyến đi đã kết thúc hoặc đã hủy');
        }

        const isLeader = await companionsRepository.isTripLeader(tripId, userId, client);
        if (!isLeader) {
            throw apiError(403, 'Chỉ trưởng nhóm chuyến đi mới có quyền tạo bài tuyển bạn đồng hành');
        }

        if (trip.privacy_type !== 'PUBLIC') {
            throw apiError(400, 'Hãy chuyển chuyến đi sang công khai trước khi đăng tuyển bạn đồng hành');
        }

        const existsPost = await companionsRepository.checkExistsPostByTripId(tripId, client);
        if (existsPost) {
            throw apiError(409, 'Chuyến đi này đã có bài viết đang hoạt động');
        }

        const currentMembersCount = await companionsRepository.getTripMembersCount(tripId, client);
        if (!currentMembersCount || currentMembersCount < 1) {
            throw apiError(400, 'Chuyến đi phải có ít nhất 1 thành viên');
        }

        const effectiveTarget = recruitmentCount !== undefined
            ? currentMembersCount + recruitmentCount
            : targetMembersCount;
        if (!Number.isInteger(effectiveTarget) || effectiveTarget > 50) {
            throw apiError(400, 'Tổng số thành viên không được vượt quá 50 người');
        }
        if (effectiveTarget <= currentMembersCount) {
            throw apiError(400, 'Số lượng thành viên mục tiêu phải lớn hơn số thành viên hiện tại trong đoàn');
        }

        try {
            return await companionsRepository.createCompanionPost({
                tripId,
                creatorId: userId,
                title,
                content,
                targetMembersCount: effectiveTarget,
                currentMembersCount,
                minAge,
                maxAge,
                genderPreference,
                tags,
            }, client);
        } catch (error) {
            if (error.code === '23505') {
                throw apiError(409, 'Chuyến đi này đã có bài viết đang hoạt động');
            }
            throw error;
        }
    });
};

const updateCompanionPost = async ({
    postId,
    newCreatorId,
    userId,
    title,
    content,
    targetMembersCount,
    recruitmentCount,
    minAge,
    maxAge,
    genderPreference,
    tags
}) => {
    const existingPost = await companionsRepository.getCompanionPostById(postId);
    if (!existingPost) {
        throw apiError(404, 'Bài viết không tồn tại');
    }

    return await db.transaction(async (client) => {
        const trip = await companionsRepository.getTripByIdForUpdate(existingPost.trip_id, client);
        if (!trip) {
            throw apiError(404, 'Chuyến đi không tồn tại');
        }

        const post = await companionsRepository.getCompanionPostById(postId, client);
        if (!post) {
            throw apiError(404, 'Bài viết không tồn tại');
        }

        if (post.status === 'CLOSED') {
            throw apiError(400, 'Không thể chỉnh sửa bài viết đã đóng');
        }

        const isLeader = await companionsRepository.isTripLeader(post.trip_id, userId, client);
        if (!isLeader) {
            throw apiError(403, 'Chỉ trưởng nhóm hiện tại của chuyến đi mới có quyền sửa bài viết này');
        }

        const effectiveMinAge = minAge !== undefined ? minAge : post.min_age;
        const effectiveMaxAge = maxAge !== undefined ? maxAge : post.max_age;
        if (effectiveMinAge && effectiveMaxAge && effectiveMinAge > effectiveMaxAge) {
            throw apiError(400, 'Độ tuổi tối thiểu không được lớn hơn độ tuổi tối đa');
        }

        if (newCreatorId) {
            const newCreator = await usersRepository.findProfileById(newCreatorId);
            if (!isVerifiedUser(newCreator)) {
                throw apiError(403, 'Người dùng này không tồn tại hoặc chưa xác minh danh tính');
            }
        }

        const actualMembersCount = await companionsRepository.getTripMembersCount(post.trip_id, client);
        const effectiveTarget = recruitmentCount !== undefined
            ? actualMembersCount + recruitmentCount
            : targetMembersCount !== undefined ? targetMembersCount : post.target_members_count;
        if (!Number.isInteger(effectiveTarget) || effectiveTarget > 50) {
            throw apiError(400, 'Tổng số thành viên không được vượt quá 50 người');
        }
        if (effectiveTarget < actualMembersCount) {
            throw apiError(400, 'Số lượng thành viên mục tiêu không được nhỏ hơn số thành viên hiện có trong đoàn');
        }

        const newStatus = actualMembersCount >= effectiveTarget ? 'FULL' : 'OPEN';

        return await companionsRepository.updateCompanionPost({
            postId,
            newCreatorId,
            title,
            content,
            targetMembersCount: effectiveTarget,
            currentMembersCount: actualMembersCount,
            status: newStatus,
            minAge,
            maxAge,
            genderPreference,
            tags,
        }, client);
    });
};

const deleteCompanionPost = async ({ postId, userId }) => {
    const existingPost = await companionsRepository.getCompanionPostById(postId);
    if (!existingPost) {
        throw apiError(404, 'Bài viết không tồn tại');
    }

    return await db.transaction(async (client) => {
        const trip = await companionsRepository.getTripByIdForUpdate(existingPost.trip_id, client);
        if (!trip) {
            throw apiError(404, 'Chuyến đi không tồn tại');
        }

        const post = await companionsRepository.getCompanionPostById(postId, client);
        if (!post) {
            throw apiError(404, 'Bài viết không tồn tại');
        }

        const isLeader = await companionsRepository.isTripLeader(post.trip_id, userId, client);
        if (!isLeader) {
            throw apiError(403, 'Chỉ trưởng nhóm hiện tại của chuyến đi mới có quyền xóa bài viết này');
        }

        if (post.status === 'CLOSED') {
            throw apiError(400, 'Bài viết này đã được đóng hoặc đã xóa trước đó');
        }

        return await companionsRepository.deleteCompanionPost(postId, client);
    });
};

const getCompanionFeed = async ({
    page = 1,
    limit = 20,
    sortBy = 'newest',
    destination,
    genderPreference,
    minAge,
    maxAge,
    status = 'OPEN',
}) => {
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 20;
    const offset = (pageNum - 1) * limitNum;

    const { rows, total } = await companionsRepository.getCompanionFeed({
        limit: limitNum,
        offset,
        sortBy,
        destination,
        genderPreference,
        minAge: minAge ? parseInt(minAge, 10) : undefined,
        maxAge: maxAge ? parseInt(maxAge, 10) : undefined,
        status,
    });

    const posts = rows.map((row) => ({
        id: row.id,
        title: row.title,
        targetMembersCount: row.target_members_count,
        currentMembersCount: row.current_members_count,
        tags: row.tags || [],
        status: row.status,
        createdAt: row.created_at,
        trip: {
            id: row.trip_id,
            destination: row.trip_destination,
            startDate: row.trip_start_date,
            durationDays: row.trip_duration_days,
            estimatedBudget: row.trip_estimated_budget,
            coverImageUrl: row.trip_cover_image_url,
        },
        creator: {
            id: row.creator_id,
            fullName: row.creator_name,
            avatarUrl: row.creator_avatar_url,
            isVerified: row.creator_is_verified,
            trustScore: row.creator_trust_score,
            reviewCount: row.creator_review_count,
        },
    }));

    const totalPages = Math.ceil(total / limitNum);

    return {
        posts,
        pagination: {
            totalItems: total,
            totalPages,
            currentPage: pageNum,
            limit: limitNum,
        },
    };
};

const getCompanionPostDetail = async ({ postId, userId }) => {
    const post = await companionsRepository.getCompanionPostDetail(postId);
    if (!post) {
        throw apiError(404, 'Bài viết không tồn tại');
    }

    if (post.trip_privacy_type === 'PRIVATE') {
        const isMember = userId
            ? await companionsRepository.isTripMember(post.trip_id, userId)
            : false;
        if (!isMember && post.creator_id !== userId) {
            throw apiError(403, 'Chuyến đi này ở chế độ riêng tư');
        }
    }

    const members = await tripRepository.findSafeMembers(post.trip_id);
    const myRequest = userId ? await companionsRepository.getExistingRequest(postId, userId) : null;
    // Yêu cầu đã duyệt chỉ còn hiệu lực khi người dùng vẫn trong nhóm.
    const canRequestAgain = myRequest?.status === 'ACCEPTED'
        && ['LEFT', 'REMOVED'].includes(myRequest.membership_status);

    // Publish only the schedule advertised by this post, never the internal ledger or notes.
    const days = await itineraryRepository.findDays(db, post.trip_id);
    const items = await itineraryRepository.findItemsForDays(db, days.map(day => day.id));

    return {
        id: post.id,
        title: post.title,
        content: post.content,
        myRequestStatus: canRequestAgain ? null : myRequest?.status || null,
        myRequestId: canRequestAgain ? null : myRequest?.id || null,
        targetMembersCount: post.target_members_count,
        currentMembersCount: post.current_members_count,
        minAge: post.min_age,
        maxAge: post.max_age,
        genderPreference: post.gender_preference,
        tags: post.tags || [],
        status: post.status,
        createdAt: post.created_at,
        updatedAt: post.updated_at,
        trip: {
            id: post.trip_id,
            name: post.trip_name,
            destination: post.trip_destination,
            startDate: post.trip_start_date,
            endDate: post.trip_end_date,
            durationDays: post.trip_duration_days,
            estimatedBudget: post.trip_estimated_budget,
            coverImageUrl: post.trip_cover_image_url,
            status: post.trip_status,
            itinerary: days.map(day => ({
                dayNumber: day.day_number,
                title: day.title,
                tripDate: day.trip_date,
                items: items.filter(item => item.itinerary_id === day.id).map(item => ({
                    customName: item.custom_name,
                    customAddress: item.custom_address || null,
                    category: item.category,
                    startTime: item.start_time?.slice(0,5),
                    endTime: item.end_time?.slice(0,5),
                    estimatedCost: Number(item.estimated_cost || 0),
                })),
            })),
            members: (members || []).map((m) => ({
                userId: m.user_id,
                displayName: m.display_name,
                avatarUrl: m.avatar_url,
                role: m.role,
                joinedAt: m.joined_at,
            })),
        },
        creator: {
            id: post.creator_id,
            fullName: post.creator_name,
            nickname: post.creator_nickname,
            avatarUrl: post.creator_avatar_url,
            isVerified: post.creator_is_verified,
            trustScore: post.creator_trust_score,
            reviewCount: post.creator_review_count,
        },
    };
};

const createJoinRequest = async ({ postId, userId, introduction }) => {
    const user = await usersRepository.findProfileById(userId);
    if (!isVerifiedUser(user)) {
        throw apiError(403, 'Bạn cần xác minh danh tính (eKYC) để gửi yêu cầu tham gia');
    }

    return db.transaction(async (client) => {
        let post = await companionsRepository.getCompanionPostById(postId, client);
        if (!post) {
            throw apiError(404, 'Bài viết không tồn tại');
        }

        const trip = await companionsRepository.getTripByIdForUpdate(post.trip_id, client);
        if (!trip || trip.status === 'CANCELLED' || trip.status === 'COMPLETED') {
            throw apiError(400, 'Không thể gửi yêu cầu cho chuyến đi đã kết thúc hoặc đã hủy');
        }

        if (trip.privacy_type === 'PRIVATE') {
            throw apiError(400, 'Không thể gửi yêu cầu tham gia chuyến đi riêng tư');
        }

        // Đọc lại sau khi khóa chuyến để lấy sức chứa và trạng thái mới nhất.
        post = await companionsRepository.getCompanionPostById(postId, client);
        if (post.status === 'CLOSED') {
            throw apiError(400, 'Bài viết đã đóng, không nhận thêm yêu cầu');
        }
        if (post.status === 'FULL') {
            throw apiError(400, 'Đoàn đã đủ số lượng thành viên, không nhận thêm yêu cầu');
        }

        const isLeader = await companionsRepository.isTripLeader(post.trip_id, userId, client);
        if (isLeader || post.creator_id === userId) {
            throw apiError(400, 'Bạn là người quản lý chuyến đi này, không thể gửi yêu cầu tham gia');
        }

        const isMember = await companionsRepository.isTripMember(post.trip_id, userId, client);
        if (isMember) {
            throw apiError(400, 'Bạn đã là thành viên của chuyến đi này');
        }

        const existing = await companionsRepository.getExistingRequest(postId, userId, client);
        if (existing?.status === 'PENDING') {
            throw apiError(409, 'Bạn đã gửi yêu cầu tham gia bài viết này rồi, vui lòng chờ duyệt');
        }
        if (existing?.status === 'REJECTED') {
            throw apiError(400, 'Yêu cầu tham gia bài viết này của bạn đã bị từ chối');
        }
        if (existing?.status === 'ACCEPTED' && !['LEFT', 'REMOVED'].includes(existing.membership_status)) {
            throw apiError(400, 'Yêu cầu của bạn đã được chấp thuận trước đó');
        }

        const leader = await companionsRepository.getTripLeader(post.trip_id, client);
        if (!leader) {
            throw apiError(400, 'Chuyến đi không có trưởng nhóm đang hoạt động');
        }

        let newRequest;
        try {
            if (existing) {
                newRequest = await companionsRepository.resendJoinRequest(existing.id, introduction, client);
            } else {
                newRequest = await companionsRepository.createJoinRequest({
                    postId,
                    userId,
                    introduction,
                }, client);
            }
        } catch (error) {
            if (error.code === '23505') {
                throw apiError(409, 'Bạn đã gửi yêu cầu tham gia bài viết này rồi');
            }
            throw error;
        }
        if (!newRequest) {
            throw apiError(409, 'Yêu cầu đã thay đổi, vui lòng tải lại bài viết');
        }

        await notificationsService.createNotification({
            recipientId: leader.user_id,
            title: 'Yêu cầu tham gia mới',
            message: `${user?.full_name || 'Một thành viên'} đã gửi yêu cầu tham gia bài viết "${post.title}"`,
            type: 'REQUEST',
            data: { postId: post.id, requestId: newRequest.id, tripId: post.trip_id }
        }, client);

        return newRequest;
    });
};

const deleteJoinRequest = async ({ requestId, userId }) => {
    const req = await companionsRepository.getJoinRequestById(requestId);
    if (!req) {
        throw apiError(404, 'Yêu cầu tham gia không tồn tại');
    }

    if (req.user_id !== userId) {
        throw apiError(403, 'Bạn không có quyền hủy yêu cầu này');
    }

    if (req.status !== 'PENDING') {
        throw apiError(400, `Không thể hủy yêu cầu đã được xử lý (trạng thái hiện tại: ${req.status})`);
    }

    const deleted = await companionsRepository.deleteJoinRequest(requestId);
    if (!deleted) {
        throw apiError(409, 'Yêu cầu này đã được xử lý, không thể hủy');
    }

    return {
        message: 'Hủy yêu cầu tham gia thành công',
        requestId,
    };
};

const reviewJoinRequest = async ({ requestId, leaderId, status }) => {
    return await db.transaction(async (client) => {
        const req = await companionsRepository.getJoinRequestById(requestId, client, true);
        if (!req) {
            throw apiError(404, 'Yêu cầu tham gia không tồn tại');
        }

        const isLeader = await companionsRepository.isTripLeader(req.trip_id, leaderId, client);
        if (!isLeader) {
            throw apiError(403, 'Chỉ trưởng nhóm chuyến đi mới có quyền xét duyệt yêu cầu này');
        }

        if (req.status !== 'PENDING') {
            throw apiError(400, `Yêu cầu này đã được xử lý trước đó (trạng thái hiện tại: ${req.status})`);
        }

        if (status === 'REJECTED') {
            const updated = await companionsRepository.updateJoinRequestStatus(requestId, 'REJECTED', client);
            if (!updated) {
                throw apiError(409, 'Yêu cầu này đã được xử lý trước đó');
            }
            await notificationsService.createNotification({
                recipientId: req.user_id,
                title: 'Yêu cầu tham gia bị từ chối',
                message: `Yêu cầu tham gia chuyến đi "${req.trip_name}" của bạn đã bị từ chối`,
                type: 'REQUEST',
                data: { postId: req.post_id, tripId: req.trip_id }
            }, client).catch(() => {});
            return updated;
        }

        if (status === 'ACCEPTED') {
            const leaderUser = await usersRepository.findProfileById(leaderId);
            if (!isVerifiedUser(leaderUser)) {
                throw apiError(403, 'Trưởng nhóm cần hoàn thành xác minh danh tính (eKYC) để xét duyệt thành viên');
            }

            const { rows: [requester] } = await client.query(
                "SELECT is_verified, verification_status, status FROM users WHERE id = $1", [req.user_id]);
            if (!isVerifiedUser(requester)) {
                throw apiError(403, 'Người gửi yêu cầu chưa hoàn thành xác minh danh tính (eKYC)');
            }
            if (requester.status !== 'ACTIVE') {
                throw apiError(403, 'Tài khoản người gửi yêu cầu không ở trạng thái hoạt động');
            }

            const trip = await companionsRepository.getTripByIdForUpdate(req.trip_id, client);
            if (!trip) {
                throw apiError(404, 'Chuyến đi không tồn tại');
            }
            if (trip.status === 'CANCELLED' || trip.status === 'COMPLETED') {
                throw apiError(400, 'Không thể duyệt thành viên cho chuyến đi đã kết thúc hoặc đã hủy');
            }
            const post = await companionsRepository.getCompanionPostById(req.post_id, client);
            if (post.status === 'CLOSED') {
                throw apiError(400, 'Không thể duyệt yêu cầu của bài viết đã đóng');
            }

            const isMember = await companionsRepository.isTripMember(req.trip_id, req.user_id, client);
            if (isMember) {
                throw apiError(400, 'Người gửi yêu cầu đã là thành viên của chuyến đi này');
            }

            const actualMembersCount = await companionsRepository.getTripMembersCount(req.trip_id, client);
            if (actualMembersCount >= post.target_members_count) {
                throw apiError(400, 'Đoàn đã đủ số lượng thành viên tối đa, không thể nhận thêm');
            }

            const updated = await companionsRepository.updateJoinRequestStatus(requestId, 'ACCEPTED', client);
            if (!updated) {
                throw apiError(409, 'Yêu cầu này đã được xử lý trước đó');
            }

            const member = await companionsRepository.addTripMember(req.trip_id, req.user_id, 'MEMBER', client);
            if (!member) {
                throw apiError(409, 'Người gửi yêu cầu đã là thành viên của chuyến đi này');
            }

            const newMembersCount = actualMembersCount + 1;
            const newPostStatus = newMembersCount >= post.target_members_count ? 'FULL' : 'OPEN';
            await companionsRepository.updateCompanionPost({
                postId: req.post_id,
                currentMembersCount: newMembersCount,
                status: newPostStatus,
            }, client);

            await notificationsService.createNotification({
                recipientId: req.user_id,
                title: 'Yêu cầu tham gia được chấp thuận',
                message: `Chúc mừng! Bạn đã được chấp thuận tham gia chuyến đi "${req.trip_name}"`,
                type: 'REQUEST',
                data: { postId: req.post_id, tripId: req.trip_id }
            }, client).catch(() => {});

            return updated;
        }
    });
};

const getMyReceivedRequests = async ({ userId, page = 1, limit = 20, status, postId }) => {
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 20;
    const offset = (pageNum - 1) * limitNum;

    const { rows, total } = await companionsRepository.getMyReceivedRequests({
        userId,
        limit: limitNum,
        offset,
        status,
        postId,
    });

    const requests = rows.map((row) => ({
        id: row.id,
        postId: row.post_id,
        introduction: row.introduction,
        status: row.status,
        createdAt: row.created_at,
        post: {
            title: row.post_title,
            targetMembersCount: row.target_members_count,
            currentMembersCount: row.current_members_count,
            status: row.post_status,
        },
        trip: {
            id: row.trip_id,
            name: row.trip_name,
            destination: row.trip_destination,
            startDate: row.trip_start_date,
            endDate: row.trip_end_date,
        },
        requester: {
            id: row.requester_id,
            fullName: row.requester_name,
            nickname: row.requester_nickname,
            avatarUrl: row.requester_avatar_url,
            phone: row.requester_phone,
            isVerified: row.requester_is_verified,
            trustScore: row.requester_trust_score,
            reviewCount: row.requester_review_count,
        },
    }));

    const totalPages = Math.ceil(total / limitNum);

    return {
        requests,
        pagination: {
            totalItems: total,
            totalPages,
            currentPage: pageNum,
            limit: limitNum,
        },
    };
};

const getPostedTripIds = async (userId) => {
    return companionsRepository.getPostedTripIds(userId);
};

// Yêu cầu đã gửi: trả về bài đăng, chuyến đi và trạng thái hiện tại
const getMySentRequests = async ({ userId, page = 1, limit = 20, status }) => {
    const offset = (page - 1) * limit;
    const { rows, total } = await companionsRepository.getMySentRequests({
        userId,
        status,
        limit,
        offset,
    });

    const requests = rows.map((row) => ({
        id: row.id,
        postId: row.post_id,
        title: row.title,
        tripName: row.trip_name,
        destination: row.destination,
        postStatus: row.post_status,
        status: row.status,
        introduction: row.introduction,
        createdAt: row.created_at,
    }));

    const totalPages = Math.ceil(total / limit);
    return {
        requests,
        pagination: {
            totalItems: total,
            totalPages,
            currentPage: page,
            limit,
        },
    };
};

const getPublicPostsByUser = async ({ userId, page = 1, limit = 20 }) => {
    const user = await usersRepository.findTrustScoreByUserId(userId);
    if (!user) {
        throw apiError(404, 'Không tìm thấy người dùng');
    }

    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 20;
    const { rows, total } = await companionsRepository.getPublicPostsByUser({
        userId,
        limit: limitNum,
        offset: (pageNum - 1) * limitNum,
    });

    return {
        posts: rows,
        pagination: {
            totalItems: total,
            totalPages: Math.ceil(total / limitNum),
            currentPage: pageNum,
            limit: limitNum,
        },
    };
};

const getMyPosts = (userId, page, limit) => {
    return companionsRepository.getMyPosts(userId, page, limit);
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
    getMyReceivedRequests
};
