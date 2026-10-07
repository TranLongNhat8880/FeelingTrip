// ================================================================================
// MODEL: CompanionRequest
// ================================================================================
// Đại diện cho 1 yêu cầu tham gia nhóm (leader nhận được).
// ================================================================================

class RequesterInfo {
  final String id;
  final String? fullName;
  final String? nickname;
  final String? avatarUrl;
  final String? phone;
  final bool isVerified;
  final double trustScore;
  final int reviewCount;

  const RequesterInfo({
    required this.id,
    this.fullName,
    this.nickname,
    this.avatarUrl,
    this.phone,
    this.isVerified = false,
    this.trustScore = 0,
    this.reviewCount = 0,
  });

  factory RequesterInfo.fromJson(Map<String, dynamic> json) => RequesterInfo(
    id: json['id']?.toString() ?? '',
    fullName: json['fullName'],
    nickname: json['nickname'],
    avatarUrl: json['avatarUrl'],
    phone: json['phone'],
    isVerified: json['isVerified'] ?? false,
    trustScore: double.tryParse('${json['trustScore']}') ?? 0,
    reviewCount: json['reviewCount'] ?? 0,
  );

  String get displayName => nickname ?? fullName ?? 'Người dùng';
}

class CompanionRequest {
  final String id;
  final String postId;
  final String? tripName;
  final String? introduction;
  final String status; // PENDING | ACCEPTED | REJECTED
  final DateTime createdAt;
  final RequesterInfo requester;

  const CompanionRequest({
    required this.id,
    required this.postId,
    this.tripName,
    this.introduction,
    required this.status,
    required this.createdAt,
    required this.requester,
  });

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isRejected => status == 'REJECTED';

  factory CompanionRequest.fromJson(Map<String, dynamic> json) =>
      CompanionRequest(
        id: json['id']?.toString() ?? '',
        postId: json['postId']?.toString() ?? '',
        tripName: (json['trip'] as Map?)?['name'] as String?,
        introduction: json['introduction'],
        status: json['status'] ?? 'PENDING',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'])?.toLocal() ?? DateTime.now()
            : DateTime.now(),
        requester: RequesterInfo.fromJson(
          json['requester'] as Map<String, dynamic>? ?? {},
        ),
      );
}
