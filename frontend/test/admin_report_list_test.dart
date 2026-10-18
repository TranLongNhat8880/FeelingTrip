import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/admin/models/admin_content_model.dart';
import 'package:feeling_trip/features/admin/repositories/admin_content_repository.dart';
import 'package:feeling_trip/features/admin/views/admin_reports_content.dart';

class ReportListRepository extends AdminContentRepository {
  final requests = <String>[];
  @override
  Future<List<AdminReport>> reports(String status, String search) async {
    requests.add('$status:$search');
    return [
      {
        'id': 'user',
        'reportedUserId': 'u',
        'reportedTripId': 't',
        'reportedUserName': 'Người dùng tên dài để kiểm tra bố cục',
        'reason': 'Lý do tài khoản',
        'status': status,
        if (status == 'DISMISSED')
          'adminNotes': '[Chưa đủ bằng chứng] Thiếu thông tin',
      },
      {
        'id': 'trip',
        'reportedTripId': 't',
        'reportedTripName': 'Chuyến Hà Nội',
        'reason': 'Lý do chuyến đi',
        'status': status,
      },
    ].map(AdminReport.new).toList();
  }
}

void main() {
  Future<void> mount(WidgetTester tester, ReportListRepository repo) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: StatefulBuilder(
          builder: (context, setState) => _Tabs(repo: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reports separated by target with independent retained filters and search',
    (tester) async {
      final repo = ReportListRepository();
      await mount(tester, repo);
      expect(tester.takeException(), isNull, reason: 'initial layout');
      expect(
        find.text('Người dùng tên dài để kiểm tra bố cục'),
        findsOneWidget,
      );
      expect(find.text('Chuyến Hà Nội'), findsNothing);
      await tester.tap(find.byTooltip('Lọc trạng thái'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is CheckedPopupMenuItem<String> && w.value == 'RESOLVED',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repo.requests.last, 'RESOLVED:abc');
      await tester.tap(find.text('Tab chuyến đi'));
      await tester.pumpAndSettle();
      expect(find.text('Chuyến Hà Nội'), findsOneWidget);
      expect(find.text('Người dùng tên dài để kiểm tra bố cục'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Chờ xử lý'), findsNWidgets(2));
      await tester.tap(find.text('Tab người dùng'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'abc',
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(repo.requests.last, 'RESOLVED:');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long status and name fit narrow screen without overflow', (
    tester,
  ) async {
    final repo = ReportListRepository();
    await mount(tester, repo);
    expect(tester.takeException(), isNull, reason: 'initial layout');
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lọc trạng thái'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is CheckedPopupMenuItem<String> && w.value == 'DISMISSED',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa đủ bằng chứng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Tabs extends StatefulWidget {
  const _Tabs({required this.repo});
  final ReportListRepository repo;
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Wrap(
            children: [
              TextButton(
                onPressed: () => setState(() => index = 0),
                child: const Text('Tab người dùng'),
              ),
              TextButton(
                onPressed: () => setState(() => index = 1),
                child: const Text('Tab chuyến đi'),
              ),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                AdminReportsContent(repository: widget.repo),
                AdminReportsContent(repository: widget.repo, tripReports: true),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
