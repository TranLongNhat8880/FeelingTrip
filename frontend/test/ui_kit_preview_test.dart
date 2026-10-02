import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/shared/gallery/ui_kit_gallery_screen.dart';

void main() {
  testWidgets('Render UI Kit preview images', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = FontLoader('BeVietnamPro')
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Bold.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const UiKitGalleryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final directory = Directory('../docs/ui-kit-previews')
      ..createSync(recursive: true);
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${directory.path}/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('overview');
    await tester.ensureVisible(find.text('04 / Thẻ & thông tin'));
    await tester.pumpAndSettle();
    await capture('cards');
    await tester.ensureVisible(find.text('Mở thông báo thành công'));
    await tester.tap(find.text('Mở thông báo thành công'));
    await tester.pumpAndSettle();
    await capture('dialog');
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('GENERATE_UI_PREVIEW'));
}
