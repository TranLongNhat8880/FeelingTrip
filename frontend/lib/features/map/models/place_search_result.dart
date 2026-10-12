class PlaceSearchResult {
  const PlaceSearchResult({
    required this.id,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  factory PlaceSearchResult.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final properties = _asMap(feature['properties']);
    final geometry = _asMap(feature['geometry']);
    final coordinates = geometry['coordinates'];

    final coordinateList = coordinates is List ? coordinates : const [];

    final longitude =
        _toDouble(properties['lon']) ??
        (coordinateList.isNotEmpty ? _toDouble(coordinateList.first) : null);

    final latitude =
        _toDouble(properties['lat']) ??
        (coordinateList.length > 1 ? _toDouble(coordinateList[1]) : null);

    if (latitude == null || longitude == null) {
      throw const FormatException('Kết quả tìm kiếm không chứa tọa độ hợp lệ.');
    }

    final formattedAddress =
        _text(properties['formatted']) ??
        _text(properties['address_line1']) ??
        'Địa điểm chưa có địa chỉ';

    final name =
        _text(properties['name']) ??
        _text(properties['address_line1']) ??
        _text(properties['city']) ??
        formattedAddress;

    return PlaceSearchResult(
      id: _text(properties['place_id']) ?? '$latitude,$longitude',
      name: name,
      formattedAddress: formattedAddress,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String? _text(Object? value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
