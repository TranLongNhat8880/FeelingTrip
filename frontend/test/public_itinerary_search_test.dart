import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/features/auth/repositories/mock_auth_repository.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/home/views/home_screen.dart';
import 'package:feeling_trip/features/itinerary/repositories/mock_itinerary_repository.dart';
import 'package:feeling_trip/features/itinerary/views/public_itineraries_screen.dart';
import 'package:feeling_trip/features/itinerary/views/public_itinerary_search_screen.dart';

void main() {
  group('HomeScreen Bottom Navigation Item', () {
    testWidgets('shows Cộng đồng instead of Lịch trình in bottom navigation', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthViewModel(repository: MockAuthRepository());
      await tester.runAsync(
        () => auth.login('user.ekyc@feelingtrip.com', 'demo'),
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        AuthScope(
          auth: auth,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check bottom nav bar label 'Cộng đồng' is present
      expect(find.text('Cộng đồng'), findsOneWidget);
      // Check old label 'Lịch trình' is not on bottom navigation bar
      expect(find.text('Lịch trình'), findsNothing);
    });
  });

  group('MockItineraryRepository Public Plans Filtering', () {
    test('getPublicPlans returns all plans when no filters provided', () async {
      final repo = MockItineraryRepository();
      final page = await repo.getPublicPlans();
      expect(page.items.length, greaterThanOrEqualTo(5));
    });

    test('getPublicPlans filters by destination', () async {
      final repo = MockItineraryRepository();
      final page = await repo.getPublicPlans(destination: 'Hà Nội');
      expect(page.items, isNotEmpty);
      expect(page.items.every((p) => p.destination.contains('Hà Nội')), isTrue);
    });

    test('getPublicPlans filters by keyword matching name, destination, or description', () async {
      final repo = MockItineraryRepository();
      final page = await repo.getPublicPlans(keyword: 'Đà Lạt');
      expect(page.items, isNotEmpty);
      expect(page.items.any((p) => p.destination == 'Đà Lạt'), isTrue);
    });

    test('getPublicPlans returns empty when no matching keyword', () async {
      final repo = MockItineraryRepository();
      final page = await repo.getPublicPlans(keyword: 'Địa điểm không tồn tại 12345');
      expect(page.items, isEmpty);
    });
  });

  group('PublicItinerariesScreen Widget Tests', () {
    testWidgets('cleans up notice & destination input, retains system templates button', (tester) async {
      final repo = MockItineraryRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicItinerariesScreen(
            repository: repo,
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify blue info notice is removed
      expect(find.textContaining('Chỉ hiển thị chuyến đi công khai đã hoàn thành'), findsNothing);

      // Verify "Xem lịch trình mẫu hệ thống" button is present
      expect(find.text('Xem lịch trình mẫu hệ thống'), findsOneWidget);

      // Verify "Điểm đến" input field is removed
      expect(find.widgetWithText(TextField, 'Điểm đến'), findsNothing);

      // Verify new search bar is present
      expect(find.text('Tìm kiếm lịch trình, điểm đến...'), findsOneWidget);

      // Verify section header "Lịch trình cộng đồng" is present
      expect(find.text('Lịch trình cộng đồng'), findsOneWidget);
    });

    testWidgets('opening PlanLibraryScreen does not contain Cộng đồng section', (tester) async {
      final repo = MockItineraryRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicItinerariesScreen(
            repository: repo,
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xem lịch trình mẫu hệ thống'));
      await tester.pumpAndSettle();

      // Screen title should be Lịch trình mẫu hệ thống
      expect(find.text('Lịch trình mẫu hệ thống'), findsOneWidget);
      // There should NOT be a "Cộng đồng" chip inside PlanLibraryScreen
      expect(find.widgetWithText(ChoiceChip, 'Cộng đồng'), findsNothing);
    });

    testWidgets('tapping search bar navigates to PublicItinerarySearchScreen', (tester) async {
      final repo = MockItineraryRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicItinerariesScreen(
            repository: repo,
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchBar = find.text('Tìm kiếm lịch trình, điểm đến...');
      expect(searchBar, findsOneWidget);

      await tester.tap(searchBar);
      await tester.pumpAndSettle();

      // Verified navigated to PublicItinerarySearchScreen
      expect(find.byType(PublicItinerarySearchScreen), findsOneWidget);
      expect(find.text('Gợi ý điểm đến phổ biến'), findsOneWidget);
      expect(find.text('Hà Nội'), findsWidgets);
      expect(find.text('Đà Lạt'), findsWidgets);
    });
  });

  group('PublicItinerarySearchScreen Widget Tests', () {
    testWidgets('shows suggestions and triggers search on submitted', (tester) async {
      final repo = MockItineraryRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicItinerarySearchScreen(
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check initial suggestions
      expect(find.text('Gợi ý điểm đến phổ biến'), findsOneWidget);
      expect(find.text('Đà Nẵng'), findsWidgets);

      // Enter search query
      final input = find.byType(TextField);
      await tester.enterText(input, 'Hà Nội');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Check search results appear
      expect(find.textContaining('kết quả cho “Hà Nội”'), findsOneWidget);
      expect(find.byType(PublicPlanCard), findsWidgets);
    });
  });
}
