import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/admin/models/admin_content_model.dart';
import 'package:feeling_trip/features/admin/views/template_form_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

LibraryPlan plan(int count) => LibraryPlan({
  'id': 'local',
  'name': 'Lịch trình thử',
  'destination': 'Hà Nội',
  'days': List.generate(
    count,
    (index) => {
      'dayNumber': index + 1,
      'items': [
        {
          'customName': 'Hoạt động ngày ${index + 1}',
          'startTime': '09:00',
          'endTime': '10:00',
        },
      ],
    },
  ),
});

void main() {
  Future<void> mount(WidgetTester tester, int count) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TemplateFormScreen(plan: plan(count)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, int day) async {
    await tester.tap(find.byTooltip('Danh sách ngày'));
    await tester.pumpAndSettle();
    final target = find.byKey(ValueKey('day-list-$day'));
    final scrollable = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(target, 400, scrollable: scrollable);
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    '30 days supports mouse and touch scroll, fixed controls and direct selection',
    (tester) async {
      await mount(tester, 30);
      final strip = find.byKey(const ValueKey('template-day-strip'));
      final controller = tester
          .widget<SingleChildScrollView>(strip)
          .controller!;
      await tester.drag(
        strip,
        const Offset(-180, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      final afterMouse = controller.offset;
      await tester.drag(strip, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(afterMouse));
      expect(
        tester.getRect(find.byTooltip('Danh sách ngày')).left,
        greaterThanOrEqualTo(0),
      );
      expect(
        tester.getRect(find.byTooltip('Thêm ngày')).right,
        lessThanOrEqualTo(390),
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Thêm ngày',
              ),
            )
            .onPressed,
        isNull,
      );
      await pick(tester, 30);
      expect(find.text('Lịch hoạt động · ngày 30'), findsOneWidget);
      final selected = tester.getRect(find.text('Ngày 30').first);
      final viewport = tester.getRect(strip);
      expect(selected.left, greaterThanOrEqualTo(viewport.left));
      expect(selected.right, lessThanOrEqualTo(viewport.right + 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'adding last day reveals it and switching retains edited activity',
    (tester) async {
      await mount(tester, 29);
      await pick(tester, 1);
      final name = tester
          .widget<CustomTextField>(
            find.byWidgetPredicate(
              (w) =>
                  w is CustomTextField && w.label == 'Tên hoạt động / địa điểm',
            ),
          )
          .controller!;
      name.text = 'Nội dung đang soạn';
      await tester.tap(find.byTooltip('Thêm ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch hoạt động · ngày 30'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Thêm ngày',
              ),
            )
            .onPressed,
        isNull,
      );
      await pick(tester, 1);
      final restored = tester
          .widget<CustomTextField>(
            find.byWidgetPredicate(
              (w) =>
                  w is CustomTextField && w.label == 'Tên hoạt động / địa điểm',
            ),
          )
          .controller!;
      expect(restored.text, 'Nội dung đang soạn');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'deleting last draft day reveals previous day and re-enables add',
    (tester) async {
      await mount(tester, 30);
      await pick(tester, 30);
      await tester.tap(find.byTooltip('Xóa ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CustomButton, 'Xóa ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch hoạt động · ngày 29'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Thêm ngày',
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
