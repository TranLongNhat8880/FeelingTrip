// ============================================================================
// MODEL: Dữ liệu Admin nhập khi thêm hoặc sửa địa điểm
// ============================================================================

class PlaceFormData {
  const PlaceFormData({
    required this.name,
    required this.destination,
    required this.category,
    required this.priceLevel,
    required this.avgDurationMinutes,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String destination;
  final String? address;
  final String category;
  final double? latitude;
  final double? longitude;
  final int priceLevel;
  final int avgDurationMinutes;

  /// Chuyển thành các field text của multipart/form-data.
  Map<String, String> toMultipartFields() {
    return {
      'name': name.trim(),
      'destination': destination.trim(),
      'address': address?.trim() ?? '',
      'category': category,
      'priceLevel': priceLevel.toString(),
      'avgDurationMinutes': avgDurationMinutes.toString(),
      if (latitude != null && longitude != null) ...{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    };
  }
}
