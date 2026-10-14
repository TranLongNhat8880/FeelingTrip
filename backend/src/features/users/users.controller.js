const usersService = require('./users.service');
const { sendSuccess } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: User Profile & eKYC
// Tiếp nhận request, gọi service và trả response.
// ============================================================================

/**
 * [GET] /api/v1/users/profile
 * Lấy hồ sơ của người dùng đang đăng nhập.
 */
const getProfile = async (req, res, next) => {
    try {
        const profile = await usersService.getProfile(req.user.id);

        return sendSuccess(
            res,
            profile,
            'Lấy thông tin hồ sơ thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [PUT] /api/v1/users/profile
 * Cập nhật thông tin cá nhân và/hoặc ảnh đại diện.
 *
 * Nếu request có multipart field "avatar", middleware Cloudinary sẽ
 * đặt thông tin ảnh đã upload vào req.file.
 */
const updateProfile = async (req, res, next) => {
    try {
        const profile = await usersService.updateProfile({
            userId: req.user.id,
            profileData: req.body,
            avatarUrl: req.file?.path,
        });

        return sendSuccess(
            res,
            profile,
            'Cập nhật hồ sơ thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/users/ekyc-verify
 * Nộp hoặc nộp lại hồ sơ xác minh CCCD.
 *
 * Các multipart field ảnh:
 * - cccdFrontImage
 * - cccdBackImage
 * - selfieImage
 */
const submitEkyc = async (req, res, next) => {
    try {
        const cccdFrontImage = req.files?.cccdFrontImage?.[0]?.path;
        const cccdBackImage = req.files?.cccdBackImage?.[0]?.path;
        const selfieImage = req.files?.selfieImage?.[0]?.path;

        const result = await usersService.submitEkyc({
            userId: req.user.id,
            cccdNumber: req.body.cccdNumber,
            cccdFrontImage,
            cccdBackImage,
            selfieImage,
        });

        return sendSuccess(
            res,
            result,
            'Đã gửi hồ sơ eKYC, vui lòng chờ Admin xét duyệt',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [GET] /api/v1/users/trust-score/:id
 * Xem điểm tín nhiệm công khai của một người dùng.
 */
const getTrustScore = async (req, res, next) => {
    try {
        const trustProfile = await usersService.getTrustScore(req.params.id);

        return sendSuccess(
            res,
            trustProfile,
            'Lấy điểm tín nhiệm thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

module.exports = {
    getProfile,
    updateProfile,
    submitEkyc,
    getTrustScore,
};
