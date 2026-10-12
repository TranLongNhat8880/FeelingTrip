import 'administrative_division_model.dart';
import 'place_search_result.dart';

/// Match whole labels only. Never infer a new province/ward from an old name.
class PlaceAddressMatch {
  const PlaceAddressMatch({this.province, this.district, this.ward});

  final AdministrativeDivision? province, district, ward;

  factory PlaceAddressMatch.resolve({
    required PlaceMapAddress address,
    required List<AdministrativeDivision> provinces,
    required List<AdministrativeDivision> districts,
    required List<AdministrativeDivision> wards,
    required AdministrativeDivision? selectedProvince,
    required AdministrativeDivision? selectedDistrict,
    required bool hasDistrictLevel,
  }) {
    final province = uniqueMatch(provinces, address.provinceCandidates);
    final sameProvince =
        province != null && province.code == selectedProvince?.code;
    final district = sameProvince && hasDistrictLevel
        ? uniqueMatch(districts, address.districtCandidates)
        : null;
    final sameParent =
        sameProvince &&
        (!hasDistrictLevel ||
            (district != null && district.code == selectedDistrict?.code));
    return PlaceAddressMatch(
      province: province,
      district: district,
      ward: sameParent ? uniqueMatch(wards, address.wardCandidates) : null,
    );
  }

  String? conflict({
    required PlaceMapAddress address,
    required AdministrativeDivision? selectedProvince,
    required AdministrativeDivision? selectedDistrict,
    required AdministrativeDivision? selectedWard,
  }) {
    if (address.countryCode.isNotEmpty &&
        address.countryCode.toLowerCase() != 'vn') {
      return 'Vị trí bản đồ nằm ngoài Việt Nam. Vui lòng chọn lại vị trí.';
    }
    for (final pair in [
      (province, selectedProvince),
      (district, selectedDistrict),
      (ward, selectedWard),
    ]) {
      if (pair.$1 != null &&
          pair.$2 != null &&
          pair.$1!.code != pair.$2!.code) {
        return 'Địa chỉ đang chọn không khớp bản đồ (${pair.$1!.name}). '
            'Hãy chọn lại địa chỉ hoặc đổi vị trí bản đồ.';
      }
    }
    return null;
  }

  bool needsConfirmation(bool hasDistrictLevel) =>
      province == null ||
      ward == null ||
      (hasDistrictLevel && district == null);

  static AdministrativeDivision? uniqueMatch(
    List<AdministrativeDivision> divisions,
    Iterable<String> candidates,
  ) {
    final matches = <int, AdministrativeDivision>{};
    for (final candidate in candidates) {
      final label = normalize(candidate);
      if (label.isEmpty) continue;
      final exact = divisions.where((d) => normalize(d.name) == label).toList();
      final found = exact.isNotEmpty
          ? exact
          : divisions.where(
              (d) =>
                  coreName(d.name) == coreName(candidate) &&
                  (_kind(candidate) == null ||
                      _kind(d.name) == null ||
                      _kind(candidate) == _kind(d.name)),
            );
      for (final division in found) {
        matches[division.code] = division;
      }
    }
    return matches.length == 1 ? matches.values.single : null;
  }

  static String coreName(String value) => normalize(value).replaceFirst(
    RegExp(
      r'^(thanh pho|tinh|quan|huyen|thi xa|phuong|xa|thi tran|city of|province of)\s+',
    ),
    '',
  );

  static String? _kind(String value) {
    final label = normalize(value);
    if (RegExp(r'^(phuong|xa|thi tran)\s').hasMatch(label)) return 'ward';
    if (RegExp(r'^(quan|huyen|thi xa)\s').hasMatch(label)) return 'district';
    if (RegExp(r'^(tinh|thanh pho|province of|city of)\s').hasMatch(label)) {
      return 'province';
    }
    return null;
  }

  static String normalize(String value) {
    var result = value.trim().toLowerCase();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final entry in groups.entries) {
      for (final character in entry.value.split('')) {
        result = result.replaceAll(character, entry.key);
      }
    }
    return result
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
