import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/features/review/models/trip_reviews_model.dart';
import 'package:feeling_trip/features/review/repositories/trip_reviews_repository.dart';

const tripId = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> payload({
  int page = 1,
  int count = 2,
  List<Object>? items,
}) => {
  'tripId': tripId,
  'averageRating': count == 0 ? 0 : 4.5,
  'reviewCount': count,
  'items':
      items ??
      [
        <String, dynamic>{
          'id': 'review',
          'tripId': tripId,
          'rating': 5,
          'comment': 'Lịch trình tốt',
          'createdAt': '2026-10-15T00:00:00Z',
          'reviewer': {
            'id': 'author',
            'displayName': 'Tác giả',
            'avatarUrl': null,
          },
        },
      ],
  'pagination': {
    'page': page,
    'limit': 20,
    'total': count,
    'totalPages': (count / 20).ceil(),
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'}),
  );

  test('parses review, safe author, summary, timestamp and pagination', () {
    final result = TripReviewsPage.fromJson(payload());
    expect(result.reviewCount, 2);
    expect(result.averageRating, 4.5);
    expect(result.items.single.reviewer.displayName, 'Tác giả');
    expect(result.items.single.createdAt, DateTime.utc(2026, 10, 15));
    expect(result.items.single.comment, 'Lịch trình tốt');
    expect(result.hasMore, false);
    final next = TripReviewsPage.fromJson(payload(count: 21));
    expect(next.hasMore, true);
  });

  test('empty and beyond-last page have safe successful models', () {
    final empty = TripReviewsPage.fromJson(payload(count: 0, items: []));
    expect(empty.items, isEmpty);
    expect(empty.averageRating, 0);
    expect(empty.hasMore, false);
    final beyond = TripReviewsPage.fromJson(payload(page: 3, items: []));
    expect(beyond.items, isEmpty);
    expect(beyond.reviewCount, 2);
    expect(beyond.hasMore, false);
  });

  test('rating-only review with null comment is preserved', () {
    final data = payload();
    (data['items'] as List).single['comment'] = null;
    expect(TripReviewsPage.fromJson(data).items.single.comment, isNull);
  });

  test('rejects wrong trip, invalid rating, malformed dates and summary', () {
    final wrong = payload();
    (wrong['items'] as List).single['tripId'] = 'other';
    expect(() => TripReviewsPage.fromJson(wrong), throwsFormatException);
    final invalid = payload();
    (invalid['items'] as List).single['rating'] = 6;
    expect(() => TripReviewsPage.fromJson(invalid), throwsFormatException);
    final date = payload();
    (date['items'] as List).single['createdAt'] = 'bad';
    expect(() => TripReviewsPage.fromJson(date), throwsFormatException);
    expect(
      () => TripReviewsPage.fromJson({...payload(), 'averageRating': 'NaN'}),
      throwsFormatException,
    );
    expect(
      () => TripReviewsPage.fromJson({...payload(), 'reviewCount': 0}),
      throwsFormatException,
    );
  });

  test(
    'repository GETs original source ID, pagination and logged-in token',
    () async {
      final previous = ApiClient.client;
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, endsWith('/reviews/trip/$tripId'));
        expect(request.url.queryParameters, {'page': '2', 'limit': '20'});
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({'data': payload(page: 2, items: [])}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      ApiClient.client = mock;
      addTearDown(() {
        ApiClient.client = previous;
        mock.close();
      });
      final result = await ApiTripReviewsRepository().getTripReviews(
        tripId,
        page: 2,
      );
      expect(result.reviewCount, 2);
      expect(result.page, 2);
    },
  );

  test('invalid input never makes a request', () async {
    final previous = ApiClient.client;
    final mock = MockClient((_) async => throw StateError('Must not request'));
    ApiClient.client = mock;
    addTearDown(() {
      ApiClient.client = previous;
      mock.close();
    });
    final repo = ApiTripReviewsRepository();
    await expectLater(repo.getTripReviews(' '), throwsArgumentError);
    await expectLater(
      repo.getTripReviews(tripId, page: 0),
      throwsArgumentError,
    );
    await expectLater(
      repo.getTripReviews(tripId, limit: 51),
      throwsArgumentError,
    );
  });

  test(
    '401 and inaccessible trip 404 remain errors, not empty reviews',
    () async {
      final previous = ApiClient.client;
      var status = 401;
      final mock = MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Không được truy cập'}),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      ApiClient.client = mock;
      addTearDown(() {
        ApiClient.client = previous;
        mock.close();
      });
      for (final code in [401, 404]) {
        status = code;
        await expectLater(
          ApiTripReviewsRepository().getTripReviews(tripId),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              code,
            ),
          ),
        );
      }
    },
  );

  test(
    'repository refuses missing data and another trip/page response',
    () async {
      final previous = ApiClient.client;
      Map<String, dynamic>? data;
      final mock = MockClient(
        (_) async => http.Response(jsonEncode({'data': data}), 200),
      );
      ApiClient.client = mock;
      addTearDown(() {
        ApiClient.client = previous;
        mock.close();
      });
      await expectLater(
        ApiTripReviewsRepository().getTripReviews(tripId),
        throwsFormatException,
      );
      data = {...payload(), 'tripId': 'other', 'items': []};
      await expectLater(
        ApiTripReviewsRepository().getTripReviews(tripId),
        throwsFormatException,
      );
      data = payload(page: 2, items: []);
      await expectLater(
        ApiTripReviewsRepository().getTripReviews(tripId),
        throwsFormatException,
      );
    },
  );
}
