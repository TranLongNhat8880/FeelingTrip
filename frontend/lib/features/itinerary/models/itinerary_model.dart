const itineraryCategories = <String, String>{
  'ATTRACTION': 'Điểm tham quan',
  'RESTAURANT': 'Nhà hàng',
  'CAFE': 'Quán cà phê',
  'HOTEL': 'Khách sạn',
  'ENTERTAINMENT': 'Giải trí',
  'NATURE': 'Thiên nhiên',
  'CULTURE': 'Văn hóa',
  'SHOPPING': 'Mua sắm',
  'OTHER': 'Khác',
};

class ItineraryTripHeader {
  const ItineraryTripHeader({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.memberRole,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String memberRole;

  bool get canEdit =>
      memberRole == 'LEADER' && ['UPCOMING', 'ONGOING'].contains(status);

  factory ItineraryTripHeader.fromJson(Map<String, dynamic> json) =>
      ItineraryTripHeader(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? 'Chuyến đi'}',
        startDate: _date(json['startDate']) ?? DateTime.now(),
        endDate: _date(json['endDate']) ?? DateTime.now(),
        status: '${json['status'] ?? 'UPCOMING'}'.toUpperCase(),
        memberRole: '${json['memberRole'] ?? 'MEMBER'}'.toUpperCase(),
      );
}

class ItineraryPlan {
  const ItineraryPlan({required this.trip, required this.days});

  final ItineraryTripHeader trip;
  final List<ItineraryDay> days;

  factory ItineraryPlan.fromJson(Map<String, dynamic> json) => ItineraryPlan(
    trip: ItineraryTripHeader.fromJson(_map(json['trip'])),
    days: _mapList(json['days']).map(ItineraryDay.fromJson).toList(),
  );
}

class ItineraryDay {
  const ItineraryDay({
    required this.tripId,
    required this.dayNumber,
    required this.title,
    required this.tripDate,
    required this.materialized,
    required this.items,
    this.id,
    this.createdAt,
    this.version,
  });

  final String? id;
  final String tripId;
  final int dayNumber;
  final String title;
  final DateTime tripDate;
  final bool materialized;
  final DateTime? createdAt;
  final String? version;
  final List<ItineraryItem> items;

  int get estimatedCost =>
      items.fold(0, (total, item) => total + item.estimatedCost);

  factory ItineraryDay.fromJson(Map<String, dynamic> json) => ItineraryDay(
    id: _string(json['id']),
    tripId: '${json['tripId'] ?? ''}',
    dayNumber: _integer(json['dayNumber']),
    title: '${json['title'] ?? 'Ngày ${json['dayNumber'] ?? ''}'}',
    tripDate: _date(json['tripDate']) ?? DateTime.now(),
    materialized: json['materialized'] == true,
    createdAt: _date(json['createdAt']),
    version: _string(json['version']),
    items: _mapList(json['items']).map(ItineraryItem.fromJson).toList(),
  );
}

class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.itineraryId,
    required this.customName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.estimatedCost,
    required this.isCompleted,
    required this.version,
    this.placeId,
    this.customAddress,
    this.latitude,
    this.longitude,
    this.note,
    this.createdAt,
    this.expenseId,
    this.actualAmount,
  });

  final String id;
  final String itineraryId;
  final String? placeId;
  final String customName;
  final String? customAddress;
  final double? latitude;
  final double? longitude;
  final String category;
  final String startTime;
  final String endTime;
  final String? note;
  final int estimatedCost;
  final bool isCompleted;
  final DateTime? createdAt;
  final String version;
  final String? expenseId;
  final int? actualAmount;

  bool get supportsSmartSwap => placeId != null;

  factory ItineraryItem.fromJson(Map<String, dynamic> json) => ItineraryItem(
    id: '${json['id'] ?? ''}',
    itineraryId: '${json['itineraryId'] ?? ''}',
    placeId: _string(json['placeId']),
    customName: '${json['customName'] ?? 'Điểm dừng'}',
    customAddress: _string(json['customAddress']),
    latitude: json['latitude'] == null ? null : _double(json['latitude']),
    longitude: json['longitude'] == null ? null : _double(json['longitude']),
    category: '${json['category'] ?? 'OTHER'}'.toUpperCase(),
    startTime: '${json['startTime'] ?? ''}',
    endTime: '${json['endTime'] ?? ''}',
    note: _string(json['note']),
    estimatedCost: _integer(json['estimatedCost']),
    isCompleted: json['isCompleted'] == true,
    createdAt: _date(json['createdAt']),
    version: '${json['version'] ?? ''}',
    expenseId: _string(json['expenseId']),
    actualAmount: json['actualAmount'] == null
        ? null
        : _integer(json['actualAmount']),
  );
}

class ItineraryItemDraft {
  const ItineraryItemDraft({
    required this.customName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.estimatedCost,
    this.placeId,
    this.customAddress,
    this.note,
  });

  final String? placeId;
  final String customName;
  final String? customAddress;
  final String category;
  final String startTime;
  final String endTime;
  final String? note;
  final int estimatedCost;

  Map<String, dynamic> toCreateJson() => {
    'placeId': placeId,
    'customName': customName.trim(),
    'customAddress': customAddress?.trim(),
    'category': category,
    'startTime': startTime,
    'endTime': endTime,
    'note': note?.trim(),
    'estimatedCost': estimatedCost,
  };

  Map<String, dynamic> toUpdateJson(String expectedVersion) => {
    'customName': customName.trim(),
    'customAddress': customAddress?.trim(),
    'category': category,
    'startTime': startTime,
    'endTime': endTime,
    'note': note?.trim(),
    'estimatedCost': estimatedCost,
    'expectedVersion': expectedVersion,
  };
}

class ItineraryPlaceOption {
  const ItineraryPlaceOption({
    required this.id,
    required this.name,
    required this.destination,
    required this.category,
    this.address,
    this.latitude,
    this.longitude,
    this.rating = 0,
  });

  final String id;
  final String name;
  final String destination;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String category;
  final double rating;

  factory ItineraryPlaceOption.fromJson(Map<String, dynamic> json) =>
      ItineraryPlaceOption(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        destination: '${json['destination'] ?? ''}',
        address: _string(json['address']),
        latitude: json['latitude'] == null ? null : _double(json['latitude']),
        longitude: json['longitude'] == null
            ? null
            : _double(json['longitude']),
        category: '${json['category'] ?? 'OTHER'}'.toUpperCase(),
        rating: _double(json['rating']),
      );
}

class SwapCandidate {
  const SwapCandidate({
    required this.placeId,
    required this.name,
    required this.category,
    required this.rating,
    required this.distanceFromOriginalKm,
    required this.routeDeltaKm,
    required this.candidateToken,
    this.address,
  });

  final String placeId;
  final String name;
  final String? address;
  final String category;
  final double rating;
  final double distanceFromOriginalKm;
  final double routeDeltaKm;
  final String candidateToken;

  factory SwapCandidate.fromJson(Map<String, dynamic> json) => SwapCandidate(
    placeId: '${json['placeId'] ?? ''}',
    name: '${json['name'] ?? ''}',
    address: _string(json['address']),
    category: '${json['category'] ?? 'OTHER'}'.toUpperCase(),
    rating: _double(json['rating']),
    distanceFromOriginalKm: _double(json['distanceFromOriginalKm']),
    routeDeltaKm: _double(json['routeDeltaKm']),
    candidateToken: '${json['candidateToken'] ?? ''}',
  );
}

class PublicItinerarySummary {
  const PublicItinerarySummary({
    required this.sourceTripId,
    required this.name,
    required this.destination,
    required this.durationDays,
    required this.averageRating,
    required this.reviewCount,
    required this.cloneCount,
    this.coverImageUrl,
    this.description,
    this.updatedAt,
  });

  final String sourceTripId;
  final String name;
  final String destination;
  final int durationDays;
  final String? coverImageUrl;
  final String? description;
  final double averageRating;
  final int reviewCount;
  final int cloneCount;
  final DateTime? updatedAt;

  factory PublicItinerarySummary.fromJson(Map<String, dynamic> json) =>
      PublicItinerarySummary(
        sourceTripId: '${json['sourceTripId'] ?? ''}',
        name: '${json['name'] ?? 'Lịch trình'}',
        destination: '${json['destination'] ?? ''}',
        durationDays: _integer(json['durationDays']),
        coverImageUrl: _string(json['coverImageUrl']),
        description: _string(json['description']),
        averageRating: _double(json['averageRating']),
        reviewCount: _integer(json['reviewCount']),
        cloneCount: _integer(json['cloneCount']),
        updatedAt: _date(json['updatedAt']),
      );
}

class PublicItineraryDetail {
  const PublicItineraryDetail({required this.summary, required this.days});

  final PublicItinerarySummary summary;
  final List<PublicItineraryDay> days;

  factory PublicItineraryDetail.fromJson(Map<String, dynamic> json) =>
      PublicItineraryDetail(
        summary: PublicItinerarySummary.fromJson(json),
        days: _mapList(json['days']).map(PublicItineraryDay.fromJson).toList(),
      );
}

class PublicItineraryDay {
  const PublicItineraryDay({
    required this.dayNumber,
    required this.title,
    required this.items,
  });

  final int dayNumber;
  final String title;
  final List<PublicItineraryItem> items;

  factory PublicItineraryDay.fromJson(Map<String, dynamic> json) =>
      PublicItineraryDay(
        dayNumber: _integer(json['dayNumber']),
        title: '${json['title'] ?? 'Ngày ${json['dayNumber'] ?? ''}'}',
        items: _mapList(
          json['items'],
        ).map(PublicItineraryItem.fromJson).toList(),
      );
}

class PublicItineraryItem {
  const PublicItineraryItem({
    required this.customName,
    required this.category,
    required this.startTime,
    required this.endTime,
    this.customAddress,
    this.note,
  });

  final String customName;
  final String? customAddress;
  final String category;
  final String startTime;
  final String endTime;
  final String? note;

  factory PublicItineraryItem.fromJson(Map<String, dynamic> json) =>
      PublicItineraryItem(
        customName: '${json['customName'] ?? 'Điểm dừng'}',
        customAddress: _string(json['customAddress']),
        category: '${json['category'] ?? 'OTHER'}'.toUpperCase(),
        startTime: '${json['startTime'] ?? ''}',
        endTime: '${json['endTime'] ?? ''}',
        note: _string(json['note']),
      );
}

class PublicItineraryPage {
  const PublicItineraryPage({required this.items, required this.total});

  final List<PublicItinerarySummary> items;
  final int total;

  factory PublicItineraryPage.fromJson(Map<String, dynamic> json) {
    final pagination = _map(json['pagination']);
    final items = _mapList(
      json['items'],
    ).map(PublicItinerarySummary.fromJson).toList();
    return PublicItineraryPage(
      items: items,
      total: pagination.isEmpty ? items.length : _integer(pagination['total']),
    );
  }
}

String categoryLabel(String category) =>
    itineraryCategories[category] ?? itineraryCategories['OTHER']!;

String? _string(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  if (value == null || '$value'.isEmpty) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

int _integer(dynamic value) {
  if (value is num) return value.round();
  return num.tryParse('$value')?.round() ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];
