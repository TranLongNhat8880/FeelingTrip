import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/admin/views/admin_reports_content.dart';

void main() {
  testWidgets('Warning dialog closes safely and does not send internal notes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AdminReportDetailScreen(id: 'report-demo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Ghi chú nội bộ không gửi',
    );
    await tester.ensureVisible(find.text('Gửi cảnh cáo và kết luận'));
    await tester.tap(find.text('Gửi cảnh cáo và kết luận'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Vui lòng kiểm tra thông tin thu tiền',
    );
    await tester.pump();
    await tester.tap(find.text('Gửi và kết luận'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Đã xử lý'), findsOneWidget);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(
      field.controller!.text,
      '[Cảnh cáo] Vui lòng kiểm tra thông tin thu tiền',
    );
    expect(tester.takeException(), isNull);
  });
}
