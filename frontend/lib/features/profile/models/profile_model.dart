// ============================================================================
// MODEL: Hồ sơ cá nhân của người dùng hiện tại
// Dữ liệu nhận từ GET /api/v1/users/profile.
// ============================================================================

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.email,
    required this.role,
    required this.isEmailVerified,
    required this.isVerified,
    required this.verificationStatus,
    required this.hasEkycDocuments,
    this.fullName,
    this.nickname,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.gender,
    this.dob,
    this.verificationRejectionReason,
    this.bankBin,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? nickname;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String? gender;
  final DateTime? dob;
  final String role;

  final bool isEmailVerified;
  final bool isVerified;
  final String verificationStatus;
  final String? verificationRejectionReason;
  final bool hasEkycDocuments;

  final String? bankBin;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final name = fullName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return email;
  }

  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  bool get isEkycVerified =>
      isVerified || verificationStatus.toUpperCase() == 'VERIFIED';

  bool get isEkycPending => verificationStatus.toUpperCase() == 'PENDING';

  bool get isEkycRejected => verificationStatus.toUpperCase() == 'REJECTED';

  bool get canSubmitEkyc {
    final status = verificationStatus.toUpperCase();
    return !isEkycVerified &&
        (status == 'UNVERIFIED' || status == 'REJECTED' || status == 'PENDING');
  }

  String get verificationLabel {
    switch (verificationStatus.toUpperCase()) {
      case 'PENDING':
        return 'Đang chờ xét duyệt';
      case 'VERIFIED':
        return 'Đã xác minh';
      case 'REJECTED':
        return 'Bị từ chối';
      default:
        return 'Chưa xác minh';
    }
  }

  String get genderLabel {
    switch (gender?.toUpperCase()) {
      case 'MALE':
        return 'Nam';
      case 'FEMALE':
        return 'Nữ';
      case 'OTHER':
        return 'Khác';
      default:
        return 'Chưa cập nhật';
    }
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final verified = _toBool(json['isVerified']) ?? false;
    final verificationStatus =
        _nullableString(json['verificationStatus']) ??
        (verified ? 'VERIFIED' : 'UNVERIFIED');

    return ProfileModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: _nullableString(json['fullName']),
      nickname: _nullableString(json['nickname']),
      phone: _nullableString(json['phone']),
      avatarUrl: _nullableString(json['avatarUrl']),
      bio: _nullableString(json['bio']),
      gender: _nullableString(json['gender']),
      dob: _toDateTime(json['dob']),
      role: json['role']?.toString() ?? 'USER',
      isEmailVerified: _toBool(json['isEmailVerified']) ?? false,
      isVerified: verified,
      verificationStatus: verificationStatus,
      verificationRejectionReason: _nullableString(
        json['verificationRejectionReason'],
      ),
      hasEkycDocuments: _toBool(json['hasEkycDocuments']) ?? false,
      bankBin: _nullableString(json['bankBin']),
      bankName: _nullableString(json['bankName']),
      bankAccountNumber: _nullableString(json['bankAccountNumber']),
      bankAccountName: _nullableString(json['bankAccountName']),
      createdAt: _toDateTime(json['createdAt']),
      updatedAt: _toDateTime(json['updatedAt']),
    );
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    switch (value?.toString().toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
      default:
        return null;
    }
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
