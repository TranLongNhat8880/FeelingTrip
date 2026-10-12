import 'dart:io';
import 'package:feeling_trip/features/companion/models/companion_post_model.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/auth/views/auth_gate.dart';
import 'package:feeling_trip/features/admin/views/admin_screen.dart';
import 'package:feeling_trip/features/companion/viewmodels/companion_feed_viewmodel.dart';
import 'package:feeling_trip/features/notification/viewmodels/notification_viewmodel.dart';
import 'package:feeling_trip/features/auth/views/blocked_account_screen.dart';
import 'package:feeling_trip/features/companion/views/widgets/companion_post_card.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['PREVIEW_SCREENSHOTS'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<GlobalKey> mount(WidgetTester tester, String email, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final auth = AuthViewModel();
  await tester.runAsync(() async {
    await auth.restoreSession();
    await auth.login(email, 'demo');
  });
  final key = GlobalKey();
  await tester.pumpWidget(
    AuthScope(
      auth: auth,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AuthGate()),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
  addTearDown(auth.dispose);
  return key;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('Home reserves space for the feed and searches destinations', (
    tester,
  ) async {
    final key = await mount(
      tester,
      'user.ekyc@feelingtrip.com',
      const Size(390, 844),
    );
    expect(find.byTooltip('Đăng bài tìm bạn'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(
      tester.getTopLeft(find.byType(CompanionPostCard).first).dy,
      lessThan(100),
    );
    await capture(tester, key, 'home-mobile');
    await tester.enterText(find.byType(TextField), 'Sapa');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      find.text('Nhóm leo núi Fansipan – Cuối tuần tháng 10'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Bộ lọc'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'feed-filter');
    await tester.tap(find.text('Đặt lại'));
    await tester.tap(find.text('Áp dụng bộ lọc'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Detail keeps destinations, dates, cost, content and members in order',
    (tester) async {
      final key = await mount(
        tester,
        'user.ekyc@feelingtrip.com',
        const Size(390, 844),
      );
      await tester.tap(find.byType(CompanionPostCard).first);
      await tester.pumpAndSettle();
      expect(
        find.text('Tuấn Travel'),
        findsNothing,
      ); // Existing mock uses nickname TuanTravel.
      final location = tester.getTopLeft(find.text('Điểm đến')).dy;
      final time = tester.getTopLeft(find.text('Thời gian')).dy;
      final cost = tester.getTopLeft(find.text('Ngân sách chung của chuyến đi')).dy;
      final content = tester.getTopLeft(find.text('Nội dung')).dy;
      expect(location, lessThan(time));
      expect(time, lessThan(cost));
      expect(cost, lessThan(content));
      await capture(tester, key, 'detail-mobile');
      await tester.tap(find.text('Gửi yêu cầu tham gia'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).last,
        'Mình muốn tham gia cùng nhóm.',
      );
      await tester.tap(find.text('Gửi yêu cầu'));
      await tester.pumpAndSettle();
      expect(find.text('Đã gửi yêu cầu'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CompanionPostCard).first);
      await tester.pumpAndSettle();
      expect(find.text('Đã gửi yêu cầu'), findsOneWidget);
      expect(find.text('Gửi yêu cầu tham gia'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unverified user cannot send a companion join request', (
    tester,
  ) async {
    await mount(tester, 'user.noekyc@feelingtrip.com', const Size(390, 844));
    await tester.tap(find.byType(CompanionPostCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Cần xác minh eKYC để tham gia'), findsOneWidget);
    expect(find.text('Gửi yêu cầu tham gia'), findsNothing);
    await tester.tap(find.text('Cần xác minh eKYC để tham gia'));
    await tester.pumpAndSettle();
    expect(find.text('Lời giới thiệu bản thân *'), findsNothing);
  });

  testWidgets(
    'Notifications default to unread; bulk delete requires confirmation',
    (tester) async {
      final key = await mount(
        tester,
        'user.ekyc@feelingtrip.com',
        const Size(390, 844),
      );
      await tester.tap(find.text('Thông báo').last);
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ của bạn đã được xác minh'), findsNothing);
      expect(find.text('Chưa đọc (2)'), findsOneWidget);
      await capture(tester, key, 'notifications-mobile');
      await tester.tap(find.byTooltip('Thao tác thông báo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá tất cả thông báo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa đọc (2)'), findsOneWidget);
      await tester.tap(find.byTooltip('Thao tác thông báo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
      await tester.pumpAndSettle();
      expect(find.text('Không có thông báo chưa đọc'), findsOneWidget);
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ của bạn đã được xác minh'), findsOneWidget);
      await tester.tap(find.byTooltip('Thao tác thông báo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá tất cả thông báo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá tất cả'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thông báo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unverified user cannot open posting from their trip', (
    tester,
  ) async {
    await mount(tester, 'user.noekyc@feelingtrip.com', const Size(360, 800));
    await tester.tap(find.text('Chuyến đi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm bạn đồng hành').first);
    await tester.pumpAndSettle();
    expect(find.text('Cần xác minh hồ sơ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Posting from a trip returns to a refreshed Home feed', (
    tester,
  ) async {
    final key = await mount(
      tester,
      'user.ekyc@feelingtrip.com',
      const Size(390, 844),
    );
    await tester.tap(find.text('Chuyến đi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm bạn đồng hành').first);
    await tester.pumpAndSettle();
    await capture(tester, key, 'create-post-mobile');
    await tester.enterText(
      find.byType(TextFormField).first,
      'Chuyến đi xem thử của mình',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Cùng khám phá Hội An và chia sẻ chi phí chuyến đi.',
    );
    await tester.tap(find.text('Đăng bài'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(find.text('Chuyến đi xem thử của mình'), findsOneWidget);
    await tester.tap(find.text('Chuyến đi').last);
    await tester.pumpAndSettle();
    expect(find.text('Tìm bạn đồng hành'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('Admin reviews profiles and updates users at $size', (
      tester,
    ) async {
      final key = await mount(tester, 'admin@feelingtrip.com', size);
      expect(find.byType(AdminScreen), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      await capture(
        tester,
        key,
        size.width < 900 ? 'admin-mobile' : 'admin-wide',
      );
      await tester.tap(find.text('Nguyễn Ngọc Anh'));
      await tester.pumpAndSettle();
      await capture(tester, key, 'ekyc-detail-${size.width.toInt()}');
      await tester.tap(find.text('Duyệt hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt hồ sơ').last);
      await tester.pumpAndSettle();
      expect(find.text('1 hồ sơ cần xem xét'), findsOneWidget);
      await tester.tap(find.text('Người dùng'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'thuha');
      await tester.pumpAndSettle();
      expect(find.text('Phạm Thu Hà'), findsOneWidget);
      await tester.tap(find.byTooltip('Thao tác tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở khóa tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở khóa'));
      await tester.pumpAndSettle();
      expect(find.text('Hoạt động'), findsWidgets);
      expect(find.text('Đã khóa'), findsOneWidget); // Filter chip remains.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Admin rejection validates and records a reason', (tester) async {
    await mount(tester, 'admin@feelingtrip.com', const Size(390, 844));
    await tester.tap(find.text('Nguyễn Ngọc Anh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối').last);
    await tester.pumpAndSettle();
    expect(find.text('Nhập ít nhất 3 ký tự'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Ảnh chưa rõ');
    await tester.tap(find.text('Từ chối').last);
    await tester.pumpAndSettle();
    expect(find.text('1 hồ sơ cần xem xét'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Blocked account opens a prefilled email and can return to login',
    (tester) async {
      final key = await mount(
        tester,
        'user.banned@feelingtrip.com',
        const Size(390, 844),
      );
      expect(find.byType(BlockedAccountScreen), findsOneWidget);
      expect(find.text('Tài khoản đã bị khóa'), findsOneWidget);
      await capture(tester, key, 'blocked-account');
      Uri? opened;
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          opened = Uri.parse(call.arguments['url'] as String);
          return true;
        }
        return false;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.tap(find.text('Liên hệ hỗ trợ'));
      await tester.pumpAndSettle();
      expect(opened?.path, supportEmail);
      expect(
        opened?.queryParameters['body'],
        contains('user.banned@feelingtrip.com'),
      );
      expect(opened?.queryParameters['body'], contains('Nội dung giải thích:'));
      await tester.tap(find.text('Quay lại đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(BlockedAccountScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Requests screen filters people and reviews a received request', (
    tester,
  ) async {
    final key = await mount(
      tester,
      'user.ekyc@feelingtrip.com',
      const Size(390, 844),
    );
    await tester.tap(find.byTooltip('Mở trang cá nhân'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Yêu cầu tham gia chuyến đi'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Yêu cầu tham gia chuyến đi'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'received-requests');
    expect(find.text('Chấp nhận'), findsWidgets);
    await tester.tap(find.text('Chấp nhận').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chấp nhận').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Chấp nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Bulk deletion persists on mock refresh, including read items',
    () async {
      final vm = NotificationViewModel();
      await vm.load();
      await vm.deleteAll();
      await vm.load();
      expect(vm.items, isEmpty);
      expect(vm.unreadCount, 0);
      vm.dispose();
    },
  );

  test('Latest destination filter wins while feed is loading', () async {
    final vm = CompanionFeedViewModel();
    final first = vm.load();
    vm.applyFilter(destination: 'Sapa');
    await first;
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(vm.posts, isNotEmpty);
    expect(
      vm.posts.every((post) => post.trip.destination!.contains('Sapa')),
      isTrue,
    );
    vm.dispose();
  });

  test('Support email retains Vietnamese accents and line breaks', () {
    final draft = buildAccountSupportEmail('test+demo@example.com');
    expect(draft.scheme, 'mailto');
    expect(draft.path, supportEmail);
    expect(
      draft.queryParameters['subject'],
      '[FeelingTrip] Đề nghị xem xét tài khoản bị khóa',
    );
    expect(
      draft.queryParameters['body'],
      contains('Email tài khoản: test+demo@example.com\n'),
    );
    expect(draft.toString(), isNot(contains('subject=[FeelingTrip]+')));
  });
  testWidgets('Auth updates preserve unauthenticated child screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthViewModel();
    await auth.restoreSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthScope(auth: auth, child: const AuthGate()),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AuthGate))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Màn đăng ký đang mở')),
      ),
    );
    await tester.pumpAndSettle();
    auth.clearError();
    await tester.pumpAndSettle();
    expect(find.text('Màn đăng ký đang mở'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('PostgreSQL money and timestamps parse for display', () {
    final trip = TripInfo.fromJson({
      'id': 'test',
      'estimatedBudget': '3500000.00',
      'startDate': '2026-10-31T17:00:00.000Z',
      'endDate': '2026-11-03T17:00:00.000Z',
    });
    expect(trip.estimatedBudget, 3500000);
    expect(
      trip.startDate,
      DateTime.parse('2026-10-31T17:00:00.000Z').toLocal(),
    );
    expect(trip.startDate!.isUtc, isFalse);
  });
}
