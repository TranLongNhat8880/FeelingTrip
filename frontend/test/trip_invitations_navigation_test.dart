import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/features/auth/models/user_model.dart';
import 'package:feeling_trip/features/home/views/personal_content.dart';
import 'package:feeling_trip/features/trip/repositories/mock_trip_repository.dart';
import 'package:feeling_trip/features/trip/views/trip_invitations_screen.dart';
import 'package:feeling_trip/features/trip/views/trip_list_screen.dart';
import 'package:feeling_trip/routes/app_routes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Trip invitations location tests', () {
    testWidgets('TripListScreen no longer contains Lời mời của tôi button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripListScreen(repository: MockTripRepository()),
        ),
      );
      await tester.pumpAndSettle();

      // "Tạo chuyến đi" and "Tham gia bằng mã" should be present
      expect(find.text('Tạo chuyến đi'), findsOneWidget);
      expect(find.text('Tham gia bằng mã'), findsOneWidget);

      // "Lời mời của tôi" button should NOT be in TripListScreen
      expect(find.text('Lời mời của tôi'), findsNothing);
    });

    testWidgets('PersonalContent contains Lời mời shortcut and Lời mời của tôi entry', (tester) async {
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

      // Quick shortcut 'Lời mời'
      expect(find.text('Lời mời'), findsOneWidget);

      // Scroll to find list entry 'Lời mời của tôi'
      await tester.scrollUntilVisible(
        find.text('Lời mời của tôi'),
        200,
      );
      await tester.pumpAndSettle();

      // List entry 'Lời mời của tôi'
      expect(find.text('Lời mời của tôi'), findsOneWidget);
      expect(find.text('Xem và phản hồi lời mời tham gia chuyến đi'), findsOneWidget);
    });

    testWidgets('Tapping Lời mời shortcut in PersonalContent navigates to TripInvitationsScreen', (tester) async {
      final user = UserModel(
        id: 'test-user-id',
        email: 'test@feelingtrip.com',
        fullName: 'Nguyen Van Test',
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => Scaffold(
                  body: PersonalContent(
                    user: user,
                    onLogout: () {},
                  ),
                ),
            AppRoutes.tripInvitations: (context) => TripInvitationsScreen(
                  repository: MockTripRepository(),
                ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap shortcut 'Lời mời'
      await tester.tap(find.text('Lời mời'));
      await tester.pumpAndSettle();

      // We should now be on TripInvitationsScreen which has title 'Lời mời của tôi' in its app bar
      expect(find.byType(TripInvitationsScreen), findsOneWidget);
    });

    testWidgets('Tapping Lời mời của tôi list entry navigates to TripInvitationsScreen', (tester) async {
      final user = UserModel(
        id: 'test-user-id',
        email: 'test@feelingtrip.com',
        fullName: 'Nguyen Van Test',
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => Scaffold(
                  body: PersonalContent(
                    user: user,
                    onLogout: () {},
                  ),
                ),
            AppRoutes.tripInvitations: (context) => TripInvitationsScreen(
                  repository: MockTripRepository(),
                ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to make sure the entry is visible
      await tester.scrollUntilVisible(
        find.text('Lời mời của tôi'),
        200,
      );
      await tester.pumpAndSettle();

      // Tap list entry 'Lời mời của tôi'
      await tester.tap(find.text('Lời mời của tôi'));
      await tester.pumpAndSettle();

      // We should now be on TripInvitationsScreen
      expect(find.byType(TripInvitationsScreen), findsOneWidget);
    });
  });
}
