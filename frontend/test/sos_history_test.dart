import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/review/models/sos_model.dart';
import 'package:feeling_trip/features/review/repositories/sos_repository.dart';
import 'package:feeling_trip/features/review/viewmodels/sos_history_viewmodel.dart';
import 'package:feeling_trip/features/review/views/sos_history_screen.dart';
import 'package:feeling_trip/features/review/views/sos_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

SosAlert record(String id, [String status = 'ACTIVE']) => SosAlert(
  id: id,
  status: status,
  latitude: 21,
  longitude: 105,
  tripId: 'trip',
  tripName: 'Chuyến đã kết thúc',
  message: 'Cần hỗ trợ $id',
  createdAt: DateTime(2026, 10, 14, 10),
  resolvedAt: status == 'ACTIVE' ? null : DateTime(2026, 10, 14, 11),
);

class FakeHistory implements SosHistoryRepository {
  final offsets = <int>[];
  bool fail = false;
  Completer<SosHistoryPage>? gate;
  SosHistoryPage page = const SosHistoryPage(items: [], hasMore: false);
  @override
  Future<SosHistoryPage> getHistory({int offset = 0, int limit = 20}) async {
    offsets.add(offset);
    if (fail) throw Exception('offline');
    return gate == null ? page : await gate!.future;
  }
}

Future<void> mount(
  WidgetTester tester,
  SosHistoryViewModel vm, {
  Future<bool> Function(Uri)? openUrl,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: SosHistoryScreen(viewModel: vm, openUrl: openUrl),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('history parses saved dates and map without requesting current GPS', () {
    final item = SosAlert.fromJson({
      'id': 's',
      'status': 'RESOLVED',
      'latitude': '21',
      'longitude': '105',
      'createdAt': '2026-10-14T03:00:00Z',
      'resolvedAt': '2026-10-14T04:00:00Z',
      'tripId': null,
      'tripName': null,
    });
    expect(item.resolvedAt, DateTime.utc(2026, 10, 14, 4));
    expect(item.mapUrl.queryParameters['query'], '21.0,105.0');
  });

  test('history load more and refresh paginate and deduplicate', () async {
    final repo = FakeHistory()
      ..page = SosHistoryPage(items: [record('1'), record('2')], hasMore: true);
    final vm = SosHistoryViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.load();
    repo.page = SosHistoryPage(
      items: [record('2'), record('3', 'RESOLVED')],
      hasMore: false,
    );
    await vm.load(more: true);
    expect(repo.offsets, [0, 2]);
    expect(vm.items.map((x) => x.id), ['1', '2', '3']);
    await vm.load(more: true);
    expect(repo.offsets.length, 2);
    repo.page = const SosHistoryPage(items: [], hasMore: false);
    await vm.load();
    expect(repo.offsets.last, 0);
    expect(vm.items, isEmpty);
  });

  test('page error retains records and retries the same offset', () async {
    final repo = FakeHistory()
      ..page = SosHistoryPage(items: [record('1')], hasMore: true);
    final vm = SosHistoryViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.load();
    repo.fail = true;
    await vm.load(more: true);
    expect(vm.items.single.id, '1');
    expect(vm.error, isNotNull);
    repo.fail = false;
    repo.page = SosHistoryPage(
      items: [record('2', 'FALSE_ALARM')],
      hasMore: false,
    );
    await vm.load(more: true);
    expect(repo.offsets, [0, 1, 1]);
    expect(vm.error, isNull);
  });

  test(
    'concurrent load ignored and disposed async completion is safe',
    () async {
      final repo = FakeHistory()..gate = Completer<SosHistoryPage>();
      final vm = SosHistoryViewModel(repository: repo);
      final loading = vm.load();
      await vm.load();
      expect(repo.offsets, [0]);
      vm.dispose();
      repo.gate!.complete(const SosHistoryPage(items: [], hasMore: false));
      await loading;
    },
  );

  test('API history is read-only and does not send another user ID', () async {
    SharedPreferences.setMockInitialValues({});
    final previous = ApiClient.client;
    var invalid = false;
    final mock = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/reviews/sos/history'));
      expect(request.url.queryParameters, {'offset': '20', 'limit': '20'});
      return http.Response(
        jsonEncode({
          'data': invalid
              ? {}
              : {
                  'items': [
                    {
                      'id': 's',
                      'status': 'FALSE_ALARM',
                      'latitude': 21,
                      'longitude': 105,
                    },
                  ],
                  'hasMore': false,
                },
        }),
        200,
      );
    });
    ApiClient.client = mock;
    addTearDown(() {
      ApiClient.client = previous;
      mock.close();
    });
    expect(
      (await ApiSosRepository().getHistory(offset: 20)).items.single.status,
      'FALSE_ALARM',
    );
    invalid = true;
    await expectLater(
      ApiSosRepository().getHistory(offset: 20),
      throwsFormatException,
    );
  });

  testWidgets('empty history and failed load are distinct; retry works', (
    tester,
  ) async {
    final repo = FakeHistory()..fail = true;
    final vm = SosHistoryViewModel(repository: repo);
    addTearDown(vm.dispose);
    await mount(tester, vm);
    expect(find.text('Chưa có lịch sử SOS'), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch sử SOS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all statuses, saved message/times and snapshot map on narrow screen',
    (tester) async {
      for (final status in ['ACTIVE', 'RESOLVED', 'FALSE_ALARM']) {
        final repo = FakeHistory()
          ..page = SosHistoryPage(
            items: [record('saved', status)],
            hasMore: false,
          );
        final vm = SosHistoryViewModel(repository: repo);
        Uri? opened;
        await mount(
          tester,
          vm,
          openUrl: (uri) async {
            opened = uri;
            return true;
          },
        );
        expect(find.text('Chuyến đã kết thúc'), findsOneWidget);
        expect(find.text('Cần hỗ trợ saved'), findsOneWidget);
        expect(
          find.text(switch (status) {
            'ACTIVE' => 'Đang cần hỗ trợ',
            'RESOLVED' => 'Đã an toàn',
            _ => 'Báo nhầm',
          }),
          findsOneWidget,
        );
        expect(find.textContaining('Ghi nhận: 14/10/2026'), findsOneWidget);
        if (status != 'ACTIVE') {
          expect(find.textContaining('Kết thúc: 14/10/2026'), findsOneWidget);
        }
        final map = find.widgetWithText(CustomButton, 'Xem vị trí đã lưu');
        await tester.ensureVisible(map);
        await tester.pumpAndSettle();
        await tester.tap(map);
        await tester.pumpAndSettle();
        expect(opened!.queryParameters['query'], '21.0,105.0');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      }
    },
  );

  testWidgets('load more button appends a page', (tester) async {
    final repo = FakeHistory()
      ..page = SosHistoryPage(items: [record('1')], hasMore: true);
    final vm = SosHistoryViewModel(repository: repo);
    addTearDown(vm.dispose);
    await mount(tester, vm);
    repo.page = SosHistoryPage(
      items: [record('2', 'RESOLVED')],
      hasMore: false,
    );
    final more = find.widgetWithText(CustomButton, 'Xem thêm');
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(repo.offsets, [0, 1]);
    expect(vm.items.length, 2);
    expect(find.text('Xem thêm'), findsNothing);
  });

  testWidgets(
    'SOS opens history and returning reloads current state; GET only',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previous = ApiClient.client;
      final paths = <String>[];
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        paths.add(request.url.path);
        final Object? data;
        if (request.url.path.endsWith('/sos/history')) {
          data = {
            'items': [
              {
                'id': 'old',
                'status': 'RESOLVED',
                'latitude': 21,
                'longitude': 105,
                'message': 'SOS đã kết thúc',
                'tripName': 'Chuyến cũ',
              },
            ],
            'hasMore': false,
          };
        } else if (request.url.path.endsWith('/sos/active')) {
          data = null;
        } else if (request.url.path.endsWith('/emergency-contacts')) {
          data = [];
        } else {
          throw StateError('Unexpected endpoint');
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      ApiClient.client = mock;
      addTearDown(() {
        ApiClient.client = previous;
        mock.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SosScreen(tripId: 'trip', tripName: 'Chuyến thử'),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.widgetWithText(CustomButton, 'Lịch sử SOS của tôi');
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(SosHistoryScreen), findsOneWidget);
      expect(find.text('Chuyến cũ'), findsOneWidget);
      expect(find.text('Đã an toàn'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(SosHistoryScreen), findsNothing);
      expect(paths.where((path) => path.endsWith('/sos/active')).length, 2);
      expect(paths.where((path) => path.endsWith('/sos/history')).length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
