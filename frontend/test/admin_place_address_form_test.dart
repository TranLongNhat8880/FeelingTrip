import 'dart:convert';

import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/features/map/models/administrative_division_model.dart';
import 'package:feeling_trip/features/map/models/place_model.dart';
import 'package:feeling_trip/features/map/models/place_form_data.dart';
import 'package:feeling_trip/features/map/models/place_search_result.dart';
import 'package:feeling_trip/features/map/repositories/administrative_division_repository.dart';
import 'package:feeling_trip/features/map/repositories/place_repository.dart';
import 'package:feeling_trip/features/map/views/admin_place_form_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Divisions extends AdministrativeDivisionRepository {
  _Divisions() : super(client: MockClient((_) async => http.Response('', 500)));

  @override
  Future<List<AdministrativeDivision>> getProvinces(
    AdministrativeDivisionVersion version,
  ) async => [
    const AdministrativeDivision(code: 1, name: 'Thành phố Hà Nội'),
    const AdministrativeDivision(code: 46, name: 'Thành phố Huế'),
  ];
  @override
  Future<List<AdministrativeDivision>> getDistricts(int provinceCode) async => [
    const AdministrativeDivision(code: 2, name: 'Quận Hoàn Kiếm'),
  ];
  @override
  Future<List<AdministrativeDivision>> getWardsByProvince(
    int provinceCode,
  ) async => provinceCode == 1
      ? [
          const AdministrativeDivision(code: 3, name: 'Phường Hoàn Kiếm'),
          const AdministrativeDivision(code: 4, name: 'Phường Ba Đình'),
        ]
      : [const AdministrativeDivision(code: 5, name: 'Phường Thuận Hóa')];
  @override
  Future<List<AdministrativeDivision>> getWardsByDistrict(int districtCode) =>
      getWardsByProvince(1);
}

class _Places extends Fake implements PlaceRepository {
  PlaceFormData? savedData;
  int writes = 0;
  @override
  Future<PlaceModel> createPlace({
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  }) async {
    writes++;
    savedData = data;
    return PlaceModel(
      id: 'saved',
      name: data.name,
      destination: data.destination,
      category: data.category,
      priceLevel: data.priceLevel,
      avgDurationMinutes: data.avgDurationMinutes,
      rating: 0,
      isActive: true,
    );
  }

  @override
  Future<PlaceModel> updatePlace({
    required String placeId,
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  }) => createPlace(data: data);
}

void main() {
  final originalClient = ApiClient.client;
  late _Places places;
  const mapped = PlaceSearchResult(
    id: 'pin',
    name: 'Hồ Hoàn Kiếm',
    formattedAddress: 'Hồ Hoàn Kiếm, Hà Nội',
    latitude: 21.028,
    longitude: 105.852,
    mapAddress: PlaceMapAddress(
      countryCode: 'vn',
      province: 'Hà Nội',
      county: 'Quận Hoàn Kiếm',
      suburb: 'Phường Hoàn Kiếm',
      street: 'Lê Thái Tổ',
    ),
  );
  setUp(() {
    places = _Places();
    SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'});
    ApiClient.client = MockClient((request) async {
      expect(request.method, 'GET');
      final Object data = request.url.path.endsWith('/reverse')
          ? {
              'features': [
                {
                  'properties': {
                    'lat': 21.028,
                    'lon': 105.852,
                    'country_code': 'vn',
                    'state': 'Hà Nội',
                    'suburb': 'Phường Hoàn Kiếm',
                  },
                },
              ],
            }
          : {'configured': false};
      return http.Response(
        jsonEncode({'success': true, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  });
  tearDown(() {
    ApiClient.client.close();
    ApiClient.client = originalClient;
  });

  Future<void> openForm(WidgetTester tester, {PlaceModel? place}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPlaceFormScreen(
                    initialPlace: place,
                    divisionRepository: _Divisions(),
                    placeRepository: places,
                  ),
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
  }

  Future<void> returnPin(WidgetTester tester, PlaceSearchResult pin) async {
    final button = find.widgetWithText(
      CustomButton,
      'Chọn bản đồ để điền địa chỉ',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    // Return a selection without loading native map tiles or using network APIs.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop(pin);
    await tester.pumpAndSettle();
  }

  DropdownButtonFormField<int> dropdown(WidgetTester tester, String label) =>
      tester.widget<DropdownButtonFormField<int>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<int> &&
              widget.decoration.labelText == label,
        ),
      );

  CustomTextField field(WidgetTester tester, String label) =>
      tester.widget<CustomTextField>(
        find.byWidgetPredicate(
          (widget) => widget is CustomTextField && widget.label == label,
        ),
      );

  testWidgets(
    'a second map selection replaces name, detail, province, ward and coordinates',
    (tester) async {
      await openForm(tester);
      await returnPin(tester, mapped);
      await returnPin(
        tester,
        const PlaceSearchResult(
          id: 'hue-pin',
          name: 'Điểm ở Huế',
          formattedAddress: 'Điểm ở Huế, Thành phố Huế',
          latitude: 16.46,
          longitude: 107.58,
          mapAddress: PlaceMapAddress(
            countryCode: 'vn',
            province: 'Huế',
            suburb: 'Phường Thuận Hóa',
            street: 'Đường mới',
            houseNumber: '12',
          ),
        ),
      );
      expect(field(tester, 'Tên địa điểm').controller!.text, 'Điểm ở Huế');
      expect(
        field(tester, 'Địa chỉ chi tiết').controller!.text,
        '12 Đường mới',
      );
      expect(field(tester, 'Vĩ độ').controller!.text, '16.46');
      expect(field(tester, 'Kinh độ').controller!.text, '107.58');
      expect(dropdown(tester, 'Tỉnh hoặc thành phố').initialValue, 46);
      expect(dropdown(tester, 'Phường hoặc xã').initialValue, 5);
      await tester.tap(find.widgetWithText(CustomButton, 'Thêm địa điểm'));
      await tester.pumpAndSettle();
      expect(places.writes, 1);
      expect(places.savedData!.name, 'Điểm ở Huế');
      expect(
        places.savedData!.address,
        '12 Đường mới, Phường Thuận Hóa, Thành phố Huế',
      );
    },
  );

  testWidgets(
    'new pin without labels clears stale fields instead of keeping previous location',
    (tester) async {
      await openForm(tester);
      await returnPin(tester, mapped);
      await returnPin(
        tester,
        const PlaceSearchResult(
          id: 'empty-pin',
          name: '',
          formattedAddress: '',
          latitude: 20,
          longitude: 106,
        ),
      );
      expect(field(tester, 'Tên địa điểm').controller!.text, isEmpty);
      expect(field(tester, 'Địa chỉ chi tiết').controller!.text, isEmpty);
      expect(dropdown(tester, 'Tỉnh hoặc thành phố').initialValue, isNull);
      expect(dropdown(tester, 'Phường hoặc xã').initialValue, isNull);
      expect(field(tester, 'Vĩ độ').controller!.text, '20.0');
      expect(places.writes, 0);
    },
  );

  testWidgets(
    'reconfirming same pin and changing dataset preserve manually edited text',
    (tester) async {
      await openForm(tester);
      await returnPin(tester, mapped);
      field(tester, 'Tên địa điểm').controller!.text = 'Tên tự đặt';
      field(tester, 'Địa chỉ chi tiết').controller!.text = 'Cổng vào phía Nam';
      await tester.pumpAndSettle();
      await returnPin(tester, mapped);
      expect(field(tester, 'Tên địa điểm').controller!.text, 'Tên tự đặt');
      expect(
        field(tester, 'Địa chỉ chi tiết').controller!.text,
        'Cổng vào phía Nam',
      );
      tester
          .widget<AppChoiceChips<AdministrativeDivisionVersion>>(
            find.byType(AppChoiceChips<AdministrativeDivisionVersion>),
          )
          .onChanged(AdministrativeDivisionVersion.beforeMerger);
      await tester.pumpAndSettle();
      expect(field(tester, 'Tên địa điểm').controller!.text, 'Tên tự đặt');
      expect(
        field(tester, 'Địa chỉ chi tiết').controller!.text,
        'Cổng vào phía Nam',
      );
    },
  );

  testWidgets('map selection fills address; changing province blocks save', (
    tester,
  ) async {
    await openForm(tester);
    await returnPin(tester, mapped);
    expect(dropdown(tester, 'Tỉnh hoặc thành phố').initialValue, 1);
    expect(dropdown(tester, 'Phường hoặc xã').initialValue, 3);
    expect(find.byType(CheckboxListTile), findsNothing);
    final detail = tester.widget<CustomTextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomTextField && widget.label == 'Địa chỉ chi tiết',
      ),
    );
    expect(detail.controller!.text, 'Lê Thái Tổ');

    dropdown(tester, 'Tỉnh hoặc thành phố').onChanged!(46);
    await tester.pumpAndSettle();
    dropdown(tester, 'Phường hoặc xã').onChanged!(5);
    await tester.pumpAndSettle();
    expect(find.textContaining('không khớp bản đồ'), findsOneWidget);
    await tester.tap(find.widgetWithText(CustomButton, 'Thêm địa điểm'));
    await tester.pumpAndSettle();
    expect(places.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing map labels require explicit confirmation, reset on address change',
    (tester) async {
      await openForm(tester);
      await returnPin(
        tester,
        const PlaceSearchResult(
          id: 'unknown',
          name: 'Điểm thử',
          formattedAddress: '',
          latitude: 21,
          longitude: 105,
        ),
      );
      expect(dropdown(tester, 'Tỉnh hoặc thành phố').initialValue, isNull);
      dropdown(tester, 'Tỉnh hoặc thành phố').onChanged!(1);
      await tester.pumpAndSettle();
      dropdown(tester, 'Phường hoặc xã').onChanged!(3);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CustomButton, 'Thêm địa điểm'));
      await tester.pumpAndSettle();
      expect(places.writes, 0);
      expect(
        find.textContaining('Vui lòng kiểm tra và xác nhận'),
        findsOneWidget,
      );
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged!(
        true,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      dropdown(tester, 'Phường hoặc xã').onChanged!(4);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged!(
        true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CustomButton, 'Thêm địa điểm'));
      await tester.pumpAndSettle();
      expect(places.writes, 1);
    },
  );

  testWidgets(
    'switching to pre-merger dataset re-matches the district and ward',
    (tester) async {
      await openForm(tester);
      await returnPin(tester, mapped);
      tester
          .widget<AppChoiceChips<AdministrativeDivisionVersion>>(
            find.byType(AppChoiceChips<AdministrativeDivisionVersion>),
          )
          .onChanged(AdministrativeDivisionVersion.beforeMerger);
      await tester.pumpAndSettle();
      expect(dropdown(tester, 'Tỉnh hoặc thành phố').initialValue, 1);
      expect(dropdown(tester, 'Quận hoặc huyện').initialValue, 2);
      expect(dropdown(tester, 'Phường hoặc xã').initialValue, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening existing inconsistent record warns without rewriting stored address',
    (tester) async {
      await openForm(
        tester,
        place: const PlaceModel(
          id: 'existing',
          name: 'Điểm thử',
          destination: 'Thành phố Huế',
          address: 'Phường Thuận Hóa, Thành phố Huế',
          category: 'ATTRACTION',
          priceLevel: 1,
          avgDurationMinutes: 60,
          rating: 0,
          isActive: true,
          latitude: 21.028,
          longitude: 105.852,
        ),
      );
      expect(dropdown(tester, 'Tỉnh hoặc thành phố').initialValue, 46);
      expect(find.textContaining('không khớp bản đồ'), findsOneWidget);
      await tester.tap(find.widgetWithText(CustomButton, 'Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(places.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'matching address can be saved using the unchanged places payload',
    (tester) async {
      await openForm(tester);
      await returnPin(tester, mapped);
      await tester.tap(find.widgetWithText(CustomButton, 'Thêm địa điểm'));
      await tester.pumpAndSettle();
      expect(places.writes, 1);
      expect(places.savedData!.destination, 'Thành phố Hà Nội');
      expect(
        places.savedData!.address,
        'Lê Thái Tổ, Phường Hoàn Kiếm, Thành phố Hà Nội',
      );
      expect(places.savedData!.latitude, 21.028);
      expect(places.savedData!.longitude, 105.852);
      expect(tester.takeException(), isNull);
    },
  );
}
