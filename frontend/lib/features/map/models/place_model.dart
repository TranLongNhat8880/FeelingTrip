// ============================================================================
// MODEL: Place
// Dữ liệu địa điểm nhận từ backend /api/v1/places.
// ============================================================================

class PlaceModel {
  const PlaceModel({
    required this.id,
    required this.name,
    required this.destination,
    required this.category,
    required this.priceLevel,
    required this.avgDurationMinutes,
    required this.rating,
    required this.isActive,
    this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.mapUrl,
    this.createdAt,
  });

  final String id;
  final String name;
  final String destination;
  final String? address;
  final String category;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final int priceLevel;
  final int avgDurationMinutes;
  final double rating;
  final bool isActive;
  final String? mapUrl;
  final DateTime? createdAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayLocation {
    final normalizedAddress = address?.trim();

    if (normalizedAddress != null && normalizedAddress.isNotEmpty) {
      return normalizedAddress;
    }

    return destination;
  }

  Uri? get mapUri {
    final value = mapUrl?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return Uri.tryParse(value);
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      address: json['address'] as String?,
      category: json['category'] as String? ?? 'OTHER',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      imageUrl: json['imageUrl'] as String?,
      priceLevel: _toInt(json['priceLevel']) ?? 1,
      avgDurationMinutes: _toInt(json['avgDurationMinutes']) ?? 60,
      rating: _toDouble(json['rating']) ?? 0,
      isActive: _toBool(json['isActive']) ?? true,
      mapUrl: json['mapUrl'] as String?,
      createdAt: _toDateTime(json['createdAt']),
    );
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _toBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      }

      if (value.toLowerCase() == 'false') {
        return false;
      }
    }

    return null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

// ============================================================================
// MODEL: Trang kết quả tìm kiếm địa điểm.
// ============================================================================

class PlacePage {
  const PlacePage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<PlaceModel> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory PlacePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawPagination = json['pagination'];

    final pagination = rawPagination is Map<String, dynamic>
        ? rawPagination
        : <String, dynamic>{};

    return PlacePage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      PlaceModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      page: PlaceModel._toInt(pagination['page']) ?? 1,
      limit: PlaceModel._toInt(pagination['limit']) ?? 20,
      total: PlaceModel._toInt(pagination['total']) ?? 0,
      totalPages: PlaceModel._toInt(pagination['totalPages']) ?? 0,
    );
  }
}
