const usersRepository = require('./users.repository');
const apiError = require('../../shared/utils/apiError.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// SERVICE: User Profile & eKYC
// Xử lý nghiệp vụ và chuyển dữ liệu DB snake_case thành API camelCase.
// ============================================================================

/**
 * Chuyển hồ sơ lấy từ DB thành dữ liệu trả cho chính chủ tài khoản.
 *
 * Không trả ảnh CCCD, số CCCD đầy đủ hoặc dữ liệu bảo mật.
 */
const mapProfile = (user) => ({
  id: user.id,
  email: user.email,
  fullName: user.full_name,
  nickname: user.nickname,
  phone: user.phone,
  avatarUrl: user.avatar_url,
  bio: user.bio,
  gender: user.gender,
  dob: user.dob,
  role: user.role,

  isEmailVerified: user.is_email_verified,
  isVerified: user.is_verified,
  verificationStatus: user.verification_status,
  verificationRejectionReason: user.verification_rejection_reason,
  hasEkycDocuments: user.has_ekyc_documents,

  bankBin: user.bank_bin,
  bankName: user.bank_name,
  bankAccountNumber: user.bank_account_number,
  bankAccountName: user.bank_account_name,

  createdAt: user.created_at,
  updatedAt: user.updated_at,
});

/**
 * Lấy hồ sơ của người dùng đang đăng nhập.
 */
const getProfile = async (userId) => {
  const user = await usersRepository.findProfileById(userId);

  if (!user) {
    throw apiError(HTTP_STATUS.NOT_FOUND, 'Không tìm thấy hồ sơ người dùng');
  }

  return mapProfile(user);
};

/**
 * Cập nhật hồ sơ cá nhân.
 *
 * profileData đã được Joi lọc trước khi vào service.
 * avatarUrl chỉ được lấy từ kết quả upload Cloudinary, không lấy từ req.body.
 */
const updateProfile = async ({ userId, profileData, avatarUrl }) => {
  const updateData = { ...profileData };

  // Chuẩn hóa chuỗi rỗng thành NULL để dữ liệu DB nhất quán.
  for (const field of ['nickname', 'phone', 'bio', 'gender', 'dob']) {
    if (updateData[field] === '') {
      updateData[field] = null;
    }
  }

  if (avatarUrl !== undefined) {
    updateData.avatarUrl = avatarUrl;
  }

  const hasUpdate = Object.values(updateData).some(
    (value) => value !== undefined
  );

  if (!hasUpdate) {
    throw apiError(
      HTTP_STATUS.BAD_REQUEST,
      'Vui lòng cung cấp ít nhất một thông tin hoặc ảnh đại diện cần cập nhật'
    );
  }

  const updatedUser = await usersRepository.updateProfile(userId, updateData);

  if (!updatedUser) {
    throw apiError(HTTP_STATUS.NOT_FOUND, 'Không tìm thấy hồ sơ người dùng');
  }

  return mapProfile(updatedUser);
};

/**
 * Nộp hoặc nộp lại hồ sơ eKYC.
 *
 * Ba URL ảnh phải đến từ Cloudinary sau khi middleware upload hoàn tất.
 * Repository đảm bảo chỉ UNVERIFIED/REJECTED mới chuyển được sang PENDING.
 */
const submitEkyc = async ({
  userId,
  cccdNumber,
  cccdFrontImage,
  cccdBackImage,
  selfieImage,
}) => {
  const imageUrls = {
    cccdFrontImage,
    cccdBackImage,
    selfieImage,
  };

  const missingImages = Object.entries(imageUrls)
    .filter(([, url]) => typeof url !== 'string' || url.length === 0)
    .map(([field]) => field);

  if (missingImages.length > 0) {
    throw apiError(
      HTTP_STATUS.BAD_REQUEST,
      `Thiếu ảnh eKYC bắt buộc: ${missingImages.join(', ')}`
    );
  }

  const result = await usersRepository.submitEkyc({
    userId,
    cccdNumber,
    cccdFrontImage,
    cccdBackImage,
    selfieImage,
  });

  if (!result) {
    const currentProfile = await usersRepository.findProfileById(userId);

    if (!currentProfile) {
      throw apiError(HTTP_STATUS.NOT_FOUND, 'Không tìm thấy hồ sơ người dùng');
    }

    if (currentProfile.verification_status === 'PENDING') {
      throw apiError(
        HTTP_STATUS.CONFLICT,
        'Hồ sơ eKYC đang chờ Admin xét duyệt'
      );
    }

    if (currentProfile.verification_status === 'VERIFIED') {
      throw apiError(
        HTTP_STATUS.CONFLICT,
        'Tài khoản đã được xác minh eKYC'
      );
    }

    throw apiError(
      HTTP_STATUS.CONFLICT,
      'Trạng thái hiện tại không cho phép nộp hồ sơ eKYC'
    );
  }

  return {
    verificationStatus: result.verification_status,
    verificationRejectionReason: result.verification_rejection_reason,
    isVerified: result.is_verified,
    submittedAt: result.updated_at,
  };
};

/**
 * Lấy hồ sơ tín nhiệm công khai.
 */
const getTrustScore = async (userId) => {
  const user = await usersRepository.findTrustScoreByUserId(userId);

  if (!user) {
    throw apiError(
      HTTP_STATUS.NOT_FOUND,
      'Không tìm thấy người dùng hoặc tài khoản không còn hoạt động'
    );
  }

  return {
    id: user.id,
    fullName: user.full_name,
    nickname: user.nickname,
    avatarUrl: user.avatar_url,
    bio: user.bio,
    isVerified: user.is_verified,
    trustScore: user.trust_score,
    reviewCount: user.review_count,
    memberSince: user.created_at,
  };
};

module.exports = {
  getProfile,
  updateProfile,
  submitEkyc,
  getTrustScore,
};
