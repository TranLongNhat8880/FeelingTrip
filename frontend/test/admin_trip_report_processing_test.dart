import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/admin/models/admin_content_model.dart';
import 'package:feeling_trip/features/admin/models/admin_trip_report_resolution.dart';
import 'package:feeling_trip/features/admin/repositories/admin_content_repository.dart';
import 'package:feeling_trip/features/admin/views/admin_reports_content.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

Map<String, dynamic> fixture({bool supported = true}) => {
  'id': 'report-trip',
  'reportedTripId': 'trip-one',
  'reportedTripName': 'Chuyến Hà Nội',
  'reporterName': 'Người gửi',
  'reason': 'Nội dung bài tuyển không chính xác',
  'status': 'PENDING',
  'context': {
    'tripReportProcessing': supported,
    'trip': {'id': 'trip-one', 'name': 'Chuyến Hà Nội'},
    'users': [
      {
        'id': 'leader',
        'full_name': 'Trưởng nhóm A',
        'role': 'USER',
        'status': 'ACTIVE',
      },
      {
        'id': 'member',
        'full_name': 'Thành viên B',
        'role': 'USER',
        'status': 'ACTIVE',
      },
      {
        'id': 'banned',
        'full_name': 'Người đã khóa',
        'role': 'USER',
        'status': 'BANNED',
      },
      {
        'id': 'admin',
        'full_name': 'Quản trị viên',
        'role': 'ADMIN',
        'status': 'ACTIVE',
      },
    ],
    'posts': [
      {'id': 'post-one', 'title': 'Bài tuyển sai', 'status': 'OPEN'},
      {'id': 'post-closed', 'title': 'Bài đã đóng', 'status': 'CLOSED'},
    ],
  },
};

class FakeRepository extends AdminContentRepository {
  FakeRepository({bool supported = true}) : row = fixture(supported: supported);
  final Map<String, dynamic> row;
  int processed = 0, legacyResolved = 0;
  bool fail = false;
  String? savedNotes;
  TripReportResolution? submitted;
  @override
  Future<AdminReport> report(String id) async => AdminReport(row);
  @override
  Future<AdminReport> processTripReport(
    String id,
    String notes,
    TripReportResolution resolution,
  ) async {
    processed++;
    submitted = resolution;
    savedNotes = notes;
    if (fail) throw Exception('BE từ chối, không áp dụng hành động');
    row['status'] = 'RESOLVED';
    row['adminNotes'] = '$notes\n[Hành động xử lý]\nĐã ẩn bài và cảnh cáo';
    return AdminReport(row);
  }

  @override
  Future<AdminReport> resolve(String id, String action, String notes) async {
    legacyResolved++;
    row['status'] = action;
    row['adminNotes'] = notes;
    return AdminReport(row);
  }
}

void main() {
  Future<void> mount(WidgetTester tester, FakeRepository repo) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AdminReportDetailScreen(id: 'report-trip', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  CustomTextField field(WidgetTester tester, String label) =>
      tester.widget<CustomTextField>(
        find.byWidgetPredicate(
          (widget) => widget is CustomTextField && widget.label == label,
        ),
      );
  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  void fill(WidgetTester tester) {
    field(tester, 'Ghi chú kết luận (nội bộ)').controller!.text =
        'Bằng chứng nội bộ bí mật';
    field(
      tester,
      'Nội dung thông báo cho đối tượng bị xử lý',
    ).controller!.text = 'Vui lòng sửa thông tin bài tuyển';
  }

  Future<void> selectActions(WidgetTester tester) async {
    tester
        .widget<CheckboxListTile>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CheckboxListTile &&
                (widget.title as Text).data == 'Bài tuyển sai',
          ),
        )
        .onChanged!(true);
    await tester.pump();
    await tap(tester, 'Cảnh cáo');
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!('member');
    await tester.pumpAndSettle();
    fill(tester);
  }

  testWidgets(
    'trip report cannot be resolved with no actual action or implicit leader target',
    (tester) async {
      final repo = FakeRepository();
      await mount(tester, repo);
      expect(find.text('Đánh dấu đã xử lý'), findsNothing);
      fill(tester);
      await tap(tester, 'Áp dụng hành động và kết luận');
      expect(
        find.text('Chọn từ 1 đến 10 hành động trước khi kết luận.'),
        findsOneWidget,
      );
      await tap(tester, 'Cảnh cáo');
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, isNull);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .items!
            .map((item) => item.value),
        isNot(contains('admin')),
      );
      await tap(tester, 'Áp dụng hành động và kết luận');
      expect(
        find.text('Hãy chọn rõ tài khoản chịu trách nhiệm.'),
        findsOneWidget,
      );
      expect(repo.processed, 0);
      expect(repo.legacyResolved, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation can be cancelled; combined actions keep internal notes separate',
    (tester) async {
      final repo = FakeRepository();
      await mount(tester, repo);
      await selectActions(tester);
      await tap(tester, 'Áp dụng hành động và kết luận');
      expect(find.text('Xác nhận xử lý báo cáo chuyến đi?'), findsOneWidget);
      expect(
        find.textContaining('Cảnh cáo tài khoản: Thành viên B'),
        findsOneWidget,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.processed, 0);
      await tap(tester, 'Áp dụng hành động và kết luận');
      await tester.tap(find.text('Áp dụng và kết luận'));
      await tester.pumpAndSettle();
      expect(repo.processed, 1);
      expect(repo.legacyResolved, 0);
      expect(repo.savedNotes, 'Bằng chứng nội bộ bí mật');
      expect(repo.submitted!.reason, 'Vui lòng sửa thông tin bài tuyển');
      expect(repo.submitted!.actions.map((a) => a.toJson()).toList(), [
        {'type': 'HIDE_POST', 'targetId': 'post-one'},
        {'type': 'WARN_USER', 'targetId': 'member'},
      ]);
      expect(find.text('Đã xử lý'), findsOneWidget);
      expect(find.text('Áp dụng hành động và kết luận'), findsNothing);
      expect(
        field(tester, 'Ghi chú kết luận (nội bộ)').controller!.text,
        contains('[Hành động xử lý]'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'backend failure keeps report pending; no fallback to legacy resolve',
    (tester) async {
      final repo = FakeRepository()..fail = true;
      await mount(tester, repo);
      await selectActions(tester);
      await tap(tester, 'Áp dụng hành động và kết luận');
      await tester.tap(find.text('Áp dụng và kết luận'));
      await tester.pumpAndSettle();
      expect(find.text('Chờ xử lý'), findsOneWidget);
      expect(find.text('BE từ chối, không áp dụng hành động'), findsOneWidget);
      expect(repo.processed, 1);
      expect(repo.legacyResolved, 0);
    },
  );

  testWidgets(
    'old backend disables new processing instead of pretending success',
    (tester) async {
      final repo = FakeRepository(supported: false);
      await mount(tester, repo);
      expect(
        find.textContaining('Chưa thể áp dụng biện pháp xử lý'),
        findsOneWidget,
      );
      final button = tester.widget<CustomButton>(
        find.widgetWithText(CustomButton, 'Áp dụng hành động và kết luận'),
      );
      expect(button.onPressed, isNull);
      expect(repo.processed, 0);
      expect(find.text('Bác bỏ báo cáo'), findsOneWidget);
    },
  );

  testWidgets(
    'closed post and already banned account cannot be selected for repeated sanction',
    (tester) async {
      final repo = FakeRepository();
      await mount(tester, repo);
      final closed = tester.widget<CheckboxListTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckboxListTile &&
              (widget.title as Text).data == 'Bài đã đóng',
        ),
      );
      expect(closed.onChanged, isNull);
      await tap(tester, 'Khóa tài khoản');
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged!('banned');
      await tester.pumpAndSettle();
      fill(tester);
      await tap(tester, 'Áp dụng hành động và kết luận');
      expect(
        find.text('Tài khoản đã bị khóa. Hãy chọn hành động khác.'),
        findsOneWidget,
      );
      expect(repo.processed, 0);
    },
  );

  test(
    'repository uses dedicated process endpoint and excludes display labels from API',
    () async {
      final original = ApiClient.client;
      SharedPreferences.setMockInitialValues({'jwt_token': 'test-admin'});
      ApiClient.client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/admin/reports/report-trip/process');
        expect(request.headers['Authorization'], 'Bearer test-admin');
        expect(jsonDecode(request.body), {
          'adminNotes': 'nội bộ',
          'reason': 'Thông báo công khai',
          'actions': [
            {'type': 'WARN_USER', 'targetId': 'member'},
          ],
        });
        return http.Response(
          jsonEncode({
            'data': {...fixture(), 'status': 'RESOLVED'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      try {
        final row = await AdminContentRepository().processTripReport(
          'report-trip',
          ' nội bộ ',
          TripReportResolution(
            reason: 'Thông báo công khai',
            actions: [
              const TripReportAction(
                type: 'WARN_USER',
                targetId: 'member',
                label: 'Không gửi nhãn UI',
              ),
            ],
          ),
        );
        expect(row.status, 'RESOLVED');
      } finally {
        ApiClient.client.close();
        ApiClient.client = original;
      }
    },
  );
}
