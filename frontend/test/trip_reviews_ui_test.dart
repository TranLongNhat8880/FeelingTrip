import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/itinerary/models/itinerary_model.dart';
import 'package:feeling_trip/features/itinerary/repositories/mock_itinerary_repository.dart';
import 'package:feeling_trip/features/itinerary/views/public_itineraries_screen.dart';
import 'package:feeling_trip/features/profile/views/public_profile_screen.dart';
import 'package:feeling_trip/features/review/models/trip_reviews_model.dart';
import 'package:feeling_trip/features/review/repositories/trip_reviews_repository.dart';
import 'package:feeling_trip/features/review/viewmodels/trip_reviews_viewmodel.dart';
import 'package:feeling_trip/features/review/views/widgets/trip_reviews_section.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

const sourceId = 'source-trip';
const planSummary = PublicItinerarySummary(
  sourceTripId: sourceId,
  name: 'Lịch trình đã hoàn thành',
  destination: 'Hà Nội',
  durationDays: 1,
  averageRating: 4.5,
  reviewCount: 2,
  cloneCount: 3,
);

TripReviewItem review(
  String id, {
  String tripId = sourceId,
  String? comment = 'Nhận xét chuyến đi',
  String name = 'Tác giả đánh giá',
}) => TripReviewItem(
  id: id,
  tripId: tripId,
  rating: 4,
  comment: comment,
  createdAt: DateTime(2026, 10, 15, 10, 30),
  reviewer: TripReviewAuthor(id: 'author-$id', displayName: name),
);

TripReviewsPage pageOf({
  int page = 1,
  int count = 1,
  List<TripReviewItem>? items,
  String tripId = sourceId,
}) => TripReviewsPage(
  tripId: tripId,
  averageRating: count == 0 ? 0 : 4.5,
  reviewCount: count,
  items: items ?? [review('1', tripId: tripId)],
  page: page,
  limit: 20,
  totalPages: (count / 20).ceil(),
);

class Reviews extends Fake implements TripReviewsRepository {
  final calls = <({String tripId, int page})>[];
  TripReviewsPage first = pageOf();
  TripReviewsPage next = pageOf(page: 2, count: 21, items: [review('2')]);
  Object? failure;
  Completer<TripReviewsPage>? gate;
  @override
  Future<TripReviewsPage> getTripReviews(
    String tripId, {
    int page = 1,
    int limit = 20,
  }) async {
    calls.add((tripId: tripId, page: page));
    if (failure != null) throw failure!;
    if (gate != null) return await gate!.future;
    return page == 1 ? first : next;
  }
}

class Plans extends MockItineraryRepository {
  final clonedSources = <String>[];
  @override
  Future<PublicItineraryPage> getPublicPlans({
    String? destination,
    int? durationDays,
    String? keyword,
  }) async => const PublicItineraryPage(items: [planSummary], total: 1);
  @override
  Future<PublicItineraryDetail> getPublicPlan(String sourceTripId) async =>
      const PublicItineraryDetail(
        summary: planSummary,
        days: [
          PublicItineraryDay(
            dayNumber: 1,
            title: 'Ngày tham quan',
            items: [
              PublicItineraryItem(
                customName: 'Điểm tham quan thử',
                category: 'ATTRACTION',
                startTime: '08:00',
                endTime: '09:00',
              ),
            ],
          ),
        ],
      );
  @override
  Future<ItineraryPlan> clonePlan(
    String sourceTripId, {
    required DateTime startDate,
    String? name,
  }) async {
    clonedSources.add(sourceTripId);
    return super.clonePlan(sourceTripId, startDate: startDate, name: name);
  }
}

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: child));
  await tester.pumpAndSettle();
}

Widget section(Reviews repo, {String id = sourceId}) => AppScaffold(
  title: 'Lịch trình',
  scrollable: true,
  body: TripReviewsSection(sourceTripId: id, repository: repo),
);

Future<void> press(WidgetTester tester, String label) async {
  final button = find.widgetWithText(CustomButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'pagination deduplicates and refresh replaces instead of appending',
    () async {
      final repo = Reviews()
        ..first = pageOf(count: 21)
        ..next = pageOf(page: 2, count: 21, items: [review('1'), review('2')]);
      final vm = TripReviewsViewModel(tripId: sourceId, repository: repo);
      addTearDown(vm.dispose);
      await vm.load();
      await vm.load(more: true);
      expect(vm.items.map((x) => x.id), ['1', '2']);
      expect(vm.hasMore, false);
      await vm.load(more: true);
      expect(repo.calls.length, 2);
      repo.first = pageOf(items: [review('new')]);
      await vm.load();
      expect(vm.items.single.id, 'new');
      expect(repo.calls.map((x) => x.page), [1, 2, 1]);
    },
  );

  test(
    'failed load-more retains comments; retry requests the failed page',
    () async {
      final repo = Reviews()..first = pageOf(count: 21);
      final vm = TripReviewsViewModel(tripId: sourceId, repository: repo);
      addTearDown(vm.dispose);
      await vm.load();
      repo.failure = Exception('offline');
      await vm.load(more: true);
      expect(vm.items.single.id, '1');
      expect(vm.error, isNotNull);
      repo.failure = null;
      await vm.retry();
      expect(repo.calls.map((x) => x.page), [1, 2, 2]);
      expect(vm.error, isNull);
      expect(vm.items.length, 2);
    },
  );

  test(
    'permission failure clears cached reviews rather than revealing private data',
    () async {
      for (final status in [401, 403, 404]) {
        final repo = Reviews();
        final vm = TripReviewsViewModel(tripId: sourceId, repository: repo);
        await vm.load();
        repo.failure = ApiException(statusCode: status, message: 'No access');
        await vm.load();
        expect(vm.items, isEmpty);
        expect(vm.summary, isNull);
        expect(vm.error, isNotNull);
        vm.dispose();
      }
    },
  );

  test('duplicate load ignored; disposal before completion is safe', () async {
    final repo = Reviews()..gate = Completer<TripReviewsPage>();
    final vm = TripReviewsViewModel(tripId: sourceId, repository: repo);
    final pending = vm.load();
    await vm.load();
    expect(repo.calls.length, 1);
    vm.dispose();
    repo.gate!.complete(pageOf());
    await pending;
  });

  test('wrong source response is rejected', () async {
    final repo = Reviews()..first = pageOf(tripId: 'other');
    final vm = TripReviewsViewModel(tripId: sourceId, repository: repo);
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.items, isEmpty);
    expect(vm.error, isNotNull);
  });

  for (final size in [const Size(320, 740), const Size(1280, 900)]) {
    testWidgets('reviews and rating-only cards fit $size', (tester) async {
      final repo = Reviews()
        ..first = pageOf(
          count: 2,
          items: [
            review('1', name: 'Tên tác giả rất dài để kiểm tra màn hình nhỏ'),
            review('2', comment: null),
          ],
        );
      await mount(tester, section(repo), size: size);
      expect(find.text('Đánh giá chuyến đi'), findsOneWidget);
      expect(find.text('4.5/5'), findsOneWidget);
      expect(find.text('2 lượt đánh giá'), findsOneWidget);
      expect(find.text('Nhận xét chuyến đi'), findsOneWidget);
      expect(
        find.text('Người dùng chỉ chấm sao, không viết nhận xét.'),
        findsOneWidget,
      );
      expect(find.text('15/10/2026 10:30'), findsNWidgets(2));
      expect(find.text('Xem thêm đánh giá'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty result is different from failure; retry recovers', (
    tester,
  ) async {
    final repo = Reviews()..failure = Exception('offline');
    await mount(tester, section(repo));
    expect(find.text('Chưa có đánh giá'), findsNothing);
    expect(find.text('Thử tải lại đánh giá'), findsOneWidget);
    repo.failure = null;
    repo.first = pageOf(count: 0, items: []);
    await press(tester, 'Thử tải lại đánh giá');
    expect(find.text('Chưa có đánh giá'), findsOneWidget);
    expect(find.text('0.0/5'), findsNothing);
    expect(find.text('Thử tải lại đánh giá'), findsNothing);
  });

  testWidgets('load-more button appends reviews and then disappears', (
    tester,
  ) async {
    final repo = Reviews()..first = pageOf(count: 21);
    await mount(tester, section(repo));
    await press(tester, 'Xem thêm đánh giá');
    expect(repo.calls.map((x) => x.page), [1, 2]);
    expect(find.text('Nhận xét chuyến đi'), findsNWidgets(2));
    expect(find.text('Xem thêm đánh giá'), findsNothing);
      expect(find.text('Đang hiển thị 2/21 đánh giá'), findsOneWidget);
  });

  testWidgets('changing source does not show old comments or late responses', (
    tester,
  ) async {
    final old = Reviews()..gate = Completer<TripReviewsPage>();
    final next = Reviews()
      ..first = pageOf(
        tripId: 'new-trip',
        items: [review('new', tripId: 'new-trip', comment: 'Nhận xét mới')],
      );
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: section(old)),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: section(next, id: 'new-trip'),
      ),
    );
    await tester.pumpAndSettle();
    old.gate!.complete(pageOf());
    await tester.pumpAndSettle();
    expect(find.text('Nhận xét mới'), findsOneWidget);
    expect(find.text('Nhận xét chuyến đi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'author opens the correct public profile and returns to reviews',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previous = ApiClient.client;
      final requests = <String>[];
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, endsWith('/users/trust-score/author-1'));
        requests.add(request.url.pathSegments.last);
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'author-1',
              'fullName': 'Hồ sơ tác giả',
              'isVerified': false,
              'trustScore': 0,
              'reviewCount': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      ApiClient.client = mock;
      addTearDown(() {
        ApiClient.client = previous;
        mock.close();
      });
      await mount(tester, section(Reviews()));
      await tester.tap(find.text('Tác giả đánh giá'));
      await tester.pumpAndSettle();
      expect(find.byType(PublicProfileScreen), findsOneWidget);
      expect(requests, ['author-1']);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Nhận xét chuyến đi'), findsOneWidget);
    },
  );

  testWidgets(
    'community list opens source reviews and leaves clone form available',
    (tester) async {
      final plans = Plans();
      final reviews = Reviews();
      await mount(
        tester,
        PublicItinerariesScreen(repository: plans, reviewsRepository: reviews),
      );
      final title = find.text(planSummary.name);
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.byType(PublicItineraryDetailScreen), findsOneWidget);
      expect(find.text('Điểm tham quan thử'), findsOneWidget);
      expect(reviews.calls.single.tripId, sourceId);
      expect(find.byType(TripReviewsSection), findsOneWidget);
      await press(tester, 'Sử dụng lịch trình này');
      expect(find.text('Tên chuyến đi mới'), findsOneWidget);
      expect(find.text('Sao chép chuyến đi'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(plans.clonedSources, isEmpty);
      expect(find.byType(PublicItineraryDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reviews failure does not disable itinerary or clone action', (
    tester,
  ) async {
    await mount(
      tester,
      PublicItineraryDetailScreen(
        summary: planSummary,
        repository: Plans(),
        reviewsRepository: Reviews()..failure = Exception('offline'),
      ),
    );
    expect(find.text('Điểm tham quan thử'), findsOneWidget);
    expect(find.text('Thử tải lại đánh giá'), findsOneWidget);
    final clone = tester.widget<CustomButton>(
      find.widgetWithText(CustomButton, 'Sử dụng lịch trình này'),
    );
    expect(clone.onPressed, isNotNull);
  });
}
