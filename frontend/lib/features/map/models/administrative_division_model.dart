// ============================================================================
// MODEL: Đơn vị hành chính dùng cho form địa điểm Admin
// Dùng chung cho Tỉnh/Thành phố, Quận/Huyện và Phường/Xã.
// ============================================================================

enum AdministrativeDivisionVersion {
  beforeMerger,
  afterMerger;

  bool get hasDistrictLevel => this == beforeMerger;

  String get apiVersion => switch (this) {
    beforeMerger => 'v1',
    afterMerger => 'v2',
  };
}

class AdministrativeDivision {
  const AdministrativeDivision({required this.code, required this.name});

  final int code;
  final String name;

  factory AdministrativeDivision.fromJson(Map<String, dynamic> json) {
    final code = _toInt(json['code']);
    final name = json['name']?.toString().trim() ?? '';

    if (code == null || name.isEmpty) {
      throw const FormatException('Dữ liệu đơn vị hành chính không hợp lệ');
    }

    return AdministrativeDivision(code: code, name: name);
  }

  static List<AdministrativeDivision> listFromJson(Object? rawData) {
    if (rawData is! List) {
      throw const FormatException('Danh sách đơn vị hành chính không hợp lệ');
    }

    final result = rawData
        .whereType<Map>()
        .map(
          (item) =>
              AdministrativeDivision.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    result.sort((first, second) => first.name.compareTo(second.name));

    return List.unmodifiable(result);
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdministrativeDivision && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => name;
}
