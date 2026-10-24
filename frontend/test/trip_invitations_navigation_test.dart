import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/features/auth/models/user_model.dart';
import 'package:feeling_trip/features/companion/views/companion_requests_screen.dart';
import 'package:feeling_trip/features/home/views/personal_content.dart';
import 'package:feeling_trip/features/trip/repositories/mock_trip_repository.dart';
import 'package:feeling_trip/features/trip/views/trip_invitations_screen.dart';
import 'package:feeling_trip/features/trip/views/trip_list_screen.dart';
import 'package:feeling_trip/routes/app_routes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Trip invitations location and unified requests tests', () {
    testWidgets('TripListScreen does not contain Lời mời của tôi button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripListScreen(repository: MockTripRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tạo chuyến đi'), findsOneWidget);
      expect(find.text('Tham gia bằng mã'), findsOneWidget);
      expect(find.text('Lời mời của tôi'), findsNothing);
    });

    testWidgets('PersonalContent unifies Lời mời into Yêu cầu shortcut and removes separate entry', (tester) async {
      final user = UserModel(
        id: 'test-user-id',
        email: 'test@feelingtrip.com',
        fullName: 'Nguyen Van Test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonalContent(
              user: user,
              onLogout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quick shortcut 'Yêu cầu' is present
      expect(find.text('Yêu cầu'), findsOneWidget);

      // Separate list entry 'Lời mời của tôi' in Account section is removed
      expect(find.text('Lời mời của tôi'), findsNothing);
    });

    testWidgets('Tapping Yêu cầu shortcut opens unified screen with Lời mời tab', (tester) async {
      final user = UserModel(
        id: 'test-user-id',
        email: 'test@feelingtrip.com',
        fullName: 'Nguyen Van Test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonalContent(
              user: user,
              onLogout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap shortcut 'Yêu cầu'
      await tester.tap(find.text('Yêu cầu'));
      await tester.pumpAndSettle();

      // We should now be on CompanionRequestsScreen with 3 tabs
      expect(find.byType(CompanionRequestsScreen), findsOneWidget);
      expect(find.text('Đã gửi'), findsOneWidget);
      expect(find.text('Nhận được'), findsOneWidget);
      expect(find.text('Lời mời'), findsOneWidget);

      // Tapping 'Lời mời' tab switches to invitations content
      await tester.tap(find.text('Lời mời'));
      await tester.pumpAndSettle();
      expect(find.byType(TripInvitationsContent), findsOneWidget);
    });

    testWidgets('AppRoutes.tripInvitations navigates to unified screen with Lời mời selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const SizedBox(),
            AppRoutes.tripInvitations: (context) =>
                const CompanionRequestsScreen(initialIndex: 2),
          },
          initialRoute: AppRoutes.tripInvitations,
        ),
      );
      await tester.pumpAndSettle();

      // Should be on CompanionRequestsScreen with Lời mời tab active
      expect(find.byType(CompanionRequestsScreen), findsOneWidget);
      expect(find.byType(TripInvitationsContent), findsOneWidget);
    });
  });
}
