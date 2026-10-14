import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/review/models/review_model.dart';
import 'package:feeling_trip/features/review/models/sos_model.dart';
import 'package:feeling_trip/features/review/repositories/review_repository.dart';
import 'package:feeling_trip/features/review/repositories/sos_repository.dart';
import 'package:feeling_trip/features/review/viewmodels/sos_viewmodel.dart';
import 'package:feeling_trip/features/review/views/sos_screen.dart';
import 'package:feeling_trip/features/trip/models/trip_model.dart';
import 'package:feeling_trip/features/trip/repositories/mock_trip_repository.dart';
import 'package:feeling_trip/features/trip/views/trip_detail_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

SosLocation gps({int secondsOld = 0}) => SosLocation(
  latitude: 21,
  longitude: 105,
  accuracy: 15,
  capturedAt: DateTime.now().subtract(Duration(seconds: secondsOld)),
);
SosAlert alert([String status = 'ACTIVE']) =>
    SosAlert(id: 'sos-one', status: status, latitude: 21, longitude: 105);

class FakeSos extends SosRepository {
  SosAlert? current;
  bool readFails = false, createFails = false;
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<SosAlert?> getActive(String tripId) async {
    if (readFails) throw Exception('offline');
    return current?.isActive == true ? current : null;
  }

  @override
  Future<SosAlert> create({
    required String tripId,
    required SosLocation location,
    required String message,
  }) async {
    writes++;
    await gate?.future;
    current = alert();
    if (createFails) throw Exception('lost acknowledgement');
    return current!;
  }

  @override
  Future<SosAlert> finish(String id, String status) async =>
      current = alert(status);
}

class FakeContacts extends Fake implements ReviewRepository {
  bool fails = false;
  List<EmergencyContactModel> contacts = [
    const EmergencyContactModel(
      id: 'c',
      fullName: 'Người thân',
      phone: '0912345678',
    ),
  ];
  @override
  Future<List<EmergencyContactModel>> getEmergencyContacts() async {
    if (fails) throw Exception('offline');
    return contacts;
  }
}

class TripRepo extends MockTripRepository {
  TripRepo(this.status, [this.membership = 'ACTIVE']);
  final String status, membership;
  @override
  Future<TripModel> getTripById(String id) async => TripModel(
    id: id,
    name: 'Chuyến thử',
    destination: 'Hà Nội',
    startDate: DateTime(2026, 10, 14),
    endDate: DateTime(2026, 10, 16),
    estimatedBudget: 0,
    privacyType: 'PUBLIC',
    status: status,
    membershipStatus: membership,
  );
}

Future<void> press(WidgetTester tester, String label) async {
  final target = find.widgetWithText(CustomButton, label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  SosViewModel vm, {
  Future<bool> Function(Uri)? opener,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: SosScreen(
        tripId: 'trip',
        tripName: 'Chuyến thử',
        viewModel: vm,
        openUrl: opener,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('stale or invalid GPS cannot be used as current location', () {
    expect(gps().isFresh, isTrue);
    expect(gps(secondsOld: 180).isFresh, isFalse);
    expect(
      SosLocation(
        latitude: 100,
        longitude: 105,
        accuracy: 10,
        capturedAt: DateTime.now(),
      ).isFresh,
      isFalse,
    );
  });
  test(
    'load recovers existing SOS and never auto-locates or creates',
    () async {
      final repo = FakeSos()..current = alert();
      var located = 0;
      final vm = SosViewModel(
        tripId: 'trip',
        repository: repo,
        contactsRepository: FakeContacts(),
        locate: () async {
          located++;
          return gps();
        },
      );
      addTearDown(vm.dispose);
      await vm.load();
      expect(vm.alert!.isActive, isTrue);
      expect(located, 0);
      expect(await vm.create('help'), isFalse);
      expect(repo.writes, 0);
    },
  );
  test('GPS failure leaves contacts available for direct calls', () async {
    final vm = SosViewModel(
      tripId: 'trip',
      repository: FakeSos(),
      contactsRepository: FakeContacts(),
      locate: () async =>
          throw const FormatException('Quyền vị trí bị từ chối'),
    );
    addTearDown(vm.dispose);
    await vm.load();
    await vm.locate();
    expect(vm.error, contains('từ chối'));
    expect(vm.contacts, hasLength(1));
    expect(vm.location, isNull);
  });
  test('missing contacts do not prevent recording SOS', () async {
    final repo = FakeSos();
    final vm = SosViewModel(
      tripId: 'trip',
      repository: repo,
      contactsRepository: FakeContacts()..fails = true,
      locate: () async => gps(),
    );
    addTearDown(vm.dispose);
    await vm.load();
    await vm.locate();
    expect(await vm.create('help'), isTrue);
    expect(vm.contactsError, isNotNull);
  });
  test(
    'unknown active status blocks duplicate saves but not contact retrieval',
    () async {
      final repo = FakeSos()..readFails = true;
      final vm = SosViewModel(
        tripId: 'trip',
        repository: repo,
        contactsRepository: FakeContacts(),
        locate: () async => gps(),
      );
      addTearDown(vm.dispose);
      await vm.load();
      await vm.locate();
      expect(await vm.create('help'), isFalse);
      expect(repo.writes, 0);
      expect(vm.contacts, hasLength(1));
    },
  );
  test(
    'double submit is guarded and failed acknowledgement recovers saved SOS',
    () async {
      final repo = FakeSos()
        ..gate = Completer<void>()
        ..createFails = true;
      final vm = SosViewModel(
        tripId: 'trip',
        repository: repo,
        contactsRepository: FakeContacts(),
        locate: () async => gps(),
      );
      addTearDown(vm.dispose);
      await vm.load();
      await vm.locate();
      final first = vm.create('help');
      expect(await vm.create('help'), isFalse);
      repo.gate!.complete();
      expect(await first, isTrue);
      expect(repo.writes, 1);
      expect(vm.alert!.isActive, isTrue);
    },
  );
  test('resolve and false alarm use server response', () async {
    final repo = FakeSos()..current = alert();
    final vm = SosViewModel(
      tripId: 'trip',
      repository: repo,
      contactsRepository: FakeContacts(),
    );
    addTearDown(vm.dispose);
    await vm.load();
    await vm.finish('RESOLVED');
    expect(vm.alert!.status, 'RESOLVED');
    repo.current = alert();
    await vm.load();
    await vm.finish('FALSE_ALARM');
    expect(vm.alert!.status, 'FALSE_ALARM');
  });
  test('location callback completing after dispose is harmless', () async {
    final location = Completer<SosLocation>();
    final vm = SosViewModel(tripId: 'trip', locate: () => location.future);
    final work = vm.locate();
    vm.dispose();
    location.complete(gps());
    await work;
  });
  test(
    'API uses own active SOS endpoint and refuses invalid closing status',
    () async {
      SharedPreferences.setMockInitialValues({});
      final previous = ApiClient.client;
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, endsWith('/reviews/sos/active'));
        expect(request.url.queryParameters['tripId'], 'trip');
        return http.Response(jsonEncode({'data': null}), 200);
      });
      ApiClient.client = mock;
      addTearDown(() {
        mock.close();
        ApiClient.client = previous;
      });
      expect(await ApiSosRepository().getActive('trip'), isNull);
      await expectLater(
        ApiSosRepository().finish('id', 'ACTIVE'),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'opening screen does not request GPS or send SOS; cancel confirmation does nothing',
    (tester) async {
      final repo = FakeSos();
      var fixes = 0;
      final vm = SosViewModel(
        tripId: 'trip',
        repository: repo,
        contactsRepository: FakeContacts(),
        locate: () async {
          fixes++;
          return gps();
        },
      );
      addTearDown(vm.dispose);
      await mount(tester, vm);
      expect(fixes, 0);
      expect(repo.writes, 0);
      await press(tester, 'Lấy vị trí hiện tại');
      await press(tester, 'Ghi nhận SOS trên hệ thống');
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      expect(fixes, 1);
    },
  );
  testWidgets(
    'save confirmation and resolve are explicit, not fake delivery success',
    (tester) async {
      final vm = SosViewModel(
        tripId: 'trip',
        repository: FakeSos(),
        contactsRepository: FakeContacts(),
        locate: () async => gps(),
      );
      addTearDown(vm.dispose);
      await mount(tester, vm);
      await press(tester, 'Lấy vị trí hiện tại');
      await press(tester, 'Ghi nhận SOS trên hệ thống');
      await tester.tap(find.text('Ghi nhận SOS'));
      await tester.pumpAndSettle();
      expect(
        find.text('SOS đã ghi nhận · chưa xác nhận gửi cho người thân'),
        findsOneWidget,
      );
      await press(tester, 'Tôi đã an toàn');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Đã xác nhận an toàn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'SMS only opens composer with encoded location; no alert created automatically',
    (tester) async {
      final repo = FakeSos();
      final uris = <Uri>[];
      final vm = SosViewModel(
        tripId: 'trip',
        repository: repo,
        contactsRepository: FakeContacts(),
        locate: () async => gps(),
      );
      addTearDown(vm.dispose);
      await mount(
        tester,
        vm,
        opener: (uri) async {
          uris.add(uri);
          return true;
        },
      );
      await press(tester, 'Lấy vị trí hiện tại');
      await tester.enterText(find.byType(TextFormField), 'Cần giúp & hỗ trợ');
      await tester.pump();
      await press(tester, 'Soạn SMS cho Người thân');
      expect(uris.single.scheme, 'sms');
      expect(uris.single.path, '0912345678');
      expect(
        uris.single.queryParameters['body'],
        contains('Cần giúp & hỗ trợ'),
      );
      expect(
        uris.single.queryParameters['body'],
        contains('https://www.google.com/maps/search/'),
      );
      expect(repo.writes, 0);
      expect(
        find.textContaining('chưa xác nhận người nhận đã nhận'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'unsupported phone handler shows fallback without success claim',
    (tester) async {
      final vm = SosViewModel(
        tripId: 'trip',
        repository: FakeSos(),
        contactsRepository: FakeContacts(),
      );
      addTearDown(vm.dispose);
      await mount(tester, vm, opener: (_) async => false);
      await press(tester, 'Gọi Người thân');
      expect(
        find.textContaining('Thiết bị không mở được ứng dụng này'),
        findsOneWidget,
      );
    },
  );
  for (final status in ['UPCOMING', 'ONGOING', 'COMPLETED', 'CANCELLED']) {
    testWidgets('SOS entry visibility for trip $status', (tester) async {
      final auth = AuthViewModel();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        AuthScope(
          auth: auth,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: TripDetailScreen(
              tripId: 'trip',
              repository: TripRepo(status),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('SOS'),
        status == 'ONGOING' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
