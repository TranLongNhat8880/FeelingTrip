class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.tripId,
    required this.reviewerId,
    required this.rating,
    this.revieweeId,
    this.comment,
    this.createdAt,
  });

  final String id;
  final String tripId;
  final String reviewerId;
  final String? revieweeId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: '${json['id'] ?? ''}',
    tripId: '${json['tripId'] ?? ''}',
    reviewerId: '${json['reviewerId'] ?? ''}',
    revieweeId: _string(json['revieweeId']),
    rating: _integer(json['rating']),
    comment: _string(json['comment']),
    createdAt: _date(json['createdAt']),
  );
}

class UserReportModel {
  const UserReportModel({
    required this.id,
    required this.reporterId,
    required this.reason,
    required this.status,
    this.reportedUserId,
    this.reportedTripId,
    this.evidenceImageUrl,
    this.createdAt,
  });

  final String id;
  final String reporterId;
  final String? reportedUserId;
  final String? reportedTripId;
  final String reason;
  final String? evidenceImageUrl;
  final String status;
  final DateTime? createdAt;

  factory UserReportModel.fromJson(Map<String, dynamic> json) =>
      UserReportModel(
        id: '${json['id'] ?? ''}',
        reporterId: '${json['reporterId'] ?? ''}',
        reportedUserId: _string(json['reportedUserId']),
        reportedTripId: _string(json['reportedTripId']),
        reason: '${json['reason'] ?? ''}',
        evidenceImageUrl: _string(json['evidenceImageUrl']),
        status: '${json['status'] ?? 'PENDING'}'.toUpperCase(),
        createdAt: _date(json['createdAt']),
      );
}

class BlockedUserModel {
  const BlockedUserModel({
    required this.id,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
    this.blockedAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? blockedAt;

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    final nickname = _string(json['nickname']);
    final fullName = _string(json['fullName']);

    return BlockedUserModel(
      id: '${json['id'] ?? ''}',
      displayName: nickname ?? fullName ?? 'Người dùng',
      avatarUrl: _string(json['avatarUrl']),
      isVerified: json['isVerified'] == true,
      blockedAt: _date(json['blockedAt']),
    );
  }
}

class EmergencyContactModel {
  const EmergencyContactModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.relationship,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final String? relationship;
  final DateTime? createdAt;

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) =>
      EmergencyContactModel(
        id: '${json['id'] ?? ''}',
        fullName: '${json['fullName'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        relationship: _string(json['relationship']),
        createdAt: _date(json['createdAt']),
      );
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
