import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/notification/viewmodels/notification_viewmodel.dart';
import 'package:feeling_trip/features/notification/views/notification_screen.dart';

void main() {
  testWidgets(
    'Notification types have distinct icons, unread default and safe fallback',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = NotificationViewModel(
        repository: MockNotificationRepository(),
      );
      addTearDown(vm.dispose);
      const types = [
        'INVITE',
        'REQUEST',
        'BILL',
        'TRIP_UPDATE',
        'SYSTEM',
        'UNKNOWN',
      ];
      vm.items = [
        for (final type in types)
          NotificationItem(
            id: type,
            title: 'Kiểm thử $type',
            message: 'Thông tin đầy đủ của thông báo.',
            type: type,
            createdAt: DateTime(2026, 10, 14, 10),
            isRead: type == 'SYSTEM',
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: NotificationScreen(viewModel: vm)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kiểm thử SYSTEM'), findsNothing);
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      for (final icon in [
        Icons.mail_outline_rounded,
        Icons.person_add_alt_1_outlined,
        Icons.account_balance_wallet_outlined,
        Icons.calendar_today_outlined,
        Icons.campaign_outlined,
      ]) {
        expect(find.byIcon(icon), findsOneWidget);
      }
      expect(find.text('Kiểm thử UNKNOWN'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
