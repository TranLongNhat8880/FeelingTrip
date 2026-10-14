// ============================================================================
// MODEL: Kết quả tính khoảng cách giữa hai địa điểm
// ============================================================================

class PlaceCoordinates {
  const PlaceCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory PlaceCoordinates.fromJson(Map<String, dynamic> json) {
    return PlaceCoordinates(
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PlaceDistanceResult {
  const PlaceDistanceResult({
    required this.origin,
    required this.destination,
    required this.travelMode,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    required this.calculationMethod,
    this.directionsUrl,
  });

  final PlaceCoordinates origin;
  final PlaceCoordinates destination;
  final String travelMode;
  final double distanceKm;
  final int estimatedDurationMinutes;
  final String calculationMethod;
  final String? directionsUrl;

  Uri? get directionsUri {
    final value = directionsUrl?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return Uri.tryParse(value);
  }

  factory PlaceDistanceResult.fromJson(Map<String, dynamic> json) {
    final rawOrigin = json['origin'];
    final rawDestination = json['destination'];

    return PlaceDistanceResult(
      origin: PlaceCoordinates.fromJson(
        rawOrigin is Map
            ? Map<String, dynamic>.from(rawOrigin)
            : <String, dynamic>{},
      ),
      destination: PlaceCoordinates.fromJson(
        rawDestination is Map
            ? Map<String, dynamic>.from(rawDestination)
            : <String, dynamic>{},
      ),
      travelMode: json['travelMode'] as String? ?? 'driving',
      distanceKm: _toDouble(json['distanceKm']),
      estimatedDurationMinutes: _toInt(json['estimatedDurationMinutes']),
      calculationMethod:
          json['calculationMethod'] as String? ?? 'HAVERSINE_ESTIMATE',
      directionsUrl: json['directionsUrl'] as String?,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
