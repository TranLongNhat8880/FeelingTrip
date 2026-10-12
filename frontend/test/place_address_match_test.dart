import 'package:feeling_trip/features/map/models/administrative_division_model.dart';
import 'package:feeling_trip/features/map/models/place_address_match.dart';
import 'package:feeling_trip/features/map/models/place_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hanoi = AdministrativeDivision(code: 1, name: 'Thành phố Hà Nội');
  const hue = AdministrativeDivision(code: 46, name: 'Thành phố Huế');
  const district = AdministrativeDivision(code: 2, name: 'Quận Hoàn Kiếm');
  const ward = AdministrativeDivision(code: 3, name: 'Phường Hoàn Kiếm');
  const otherWard = AdministrativeDivision(code: 4, name: 'Phường Ba Đình');

  test('whole labels match accents, spacing and administrative prefixes', () {
    expect(
      PlaceAddressMatch.uniqueMatch([hanoi, hue], ['  Ha   Noi  ']),
      hanoi,
    );
    expect(
      PlaceAddressMatch.uniqueMatch([hanoi, hue], ['Thành phố Hà Nội']),
      hanoi,
    );
    expect(PlaceAddressMatch.uniqueMatch([hanoi, hue], ['Nội']), isNull);
    expect(PlaceAddressMatch.uniqueMatch([hanoi, hue], ['Đường Huế']), isNull);
    expect(PlaceAddressMatch.uniqueMatch([ward], ['Quận Hoàn Kiếm']), isNull);
  });

  test('numbered wards and ambiguous labels are not guessed', () {
    const one = AdministrativeDivision(code: 1, name: 'Phường 1');
    const ten = AdministrativeDivision(code: 10, name: 'Phường 10');
    const commune = AdministrativeDivision(code: 20, name: 'Xã 1');
    expect(PlaceAddressMatch.uniqueMatch([one, ten], ['Phường 10']), ten);
    expect(PlaceAddressMatch.uniqueMatch([one, commune], ['1']), isNull);
    expect(
      PlaceAddressMatch.uniqueMatch([one, ten], ['Phường 1', 'Phường 10']),
      isNull,
    );
  });

  PlaceAddressMatch resolve(
    PlaceMapAddress address, {
    AdministrativeDivision province = hanoi,
    AdministrativeDivision? selectedDistrict = district,
    bool beforeMerger = false,
  }) => PlaceAddressMatch.resolve(
    address: address,
    provinces: [hanoi, hue],
    districts: [district],
    wards: [ward, otherWard],
    selectedProvince: province,
    selectedDistrict: selectedDistrict,
    hasDistrictLevel: beforeMerger,
  );

  test(
    'two-level address needs no district and detects wrong province/ward',
    () {
      const address = PlaceMapAddress(
        countryCode: 'vn',
        province: 'Hà Nội',
        suburb: 'Phường Hoàn Kiếm',
      );
      final match = resolve(address);
      expect(match.province, hanoi);
      expect(match.ward, ward);
      expect(match.needsConfirmation(false), isFalse);
      expect(
        match.conflict(
          address: address,
          selectedProvince: hanoi,
          selectedDistrict: null,
          selectedWard: ward,
        ),
        isNull,
      );
      expect(
        match.conflict(
          address: address,
          selectedProvince: hanoi,
          selectedDistrict: null,
          selectedWard: otherWard,
        ),
        contains('Phường Hoàn Kiếm'),
      );
      final wrongProvince = resolve(address, province: hue);
      expect(wrongProvince.ward, isNull);
      expect(
        wrongProvince.conflict(
          address: address,
          selectedProvince: hue,
          selectedDistrict: null,
          selectedWard: null,
        ),
        contains('Thành phố Hà Nội'),
      );
    },
  );

  test('three-level address must also match the district', () {
    const address = PlaceMapAddress(
      province: 'Hà Nội',
      county: 'Quận Hoàn Kiếm',
      suburb: 'Phường Hoàn Kiếm',
    );
    expect(
      resolve(address, beforeMerger: true).needsConfirmation(true),
      isFalse,
    );
    final match = resolve(address, beforeMerger: true, selectedDistrict: null);
    expect(match.ward, isNull);
    expect(match.needsConfirmation(true), isTrue);
    const wrongDistrict = AdministrativeDivision(
      code: 99,
      name: 'Quận Ba Đình',
    );
    expect(
      resolve(
        address,
        beforeMerger: true,
        selectedDistrict: wrongDistrict,
      ).conflict(
        address: address,
        selectedProvince: hanoi,
        selectedDistrict: wrongDistrict,
        selectedWard: null,
      ),
      contains('Quận Hoàn Kiếm'),
    );
  });

  test('old names and missing metadata require manual confirmation', () {
    final old = resolve(
      const PlaceMapAddress(province: 'Hà Tây', suburb: 'Phường cũ'),
    );
    expect(old.province, isNull);
    expect(old.ward, isNull);
    expect(old.needsConfirmation(false), isTrue);
    expect(resolve(const PlaceMapAddress()).needsConfirmation(false), isTrue);
    final oldDistrict = resolve(
      const PlaceMapAddress(province: 'Hà Nội', district: 'Hoàn Kiếm'),
    );
    expect(oldDistrict.ward, isNull);
    expect(oldDistrict.needsConfirmation(false), isTrue);
  });

  test(
    'known foreign country is a conflict even without administrative matches',
    () {
      const address = PlaceMapAddress(countryCode: 'US');
      expect(
        resolve(address).conflict(
          address: address,
          selectedProvince: hanoi,
          selectedDistrict: null,
          selectedWard: ward,
        ),
        contains('ngoài Việt Nam'),
      );
    },
  );

  test('metadata survives parsing and coordinate/name changes', () {
    final result = PlaceSearchResult.fromGeoJsonFeature({
      'properties': {
        'lat': 21,
        'lon': 105,
        'country_code': 'vn',
        'state': 'Hà Nội',
        'county': 'Hoàn Kiếm',
        'suburb': 'Hàng Trống',
        'street': 'Lê Thái Tổ',
        'housenumber': '1',
      },
    });
    final moved = result.copyWith(
      name: '',
      latitude: 21.028,
      longitude: 105.852,
    );
    expect(moved.name, '');
    expect(moved.latitude, 21.028);
    expect(moved.mapAddress.province, 'Hà Nội');
    expect(moved.mapAddress.wardCandidates, contains('Hàng Trống'));
    expect(moved.mapAddress.detailedAddress, '1 Lê Thái Tổ');
  });
}
