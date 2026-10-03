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
  final String role; // 'USER' hoặc 'ADMIN'

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = 'USER',
  });

  /// Parse từ JSON (Backend trả về) → Object Dart
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email'],
      fullName: json['fullName'] ?? json['full_name'],
      phone: json['phone'],
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      role: json['role'] ?? 'USER',
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
    };
  }

  @override
  String toString() => 'UserModel(id: $id, email: $email, fullName: $fullName)';
}
