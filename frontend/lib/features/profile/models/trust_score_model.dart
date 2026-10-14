// ============================================================================
// MODEL: Thông tin tín nhiệm công khai của một người dùng
// Dữ liệu nhận từ GET /api/v1/users/trust-score/:id.
// ============================================================================

class TrustScoreModel {
  const TrustScoreModel({
    required this.id,
    required this.fullName,
    required this.isVerified,
    required this.trustScore,
    required this.reviewCount,
    this.nickname,
    this.avatarUrl,
    this.bio,
    this.memberSince,
    this.age,
  });

  final String id;
  final String fullName;
  final String? nickname;
  final String? avatarUrl;
  final String? bio;
  final bool isVerified;
  final double trustScore;
  final int reviewCount;
  final DateTime? memberSince;

  /// Age computed by the backend; the public API does not expose date of birth.
  final int? age;

  String get displayName {
    final normalizedNickname = nickname?.trim();

    if (normalizedNickname != null && normalizedNickname.isNotEmpty) {
      return normalizedNickname;
    }

    return fullName;
  }

  factory TrustScoreModel.fromJson(Map<String, dynamic> json) {
    return TrustScoreModel(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      nickname: _nullableString(json['nickname']),
      avatarUrl: _nullableString(json['avatarUrl']),
      bio: _nullableString(json['bio']),
      isVerified: _toBool(json['isVerified']) ?? false,
      trustScore: _toDouble(json['trustScore']) ?? 0,
      reviewCount: _toInt(json['reviewCount']) ?? 0,
      memberSince: _toDateTime(json['memberSince']),
      age: _toAge(json['age']),
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

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _toAge(Object? value) {
    final age = int.tryParse(value?.toString() ?? '');
    return age != null && age >= 0 ? age : null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
