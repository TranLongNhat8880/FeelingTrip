import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/shared/inputs/time_input_formatter.dart';
import 'package:feeling_trip/features/admin/models/admin_content_model.dart';
import 'package:feeling_trip/features/admin/views/template_form_screen.dart';

void main() {
  const formatter = TimeInputFormatter();
  TextEditingValue edit(String value) => TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
  test('four digits, paste and midnight boundaries format correctly', () {
    for (final entry in {
      '1234': '12:34',
      '0000': '00:00',
      '2359': '23:59',
      '09:05': '09:05',
    }.entries) {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        edit(entry.key),
      );
      expect(result.text, entry.value);
      expect(result.selection.baseOffset, entry.value.length);
    }
  });
  test('invalid characters, out of range and extra digits are rejected', () {
    final previous = edit('09:00');
    for (final value in [
      '11;00',
      'ab12',
      '2400',
      '2360',
      '1269',
      '12345',
      '9999',
      '9',
    ]) {
      expect(
        formatter.formatEditUpdate(previous, edit(value)),
        previous,
        reason: value,
      );
    }
  });
  test('typing, clearing and backspace across separator remain editable', () {
    var value = TextEditingValue.empty;
    for (final character in ['1', '2', '3', '4']) {
      value = formatter.formatEditUpdate(value, edit(value.text + character));
    }
    expect(value.text, '12:34');
    final before = TextEditingValue(
      text: '12:34',
      selection: const TextSelection.collapsed(offset: 3),
    );
    final after = formatter.formatEditUpdate(
      before,
      const TextEditingValue(
        text: '1234',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(after.text, '12:34');
    expect(after.selection.baseOffset, 2);
    expect(
      formatter.formatEditUpdate(value, TextEditingValue.empty).text,
      isEmpty,
    );
  });

  testWidgets(
    'form formats input and refuses incomplete or reversed time before saving',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plan = LibraryPlan({
        'id': 'local',
        'name': 'Mẫu thử',
        'destination': 'Hà Nội',
        'days': [
          {
            'dayNumber': 1,
            'items': [
              {
                'customName': 'Tham quan',
                'startTime': '09:00',
                'endTime': '10:00',
              },
            ],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TemplateFormScreen(plan: plan),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Danh sách ngày'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-list-1')));
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.ensureVisible(field('Bắt đầu'));
      await tester.enterText(field('Bắt đầu'), '1234');
      expect(
        tester.widget<TextField>(field('Bắt đầu')).controller!.text,
        '12:34',
      );
      await tester.enterText(field('Kết thúc'), '11;00');
      expect(
        tester.widget<TextField>(field('Kết thúc')).controller!.text,
        '10:00',
      );
      await tester.enterText(field('Kết thúc'), '2400');
      expect(
        tester.widget<TextField>(field('Kết thúc')).controller!.text,
        '10:00',
      );
      await tester.tap(find.text('Lưu mẫu'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('giờ kết thúc phải sau bắt đầu'),
        findsOneWidget,
      );
      await tester.enterText(field('Kết thúc'), '12');
      await tester.tap(find.text('Lưu mẫu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nhập giờ HH:mm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
