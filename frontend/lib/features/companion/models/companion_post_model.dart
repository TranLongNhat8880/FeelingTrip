// ================================================================================
// MODEL: CompanionPost
// ================================================================================
// Đại diện cho 1 bài đăng tìm bạn đồng hành.
// Dùng cho cả feed (danh sách) và detail (chi tiết).
// ================================================================================

class TripInfo {
  final String id;
  final String? name;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? durationDays;
  final double? estimatedBudget;
  final String? coverImageUrl;
  final String? status;
  final List<TripMemberInfo> members;
  final List<CompanionItineraryDay> itinerary;

  const TripInfo({
    required this.id,
    this.name,
    this.destination,
    this.startDate,
    this.endDate,
    this.durationDays,
    this.estimatedBudget,
    this.coverImageUrl,
    this.status,
    this.members = const [],
    this.itinerary = const [],
  });

  factory TripInfo.fromJson(Map<String, dynamic> json) => TripInfo(
    id: json['id']?.toString() ?? '',
    name: json['name'],
    destination: json['destination'],
    startDate: json['startDate'] != null
        ? DateTime.tryParse(json['startDate'])?.toLocal()
        : null,
    endDate: json['endDate'] != null
        ? DateTime.tryParse(json['endDate'])?.toLocal()
        : null,
    durationDays: json['durationDays'],
    estimatedBudget: double.tryParse('${json['estimatedBudget']}'),
    coverImageUrl: json['coverImageUrl'],
    status: json['status'],
    itinerary: (json['itinerary'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map(
          (d) => CompanionItineraryDay.fromJson(Map<String, dynamic>.from(d)),
        )
        .toList(),
    members:
        (json['members'] as List<dynamic>?)
            ?.map((m) => TripMemberInfo.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class CompanionItineraryDay {
  const CompanionItineraryDay({
    required this.dayNumber,
    required this.title,
    this.date,
    this.items = const [],
  });
  final int dayNumber;
  final String title;
  final DateTime? date;
  final List<CompanionItineraryItem> items;
  factory CompanionItineraryDay.fromJson(Map<String, dynamic> json) =>
      CompanionItineraryDay(
        dayNumber: int.tryParse('${json['dayNumber']}') ?? 1,
        title: '${json['title'] ?? 'Lịch trình'}',
        date: DateTime.tryParse('${json['tripDate']}'),
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map(
              (i) =>
                  CompanionItineraryItem.fromJson(Map<String, dynamic>.from(i)),
            )
            .toList(),
      );
}

class CompanionItineraryItem {
  const CompanionItineraryItem({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.estimatedCost,
    this.address,
  });
  final String name, startTime, endTime;
  final String? address;
  final int estimatedCost;
  factory CompanionItineraryItem.fromJson(Map<String, dynamic> json) =>
      CompanionItineraryItem(
        name: '${json['customName'] ?? 'Hoạt động'}',
        startTime: '${json['startTime'] ?? ''}',
        endTime: '${json['endTime'] ?? ''}',
        estimatedCost: num.tryParse('${json['estimatedCost']}')?.round() ?? 0,
        address: json['customAddress'] as String?,
      );
}

class TripMemberInfo {
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final String? role;
  final DateTime? joinedAt;

  const TripMemberInfo({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.role,
    this.joinedAt,
  });

  factory TripMemberInfo.fromJson(Map<String, dynamic> json) => TripMemberInfo(
    userId: json['userId']?.toString() ?? '',
    displayName: json['displayName'],
    avatarUrl: json['avatarUrl'],
    role: json['role'],
    joinedAt: json['joinedAt'] != null
        ? DateTime.tryParse(json['joinedAt'])?.toLocal()
        : null,
  );
}

class CreatorInfo {
  final String id;
  final String? fullName;
  final String? nickname;
  final String? avatarUrl;
  final bool isVerified;
  final double trustScore;
  final int reviewCount;

  const CreatorInfo({
    required this.id,
    this.fullName,
    this.nickname,
    this.avatarUrl,
    this.isVerified = false,
    this.trustScore = 0,
    this.reviewCount = 0,
  });

  factory CreatorInfo.fromJson(Map<String, dynamic> json) => CreatorInfo(
    id: json['id']?.toString() ?? '',
    fullName: json['fullName'],
    nickname: json['nickname'],
    avatarUrl: json['avatarUrl'],
    isVerified: json['isVerified'] ?? false,
    trustScore: double.tryParse('${json['trustScore']}') ?? 0,
    reviewCount: json['reviewCount'] ?? 0,
  );

  String get displayName => nickname ?? fullName ?? 'Người dùng';
}

class CompanionPost {
  final String id;
  final String? title;
  final String? content;
  final int targetMembersCount;
  final int currentMembersCount;
  final int? minAge;
  final int? maxAge;
  final String genderPreference; // ANY | MALE | FEMALE
  final List<String> tags;
  final String status; // OPEN | FULL | CLOSED
  final DateTime createdAt;
  final DateTime? updatedAt;
  final TripInfo trip;
  final CreatorInfo creator;
  final String? myRequestId;
  final String? myRequestStatus; // PENDING | ACCEPTED | REJECTED

  const CompanionPost({
    required this.id,
    this.title,
    this.content,
    required this.targetMembersCount,
    required this.currentMembersCount,
    this.minAge,
    this.maxAge,
    this.genderPreference = 'ANY',
    this.tags = const [],
    this.status = 'OPEN',
    required this.createdAt,
    this.updatedAt,
    required this.trip,
    required this.creator,
    this.myRequestStatus,
    this.myRequestId,
  });

  int get slotsLeft => targetMembersCount - currentMembersCount;
  bool get isFull => status == 'FULL' || slotsLeft <= 0;
  bool get isOpen => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';

  factory CompanionPost.fromJson(Map<String, dynamic> json) => CompanionPost(
    id: json['id']?.toString() ?? '',
    title: json['title'],
    myRequestStatus: json['myRequestStatus'],
    myRequestId: json['myRequestId'],
    content: json['content'],
    targetMembersCount: json['targetMembersCount'] ?? 0,
    currentMembersCount: json['currentMembersCount'] ?? 0,
    minAge: json['minAge'],
    maxAge: json['maxAge'],
    genderPreference: json['genderPreference'] ?? 'ANY',
    tags:
        (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ??
        [],
    status: json['status'] ?? 'OPEN',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'])?.toLocal() ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'])?.toLocal()
        : null,
    trip: TripInfo.fromJson(json['trip'] as Map<String, dynamic>? ?? {}),
    creator: CreatorInfo.fromJson(
      json['creator'] as Map<String, dynamic>? ?? {},
    ),
  );
}

class PaginationInfo {
  final int totalItems;
  final int totalPages;
  final int currentPage;
  final int limit;

  const PaginationInfo({
    required this.totalItems,
    required this.totalPages,
    required this.currentPage,
    required this.limit,
  });

  bool get hasNextPage => currentPage < totalPages;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) => PaginationInfo(
    totalItems: json['totalItems'] ?? 0,
    totalPages: json['totalPages'] ?? 1,
    currentPage: json['currentPage'] ?? 1,
    limit: json['limit'] ?? 20,
  );
}
