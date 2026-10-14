// ================================================================================
// MODEL: User
// ================================================================================
// Đại diện cho 1 user trong hệ thống.
// Chứa phương thức fromJson (parse từ JSON) và toJson (chuyển thành JSON).
//
// Cách dùng:
//   final user = UserModel.fromJson(response['data']);
//   print(user.fullName);
// ================================================================================

class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String status;
  final String role; // 'USER' hoặc 'ADMIN'
  final bool isVerified; // Đã xác thực eKYC CCCD
  final String
  verificationStatus; // 'VERIFIED' | 'UNVERIFIED' | 'PENDING' | 'REJECTED'

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = 'USER',
    this.status = 'ACTIVE',
    this.isVerified = false,
    this.verificationStatus = 'UNVERIFIED',
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get hasVerifiedEkyc =>
      isVerified || verificationStatus.toUpperCase() == 'VERIFIED';

  /// Parse từ JSON (Backend trả về) → Object Dart
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final verified = json['isVerified'] ?? json['is_verified'] ?? false;
    final status =
        json['verificationStatus'] ??
        json['verification_status'] ??
        (verified == true ? 'VERIFIED' : 'UNVERIFIED');

    return UserModel(
      id: json['id'].toString(),
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['full_name'],
      phone: json['phone'],
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      role: json['role'] ?? 'USER',
      status: json['status'] ?? 'ACTIVE',
      isVerified: verified is bool
          ? verified
          : (verified == 1 || verified == 'true'),
      verificationStatus: status.toString(),
    );
  }

  /// Chuyển Object Dart → JSON (gửi lên Backend)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role,
      'status': status,
      'is_verified': isVerified,
      'verification_status': verificationStatus,
    };
  }

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, fullName: $fullName, role: $role, verified: $isVerified)';
}
