import 'dart:convert';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/features/map/repositories/place_search_repository.dart';
import 'package:feeling_trip/features/map/views/place_location_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final originalClient = ApiClient.client;
  setUp(
    () => SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'}),
  );
  tearDown(() {
    ApiClient.client.close();
    ApiClient.client = originalClient;
  });

  http.Response response(Object data) => http.Response(
    jsonEncode({'success': true, 'data': data}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test(
    'configuration is read from the backend with the current session',
    () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/places/geocode/configuration');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.queryParameters.containsKey('apiKey'), isFalse);
        return response({'configured': true});
      });
      expect(await PlaceSearchRepository().isConfigured(), isTrue);
      expect(
        PlaceSearchRepository.tileUrlTemplate,
        contains('/places/geocode/tiles/'),
      );
      expect(PlaceSearchRepository.tileUrlTemplate, isNot(contains('apiKey')));
    },
  );

  test('search uses the backend and skips only malformed results', () async {
    ApiClient.client = MockClient((request) async {
      expect(request.url.path, '/api/v1/places/geocode/search');
      expect(request.url.queryParameters['text'], 'Hồ Hoàn Kiếm');
      return response({
        'features': [
          {
            'properties': {'name': 'Missing coordinates'},
          },
          {
            'properties': {'name': 'Hồ Hoàn Kiếm', 'formatted': 'Hà Nội'},
            'geometry': {
              'coordinates': [105.852, 21.028],
            },
          },
          {
            'properties': {'lat': 200, 'lon': 300},
          },
        ],
      });
    });
    final results = await PlaceSearchRepository().searchPlaces('Hồ Hoàn Kiếm');
    expect(results, hasLength(1));
    expect(results.single.name, 'Hồ Hoàn Kiếm');
  });

  test(
    'reverse lookup keeps the selected pin and validates coordinates',
    () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, '/api/v1/places/geocode/reverse');
        expect(request.url.queryParameters['lat'], '21.028');
        return response({
          'features': [
            {
              'properties': {
                'formatted': 'Hà Nội',
                'country_code': 'vn',
                'state': 'Hà Nội',
                'suburb': 'Phường Hoàn Kiếm',
                'lat': 21.03,
                'lon': 105.86,
              },
            },
          ],
        });
      });
      final repository = PlaceSearchRepository();
      final result = await repository.reverseGeocode(
        latitude: 21.028,
        longitude: 105.852,
      );
      expect(result!.latitude, 21.028);
      expect(result.longitude, 105.852);
      expect(result.mapAddress.province, 'Hà Nội');
      expect(result.mapAddress.suburb, 'Phường Hoàn Kiếm');
      await expectLater(
        repository.reverseGeocode(latitude: 200, longitude: 0),
        throwsA(isA<PlaceSearchException>()),
      );
    },
  );

  test(
    'unavailable backend map configuration produces a readable message',
    () async {
      ApiClient.client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Dịch vụ bản đồ chưa được cấu hình trên máy chủ',
          }),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final repository = PlaceSearchRepository();
      await expectLater(
        repository.searchPlaces('Hà Nội'),
        throwsA(
          isA<PlaceSearchException>().having(
            (error) => error.message,
            'message',
            contains('máy chủ'),
          ),
        ),
      );
    },
  );

  test('a backend without a map key reports unconfigured', () async {
    ApiClient.client = MockClient((request) async {
      return response({'configured': false});
    });

    expect(await PlaceSearchRepository().isConfigured(), isFalse);
  });

  test('short searches do not call the backend', () async {
    ApiClient.client = MockClient((request) async {
      fail('A short search must not make an HTTP request');
    });

    expect(await PlaceSearchRepository().searchPlaces(' H '), isEmpty);
  });

  test(
    'search parses the sanitized backend properties and encodes text',
    () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.queryParameters, {'text': 'Hồ & phố cổ'});
        expect(request.headers['Authorization'], 'Bearer test-token');
        return response({
          'features': [
            {
              'properties': {
                'place_id': 'backend-place',
                'name': 'Hồ Hoàn Kiếm',
                'formatted': 'Hà Nội',
                'lat': 21.028,
                'lon': 105.852,
              },
            },
          ],
        });
      });

      final results = await PlaceSearchRepository().searchPlaces(
        ' Hồ & phố cổ ',
      );
      expect(results.single.id, 'backend-place');
      expect(results.single.latitude, 21.028);
      expect(results.single.longitude, 105.852);
    },
  );

  test('backend permission errors keep their readable message', () async {
    ApiClient.client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Chỉ quản trị viên được truy cập',
        }),
        403,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await expectLater(
      PlaceSearchRepository().isConfigured(),
      throwsA(
        isA<PlaceSearchException>().having(
          (error) => error.message,
          'message',
          contains('quản trị viên'),
        ),
      ),
    );
  });

  testWidgets('unconfigured map offers a backend configuration retry', (
    tester,
  ) async {
    var requests = 0;
    ApiClient.client = MockClient((request) async {
      requests++;
      expect(request.url.path, '/api/v1/places/geocode/configuration');
      return response({'configured': false});
    });

    await tester.pumpWidget(
      const MaterialApp(home: PlaceLocationPickerScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa sẵn sàng trên máy chủ'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(requests, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('configuration connection errors can be retried', (tester) async {
    var requests = 0;
    ApiClient.client = MockClient((request) async {
      if (++requests == 1) {
        throw http.ClientException('Cannot reach backend');
      }
      return response({'configured': false});
    });

    await tester.pumpWidget(
      const MaterialApp(home: PlaceLocationPickerScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa sẵn sàng trên máy chủ'), findsOneWidget);
    expect(requests, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
