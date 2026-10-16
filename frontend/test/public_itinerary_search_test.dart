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
    testWidgets('renders filter pills, search input, sort dropdown and cards', (tester) async {
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

      // Verify filter pills
      expect(find.widgetWithText(ChoiceChip, 'Mẫu hệ thống'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Cộng đồng'), findsOneWidget);

      // Verify search input
      expect(find.text('Tên lịch trình hoặc điểm đến'), findsOneWidget);

      // Verify sort dropdown
      expect(find.text('Mới nhất'), findsOneWidget);

      // Verify cards loaded
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('switching between Mẫu hệ thống and Cộng đồng chips', (tester) async {
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

      await tester.tap(find.widgetWithText(ChoiceChip, 'Mẫu hệ thống'));
      await tester.pumpAndSettle();

      final ChoiceChip systemChip = tester.widget(find.widgetWithText(ChoiceChip, 'Mẫu hệ thống'));
      expect(systemChip.selected, isTrue);
    });

    testWidgets('tapping search bar navigates to PublicItinerarySearchScreen and applies filter', (tester) async {
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

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Verify opened PublicItinerarySearchScreen with suggestions
      expect(find.byType(PublicItinerarySearchScreen), findsOneWidget);
      expect(find.text('Gợi ý điểm đến phổ biến'), findsOneWidget);
      expect(find.text('Hà Nội'), findsWidgets);

      // Tap popular destination chip 'Hà Nội'
      await tester.tap(find.widgetWithText(ActionChip, 'Hà Nội'));
      await tester.pumpAndSettle();

      // Verify results appear
      expect(find.textContaining('kết quả cho “Hà Nội”'), findsOneWidget);

      // Tap 'Chọn lọc này' to return to PublicItinerariesScreen
      await tester.tap(find.text('Chọn lọc này'));
      await tester.pumpAndSettle();

      // Verify returned to PublicItinerariesScreen with filter active
      expect(find.byType(PublicItinerariesScreen), findsOneWidget);
      expect(find.text('Đang lọc: Hà Nội'), findsOneWidget);
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

    testWidgets('source: SYSTEM searches system templates only', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PublicItinerarySearchScreen(
            source: 'SYSTEM',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mẫu hệ thống'));
      expect(chip.selected, isTrue);

      final input = find.byType(TextField);
      await tester.enterText(input, 'Hà Nội');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Should find the system template for Hanoi
      expect(find.textContaining('Khám phá Hà Nội'), findsOneWidget);
      // Should NOT find community trekking
      expect(find.text('Trekking'), findsNothing);
    });

    testWidgets('source: COMMUNITY searches community plans only', (tester) async {
      final repo = MockItineraryRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicItinerarySearchScreen(
            source: 'COMMUNITY',
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cộng đồng'));
      expect(chip.selected, isTrue);

      final input = find.byType(TextField);
      await tester.enterText(input, 'Hà Nội');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Should find the community plan for Hanoi
      expect(find.textContaining('Chuyến đi Hà Nội'), findsOneWidget);
      // Should NOT find system template
      expect(find.text('Khám phá Hà Nội 2 ngày 1 đêm'), findsNothing);
    });
  });
}
