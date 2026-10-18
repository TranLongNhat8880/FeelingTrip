import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/admin/models/admin_content_model.dart';
import 'package:feeling_trip/features/admin/repositories/admin_content_repository.dart';
import 'package:feeling_trip/features/admin/views/admin_reports_content.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

class ReportRepository extends AdminContentRepository {
  int bans = 0, resolutions = 0;
  String? sentNotes;
  final data = <String, dynamic>{
    'id': 'report',
    'reportedUserId': 'user',
    'reportedUserName': 'Người dùng',
    'reportedUserStatus': 'ACTIVE',
    'reportedUserRole': 'USER',
    'reporterName': 'Người gửi',
    'reason': 'Nội dung báo cáo',
    'status': 'PENDING',
    'context': {
      'user': {'full_name': 'Người dùng', 'verification_status': 'VERIFIED'},
    },
  };
  @override
  Future<AdminReport> report(String id) async => AdminReport(data);
  @override
  Future<void> ban(String id, String reason) async {
    bans++;
    data['reportedUserStatus'] = 'BANNED';
  }

  @override
  Future<AdminReport> resolve(String id, String action, String notes) async {
    resolutions++;
    sentNotes = notes;
    return AdminReport({
      ...data,
      'status': action,
      'adminNotes': notes,
      'context': null,
    });
  }
}

void main() {
  Future<void> mount(WidgetTester tester, ReportRepository repo) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AdminReportDetailScreen(id: 'report', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextEditingController notes(WidgetTester tester) =>
      tester.widget<CustomTextField>(find.byType(CustomTextField)).controller!;
  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('insufficient evidence validates prefixed payload before API', (
    tester,
  ) async {
    final repo = ReportRepository();
    await mount(tester, repo);
    notes(tester).text = List.filled(1000, 'a').join();
    await tap(tester, 'Chưa đủ bằng chứng');
    expect(repo.resolutions, 0);
    expect(
      find.textContaining('Nhập ghi chú kết luận từ 3 đến'),
      findsOneWidget,
    );
    notes(tester).text = 'Thiếu bằng chứng đối chiếu';
    await tap(tester, 'Chưa đủ bằng chứng');
    expect(repo.resolutions, 1);
    expect(repo.sentNotes, '[Chưa đủ bằng chứng] Thiếu bằng chứng đối chiếu');
    expect(find.text('Kết luận báo cáo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ban validates 500 char limit and keeps draft after reload', (
    tester,
  ) async {
    final repo = ReportRepository();
    await mount(tester, repo);
    notes(tester).text = List.filled(501, 'a').join();
    await tap(tester, 'Khóa tài khoản');
    expect(repo.bans, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Nhập lý do khóa từ 3 đến 500 ký tự trong phần ghi chú.'),
      findsOneWidget,
    );
    notes(tester).text = 'Lý do khóa cần giữ lại để kết luận';
    await tap(tester, 'Khóa tài khoản');
    await tester.tap(find.widgetWithText(CustomButton, 'Khóa tài khoản'));
    await tester.pumpAndSettle();
    expect(repo.bans, 1);
    expect(notes(tester).text, 'Lý do khóa cần giữ lại để kết luận');
    expect(find.text('Chờ xử lý'), findsOneWidget);
    expect(find.text('Tài khoản đã khóa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conclusion retains loaded profile context when API omits it', (
    tester,
  ) async {
    final repo = ReportRepository();
    await mount(tester, repo);
    notes(tester).text = 'Đã kiểm tra và kết luận';
    await tap(tester, 'Kết luận báo cáo');
    expect(repo.resolutions, 1);
    expect(find.text('Đã xác minh'), findsOneWidget);
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
