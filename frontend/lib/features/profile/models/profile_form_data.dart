// ============================================================================
// MODEL: Dữ liệu biểu mẫu cập nhật hồ sơ cá nhân
// Dùng cho PUT /api/v1/users/profile bằng multipart/form-data.
// ============================================================================

class ProfileFormData {
  const ProfileFormData({
    required this.fullName,
    required this.nickname,
    required this.phone,
    required this.bio,
    required this.gender,
    required this.dob,
  });

  final String fullName;
  final String? nickname;
  final String? phone;
  final String? bio;
  final String? gender;
  final DateTime? dob;

  /// Gửi chuỗi rỗng để backend xóa các trường không bắt buộc.
  Map<String, String> toMultipartFields() {
    return {
      'fullName': fullName.trim(),
      'nickname': nickname?.trim() ?? '',
      'phone': phone?.trim() ?? '',
      'bio': bio?.trim() ?? '',
      'gender': gender?.trim() ?? '',
      'dob': dob == null ? '' : _formatDate(dob!),
    };
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
