import 'dart:io';
import 'package:feeling_trip/features/trip/views/trip_form_screen.dart';
import 'package:feeling_trip/features/companion/repositories/companion_trip_repository.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/features/admin/views/admin_screen.dart';
import 'package:feeling_trip/features/trip/models/trip_model.dart';
import 'package:feeling_trip/features/trip/repositories/mock_trip_repository.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:feeling_trip/routes/app_routes.dart';
import 'package:feeling_trip/features/trip/views/trip_detail_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';
import 'package:feeling_trip/features/companion/views/companion_detail_screen.dart';
import 'package:feeling_trip/features/admin/views/admin_moderation_screen.dart';
import 'package:feeling_trip/features/companion/views/create_companion_post_screen.dart';
import 'package:feeling_trip/features/companion/views/companion_sent_requests_screen.dart';
import 'package:feeling_trip/features/companion/views/companion_requests_screen.dart';
import 'package:feeling_trip/features/companion/repositories/mock_companion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/admin/views/admin_reports_content.dart';
import 'package:feeling_trip/features/admin/views/admin_templates_content.dart';
import 'package:feeling_trip/features/admin/views/plan_library_screen.dart';
import 'package:feeling_trip/features/admin/views/template_form_screen.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';

class CapturingRecruitmentTripRepository extends MockTripRepository {
  TripFormData? submitted;
  @override
  Future<TripModel> createTrip(TripFormData data) async {
    submitted = data;
    return super.createTrip(data);
  }
}

class PrivateTripFixture extends CompanionTripRepository {
  bool public = false;
  bool fail = false;
  int conversions = 0;
  @override
  Future<bool> hasPostForTrip(String tripId) async => false;
  @override
  Future<bool> isPublicTrip(String tripId) async => public;
  @override
  Future<void> makePublic(String tripId) async {
    conversions++;
    if (fail) {
      throw ApiException(
        statusCode: 403,
        message: 'Cần xác minh danh tính trước khi công khai',
      );
    }
    public = true;
  }
}

Future<void> mount(
  WidgetTester tester,
  Widget screen, {
  bool user = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final auth = AuthViewModel();
  await tester.runAsync(
    () => auth.login(
      user ? 'user.ekyc@feelingtrip.com' : 'admin@feelingtrip.com',
      'demo',
    ),
  );
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    AuthScope(
      auth: auth,
      child: RepaintBoundary(
        key: const ValueKey('admin-preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  final output = Platform.environment['ADMIN_SCREENSHOTS'];
  if (output == null) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('admin-preview')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
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
  testWidgets(
    'Admin resolves report without success popup and final state survives reopening',
    (tester) async {
      await mount(tester, const Scaffold(body: AdminReportsContent()));
      await tester.tap(find.text('Minh Khang'));
      await tester.pumpAndSettle();
      await capture(tester, 'report-detail');
      await tester.enterText(
        find.byType(TextFormField).first,
        'Đã kiểm tra và xử lý.',
      );
      await tester.ensureVisible(find.text('Đánh dấu đã xử lý'));
      await tester.tap(find.text('Đánh dấu đã xử lý'));
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái: Đã xử lý'), findsOneWidget);
      expect(find.text('Bác bỏ báo cáo'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Minh Khang'), findsNothing);
      await tester.tap(find.text('Đã xử lý'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minh Khang'));
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái: Đã xử lý'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Template description expands instead of scrolling inside its field',
    (tester) async {
      await mount(tester, const TemplateFormScreen());
      final field = find.byType(TextFormField).at(3);
      final initialHeight = tester.getSize(field).height;
      final longDescription = List.generate(
        12,
        (index) =>
            'Dòng ${index + 1}: Lưu ý cho chuyến đi và lịch trình tham khảo.',
      ).join('\n');
      await tester.ensureVisible(field);
      await tester.enterText(field, longDescription);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .maxLines,
        isNull,
      );
      expect(tester.getSize(field).height, greaterThan(initialHeight * 2));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        longDescription,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Template form validates, saves and returns without success popup',
    (tester) async {
      await mount(tester, const Scaffold(body: AdminTemplatesContent()));
      await tester.tap(find.text('Thêm mẫu'));
      await tester.pumpAndSettle();
      expect(find.text('Tên ngày'), findsNothing);
      expect(find.text('Ngày 1'), findsOneWidget);
      await tester.tap(find.text('Lưu mẫu'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kiểm tra tên mẫu, điểm đến, ngân sách và mô tả.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Mẫu kiểm thử giao diện',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Hanoi');
      await tester.tap(find.text('Ngày 1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhập tự do'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Dạo phố');
      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pump();
      await capture(tester, 'template-form');
      await tester.tap(find.text('Lưu mẫu'));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateFormScreen), findsNothing);
      expect(find.text('Mẫu kiểm thử giao diện'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      final row = find.ancestor(
        of: find.text('Mẫu kiểm thử giao diện'),
        matching: find.byType(Card),
      );
      await tester.ensureVisible(
        find.descendant(of: row, matching: find.text('Ẩn')),
      );
      await tester.tap(find.descendant(of: row, matching: find.text('Ẩn')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: row, matching: find.text('Đã ẩn')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Template editor selects a catalog place and keeps the link on reopening',
    (tester) async {
      await mount(tester, const Scaffold(body: AdminTemplatesContent()));
      await tester.tap(find.text('Thêm mẫu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Mẫu có địa điểm liên kết',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Hà Nội');
      await tester.tap(find.text('Ngày 1').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Chọn địa điểm'));
      await tester.tap(find.text('Chọn địa điểm'));
      await tester.pumpAndSettle();
      await capture(tester, 'template-place-picker');
      await tester.tap(find.text('Hồ Hoàn Kiếm'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi địa điểm'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(0)).enabled,
        isFalse,
      );
      await tester.tap(find.text('Lưu mẫu'));
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('Mẫu có địa điểm liên kết'),
        matching: find.byType(Card),
      );
      await tester.ensureVisible(
        find.descendant(of: row, matching: find.text('Sửa')),
      );
      await tester.tap(find.descendant(of: row, matching: find.text('Sửa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ngày 1').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đổi địa điểm'));
      expect(find.text('Đổi địa điểm'), findsOneWidget);
      expect(find.text('Hồ Hoàn Kiếm'), findsWidgets);
      await tester.ensureVisible(find.text('Nhập tự do'));
      await tester.tap(find.text('Nhập tự do'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(0)).enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Admin groups use named app-bar tabs without nested scaffold', (
    tester,
  ) async {
    await mount(tester, const AdminScreen());
    await tester.tap(find.text('Thư viện').last);
    await tester.pumpAndSettle();
    expect(find.text('Lịch trình mẫu'), findsOneWidget);
    expect(find.byTooltip('Kho lịch trình'), findsNothing);
    await capture(tester, 'admin-library-tabs');
    await tester.tap(find.text('Cộng đồng'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.tap(find.text('Kiểm duyệt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bài tuyển'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    await capture(tester, 'admin-moderation-tabs');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Template editor retains each day and validates hidden activities',
    (tester) async {
      await mount(tester, const TemplateFormScreen());
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Mẫu nhiều ngày',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Hà Nội');
      await tester.tap(find.text('Ngày 1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhập tự do'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Dạo phố ngày một',
      );
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      await tester.enterText(find.byType(TextFormField).at(2), '08:15');
      await tester.enterText(find.byType(TextFormField).at(3), '09:00');
      await tester.tap(find.byTooltip('Thêm ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhập tự do'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Dạo phố ngày hai',
      );
      await tester.tap(find.text('Ngày 1').first);
      await tester.pumpAndSettle();
      expect(find.text('Dạo phố ngày một'), findsWidgets);
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .initialValue,
        '08:15',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '25:00');
      await tester.tap(find.text('Thông tin chung').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu mẫu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ngày 1 · Hoạt động 1:'), findsOneWidget);
      expect(find.text('Lịch hoạt động · ngày 1'), findsOneWidget);
      expect(find.byType(TemplateFormScreen), findsOneWidget);
      await capture(tester, 'template-day-validation');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'User selects target trip and sees applied state instead of success popup',
    (tester) async {
      await mount(tester, const PlanLibraryScreen(), user: true);
      await capture(tester, 'plan-library');
      await tester.tap(find.text('Một ngày khám phá Hội An'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sử dụng mẫu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Chuyến đi Hội An của bạn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Sử dụng'));
      await tester.pumpAndSettle();
      expect(find.text('Đã sử dụng cho chuyến đi'), findsOneWidget);
      await capture(tester, 'plan-applied');
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Owner edits an existing companion post without duplicate posting or success popup',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockCompanionRepository();
      final post = (await tester.runAsync(
        () => repo.createPost(
          tripId: 'edit-trip',
          title: 'Bài tuyển ban đầu',
          content: 'Nội dung ban đầu đủ dài',
          targetMembersCount: 3,
        ),
      ))!;
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateCompanionPostScreen(
                    post: post,
                    tripId: post.trip.id,
                    repository: repo,
                  ),
                ),
              ),
              child: const Text('Mở form sửa'),
            ),
          ),
        ),
        user: true,
      );
      await tester.tap(find.text('Mở form sửa'));
      await tester.pumpAndSettle();
      expect(find.text('Bài tuyển ban đầu'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Bài tuyển đã chỉnh sửa',
      );
      await capture(tester, 'edit-companion-post');
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => repo.getPostDetail(post.id)))!.title,
        'Bài tuyển đã chỉnh sửa',
      );
      expect(find.byType(SnackBar), findsNothing);
      await mount(tester, CompanionDetailScreen(postId: post.id), user: true);
      await tester.tap(find.byTooltip('Thao tác bài đăng'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa bài đăng'), findsOneWidget);
      expect(find.text('Đóng bài tuyển'), findsOneWidget);
      await repo.closePost(post.id);
    },
  );
  testWidgets('Sent requests can be cancelled and stay removed after reload', (
    tester,
  ) async {
    await mount(
      tester,
      const CompanionRequestsScreen(initialReceived: true),
      user: true,
    );
    final repo = MockCompanionRepository();
    await tester.runAsync(
      () => repo.createJoinRequest(
        postId: 'post-1',
        introduction: 'Mình muốn tham gia',
      ),
    );
    await tester.tap(find.text('Đã gửi'));
    await tester.pumpAndSettle();
    expect(find.byType(CompanionSentRequestsContent), findsOneWidget);
    expect(find.byType(CompanionRequestsScreen), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('Huỷ yêu cầu'), findsOneWidget);
    await capture(tester, 'sent-companion-requests');
    await tester.tap(find.text('Huỷ yêu cầu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huỷ yêu cầu').last);
    await tester.pumpAndSettle();
    await capture(tester, 'sent-after-cancel');
    expect(find.text('Không có yêu cầu'), findsOneWidget);
    expect((await repo.getMySentRequests()).isEmpty, true);
    expect(find.byType(SnackBar), findsNothing);
  });
  testWidgets(
    'Admin moderation requires a reason and persists hidden post state',
    (tester) async {
      await mount(
        tester,
        const AdminModerationDetailScreen(id: 'moderation-1'),
      );
      await tester.ensureVisible(find.text('Ẩn bài tuyển'));
      await tester.tap(find.text('Ẩn bài tuyển'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập lý do từ 3 đến 1000 ký tự.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Thông tin tuyển không đúng sự thật',
      );
      await capture(tester, 'admin-moderation-detail');
      await tester.ensureVisible(find.text('Ẩn bài tuyển'));
      await tester.tap(find.text('Ẩn bài tuyển'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ẩn bài'));
      await tester.pumpAndSettle();
      expect(find.text('Bài đăng đã đóng hoặc đã bị ẩn.'), findsOneWidget);
      expect(find.text('Ẩn bài tuyển'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Private recruitment requires confirmation and never auto-publishes',
    (tester) async {
      final trips = PrivateTripFixture();
      await mount(
        tester,
        CreateCompanionPostScreen(
          tripId: 'private-trip',
          tripName: 'Chuyến riêng tư',
          tripRepository: trips,
        ),
        user: true,
      );
      await tester.tap(
        find.widgetWithText(CustomButton, 'Chuyển sang công khai'),
      );
      await tester.pumpAndSettle();
      expect(trips.conversions, 0);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(trips.public, false);
      expect(trips.conversions, 0);
      await tester.tap(
        find.widgetWithText(CustomButton, 'Chuyển sang công khai'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Chuyển sang công khai'),
        ),
      );
      await tester.pumpAndSettle();
      expect(trips.conversions, 1);
      expect(trips.public, true);
      expect(find.widgetWithText(CustomButton, 'Đăng bài'), findsOneWidget);
      expect(find.byType(CreateCompanionPostScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Failed public conversion leaves private recruitment state intact',
    (tester) async {
      final trips = PrivateTripFixture()..fail = true;
      await mount(
        tester,
        CreateCompanionPostScreen(
          tripId: 'private-trip',
          tripRepository: trips,
        ),
        user: true,
      );
      await tester.tap(
        find.widgetWithText(CustomButton, 'Chuyển sang công khai'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Chuyển sang công khai'),
        ),
      );
      await tester.pumpAndSettle();
      expect(trips.public, false);
      expect(find.widgetWithText(CustomButton, 'Đăng bài'), findsNothing);
      expect(
        find.text('Cần xác minh danh tính trước khi công khai'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Public trip counts the leader and validates recruitment ages before submission',
    (tester) async {
      final trips = CapturingRecruitmentTripRepository();
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripFormScreen(repository: trips),
                ),
              ),
              child: const Text('Mở form chuyến đi'),
            ),
          ),
        ),
        user: true,
      );
      await tester.tap(find.text('Mở form chuyến đi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), 'Hà Nội');
      await tester.ensureVisible(find.text('Nhóm công khai'));
      await tester.tap(find.text('Nhóm công khai'));
      await tester.pumpAndSettle();
      final age = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is CustomTextField && w.label == 'Tuổi từ (tùy chọn)',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(age);
      await tester.enterText(age, '9');
      await tester.tap(find.widgetWithText(CustomButton, 'Tạo chuyến đi'));
      await tester.pumpAndSettle();
      expect(trips.submitted, isNull);
      expect(find.text('Nhập tuổi từ 16 đến 100'), findsOneWidget);
      await tester.ensureVisible(age);
      await tester.enterText(age, '22');
      await tester.tap(find.widgetWithText(CustomButton, 'Tạo chuyến đi'));
      await tester.pumpAndSettle();
      expect(trips.submitted?.privacyType, 'PUBLIC');
      expect(trips.submitted?.targetMembersCount, 4);
      expect(trips.submitted?.toJson()['targetMembersCount'], 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Private trip hides recruitment entry', (tester) async {
    await mount(
      tester,
      const TripDetailScreen(tripId: '11111111-1111-4111-8111-111111111111'),
      user: true,
    );
    expect(find.text('Tìm bạn đồng hành'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Posting from trip detail hides the entry and reopening the pinned form blocks duplicates',
    (tester) async {
      const tripId = '11111111-1111-4111-8111-111111111111';
      final trips = MockTripRepository();
      final trip = await tester.runAsync(() => trips.getTripById(tripId));
      await tester.runAsync(
        () => trips.updateTrip(
          trip!,
          TripFormData(
            name: trip.name,
            destination: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            estimatedBudget: trip.estimatedBudget,
            privacyType: 'PUBLIC',
          ),
        ),
      );
      await mount(
        tester,
        TripDetailScreen(tripId: tripId, repository: trips),
        user: true,
      );
      await tester.ensureVisible(find.text('Tìm bạn đồng hành'));
      await tester.tap(find.text('Tìm bạn đồng hành'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Cùng khám phá và chia sẻ chi phí chuyến đi.',
      );
      await tester.tap(find.text('Đăng bài'));
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailScreen), findsOneWidget);
      expect(find.text('Tìm bạn đồng hành'), findsNothing);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute(
              builder: (_) => const CreateCompanionPostScreen(
                tripId: tripId,
                tripName: 'Đà Nẵng',
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Đã đăng bài'), findsOneWidget);
      final button = tester.widget<CustomButton>(
        find.widgetWithText(CustomButton, 'Đã đăng bài'),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Requests use one screen with app-bar tabs and preserve filters',
    (tester) async {
      await mount(tester, const CompanionRequestsScreen(), user: true);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      expect(find.text('Yêu cầu tham gia'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.tap(find.text('Chờ duyệt'));
      await tester.pumpAndSettle();
      await capture(tester, 'requests-sent-tab');
      await tester.tap(find.text('Nhận được'));
      await tester.pumpAndSettle();
      expect(find.text('Tên người gửi yêu cầu'), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first),
        same(navigator),
      );
      expect(find.byType(Scaffold), findsOneWidget);
      await capture(tester, 'requests-received-tab');
      await tester.tap(find.text('Đã gửi'));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Chờ duyệt'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip.selected, true);
      expect(tester.takeException(), isNull);
    },
  );
}
