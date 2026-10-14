class SosAlert {
  const SosAlert({
    required this.id,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.message,
    this.createdAt,
    this.resolvedAt,
    this.tripId,
    this.tripName,
  });
  final String id, status;
  final double latitude, longitude;
  final String? message;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? tripId, tripName;
  Uri get mapUrl => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
  bool get isActive => status == 'ACTIVE';
  factory SosAlert.fromJson(Map<String, dynamic> json) {
    final latitude = double.tryParse('${json['latitude']}');
    final longitude = double.tryParse('${json['longitude']}');
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        !['ACTIVE', 'RESOLVED', 'FALSE_ALARM'].contains(json['status'])) {
      throw const FormatException('Dữ liệu SOS không hợp lệ.');
    }
    return SosAlert(
      id: json['id'],
      status: json['status'],
      latitude: latitude,
      longitude: longitude,
      message: json['message'] as String?,
      createdAt: DateTime.tryParse('${json['createdAt']}'),
      resolvedAt: DateTime.tryParse('${json['resolvedAt']}'),
      tripId: json['tripId'] as String?,
      tripName: json['tripName'] as String?,
    );
  }
}

class SosLocation {
  const SosLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });
  final double latitude, longitude, accuracy;
  final DateTime capturedAt;
  bool get isFresh =>
      accuracy.isFinite &&
      accuracy >= 0 &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      DateTime.now().difference(capturedAt).inSeconds >= -30 &&
      DateTime.now().difference(capturedAt).inSeconds <= 120;
  Uri get mapUrl => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
}
