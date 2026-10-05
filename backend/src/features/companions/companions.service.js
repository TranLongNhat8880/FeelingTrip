const db = require('../../config/database');
const companionsRepository = require('./companions.repository');
const usersRepository = require('../users/users.repository');
const tripRepository = require('../trips/trips.repository');
const apiError = require('../../shared/utils/apiError.util');


const createCompanionPost = async ({
    tripId,
    userId,
    title,
    content,
    targetMembersCount,
    minAge = null,
    maxAge = null,
    genderPreference = 'ANY',
    tags = []
}) => {
    const user = await usersRepository.findProfileById(userId);
    if (!user || !user.is_verified) {
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

        const existsPost = await companionsRepository.checkExistsPostByTripId(tripId, client);
        if (existsPost) {
            throw apiError(409, 'Chuyến đi này đã có bài viết đang hoạt động');
        }

        const currentMembersCount = await companionsRepository.getTripMembersCount(tripId, client);
        if (!currentMembersCount || currentMembersCount < 1) {
            throw apiError(400, 'Chuyến đi phải có ít nhất 1 thành viên');
        }

        if (targetMembersCount <= currentMembersCount) {
            throw apiError(400, 'Số lượng thành viên mục tiêu phải lớn hơn số thành viên hiện tại trong đoàn');
        }

        try {
            return await companionsRepository.createCompanionPost({
                tripId,
                creatorId: userId,
                title,
                content,
                targetMembersCount,
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
    minAge,
    maxAge,
    genderPreference,
    tags
}) => {
    const post = await companionsRepository.getCompanionPostById(postId);
    if (!post) {
        throw apiError(404, 'Bài viết không tồn tại');
    }

    if (post.status === 'CLOSED') {
        throw apiError(400, 'Không thể chỉnh sửa bài viết đã đóng');
    }

    const isLeader = await companionsRepository.isTripLeader(post.trip_id, userId);
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
        if (!newCreator || !newCreator.is_verified) {
            throw apiError(403, 'Người dùng này không tồn tại hoặc chưa xác minh danh tính');
        }
    }

    const actualMembersCount = await companionsRepository.getTripMembersCount(post.trip_id);
    const effectiveTarget = targetMembersCount !== undefined ? targetMembersCount : post.target_members_count;
    if (effectiveTarget < actualMembersCount) {
        throw apiError(400, 'Số lượng thành viên mục tiêu không được nhỏ hơn số thành viên hiện có trong đoàn');
    }

    const newStatus = actualMembersCount >= effectiveTarget ? 'FULL' : 'OPEN';

    return await companionsRepository.updateCompanionPost({
        postId,
        newCreatorId,
        title,
        content,
        targetMembersCount,
        currentMembersCount: actualMembersCount,
        status: newStatus,
        minAge,
        maxAge,
        genderPreference,
        tags,
    });
};

const deleteCompanionPost = async ({ postId, userId }) => {
    const post = await companionsRepository.getCompanionPostById(postId);
    if (!post) {
        throw apiError(404, 'Bài viết không tồn tại');
    }

    const isLeader = await companionsRepository.isTripLeader(post.trip_id, userId);
    if (!isLeader) {
        throw apiError(403, 'Chỉ trưởng nhóm hiện tại của chuyến đi mới có quyền xóa bài viết này');
    }

    if (post.status === 'CLOSED') {
        throw apiError(400, 'Bài viết này đã được đóng hoặc đã xóa trước đó');
    }

    return await companionsRepository.deleteCompanionPost(postId);
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

const getCompanionPostDetail = async ({ postId }) => {
    const post = await companionsRepository.getCompanionPostDetail(postId);
    if (!post) {
        throw apiError(404, 'Bài viết không tồn tại');
    }

    const members = await tripRepository.findSafeMembers(post.trip_id);

    return {
        id: post.id,
        title: post.title,
        content: post.content,
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

module.exports = {
    createCompanionPost,
    updateCompanionPost,
    deleteCompanionPost,
    getCompanionFeed,
    getCompanionPostDetail
};
