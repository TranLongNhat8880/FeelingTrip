import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/shared/ui_kit.dart';
import 'package:feeling_trip/shared/gallery/ui_kit_gallery_screen.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  testWidgets('Gallery switch remains responsive through repeated toggles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const UiKitGalleryScreen()),
    );
    await tester.pumpAndSettle();
    final toggle = find.byType(Switch).first;
    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<Switch>(toggle).value, true);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, false);
    expect(tester.takeException(), isNull);
  });
  test('VND formatter preserves raw value and cursor during middle edits', () {
    final formatter = VndInputFormatter();
    final typed = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '150000',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    expect(typed.text, '150.000');
    expect(VndInputFormatter.parse(typed.text), 150000);
    final middle = formatter.formatEditUpdate(
      typed,
      const TextEditingValue(
        text: '1590.000',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    expect(middle.text, '1.590.000');
    expect(middle.selection.extentOffset, 4);
    final cleared = formatter.formatEditUpdate(middle, TextEditingValue.empty);
    expect(VndInputFormatter.parse(cleared.text), isNull);
    expect(VndInputFormatter.parse('-100'), isNull);
    expect(
      formatter.formatEditUpdate(typed, const TextEditingValue(text: '-100')),
      typed,
    );
  });

  testWidgets(
    'Selection displays its value before focus and respects disabled',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppSelectionField(
            label: 'Ngày đi',
            value: '21/10/2026',
            onTap: () => taps++,
            enabled: false,
          ),
        ),
      );
      expect(find.text('21/10/2026'), findsOneWidget);
      await tester.tap(find.text('21/10/2026'));
      expect(taps, 0);
    },
  );

  testWidgets('Loading and disabled buttons prevent duplicate actions', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      host(
        CustomButton(text: 'Lưu', isLoading: true, onPressed: () => presses++),
      ),
    );
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(presses, 0);
    await tester.pumpWidget(
      host(CustomButton(text: 'Lưu', onPressed: () => presses++)),
    );
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(presses, 1);
    await tester.pumpWidget(host(const CustomButton(text: 'Lưu')));
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(presses, 1);
  });

  testWidgets(
    'Money input formats and returns integer; zero rules are configurable',
    (tester) async {
      final form = GlobalKey<FormState>();
      int? value;
      await tester.pumpWidget(
        host(
          Form(
            key: form,
            child: AppMoneyField(
              label: 'Khoản chi',
              allowZero: false,
              onChanged: (v) => value = v,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '150000');
      await tester.pump();
      expect(value, 150000);
      expect(find.text('150.000'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '0');
      expect(form.currentState!.validate(), false);
      await tester.pump();
      expect(find.text('Số tiền phải lớn hơn 0'), findsOneWidget);
    },
  );

  testWidgets('Cancel dialog resolves false without applying an action', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => CustomButton(
            text: 'Mở',
            onPressed: () async {
              result = await AppConfirmDialog.show(
                context,
                title: 'Xóa?',
                message: 'Xác nhận thao tác',
                destructive: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(result, false);
  });

  testWidgets('Search clear notifies the feature', (tester) async {
    final controller = TextEditingController(text: 'Đà Lạt');
    String? query;
    await tester.pumpWidget(
      host(AppSearchField(controller: controller, onChanged: (v) => query = v)),
    );
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pump();
    expect(query, '');
    expect(controller.text, '');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Gallery handles a small viewport, large text and long labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const UiKitGalleryScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Văn bản dài'));
    await tester.tap(find.text('Văn bản dài'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Lưu kế hoạch chuyến đi cùng nhóm bạn của bạn'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Chọn ảnh chuyến đi'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
