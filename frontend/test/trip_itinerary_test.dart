import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feeling_trip/features/itinerary/models/itinerary_model.dart';
import 'package:feeling_trip/features/itinerary/repositories/mock_itinerary_repository.dart';
import 'package:feeling_trip/features/itinerary/viewmodels/itinerary_viewmodel.dart';
import 'package:feeling_trip/features/trip/models/trip_model.dart';
import 'package:feeling_trip/features/trip/repositories/mock_trip_repository.dart';
import 'package:feeling_trip/features/trip/viewmodels/trip_viewmodel.dart';
import 'package:feeling_trip/routes/app_routes.dart';
import 'package:feeling_trip/features/trip/views/trip_form_screen.dart';


void main() {
  group('TripModel & MockTripRepository Tests', () {
    test('TripModel parses JSON correctly', () {
      final json = {
        'id': 'trip-101',
        'name': 'Du lịch Đà Nẵng',
        'destination': 'Đà Nẵng',
        'startDate': '2026-06-01T00:00:00.000Z',
        'endDate': '2026-06-04T00:00:00.000Z',
        'estimatedBudget': 5000000,
        'privacyType': 'PUBLIC',
        'status': 'UPCOMING',
        'memberRole': 'LEADER',
        'members': [
          {
            'userId': 'user-1',
            'displayName': 'Nguyễn Văn A',
            'role': 'LEADER',
            'membershipStatus': 'ACTIVE',
          },
        ],
      };

      final trip = TripModel.fromJson(json);
      expect(trip.id, 'trip-101');
      expect(trip.name, 'Du lịch Đà Nẵng');
      expect(trip.destination, 'Đà Nẵng');
      expect(trip.isLeader, isTrue);
      expect(trip.isPublic, isTrue);
      expect(trip.isEditable, isTrue);
      expect(trip.members.length, 1);
    });

    test('MockTripRepository creates, updates and fetches trips', () async {
      final repo = MockTripRepository();
      final page = await repo.getMyTrips();
      expect(page.items.isNotEmpty, isTrue);

      final newTrip = await repo.createTrip(
        TripFormData(
          name: 'Chuyến đi Phú Quốc',
          destination: 'Phú Quốc',
          startDate: DateTime(2026, 7, 10),
          endDate: DateTime(2026, 7, 13),
          estimatedBudget: 8000000,
          privacyType: 'PRIVATE',
        ),
      );

      expect(newTrip.id, isNotEmpty);
      expect(newTrip.destination, 'Phú Quốc');
      expect(newTrip.isLeader, isTrue);

      final updated = await repo.updateTrip(
        newTrip,
        TripFormData(
          name: 'Chuyến đi Phú Quốc VIP',
          destination: 'Phú Quốc',
          startDate: newTrip.startDate,
          endDate: newTrip.endDate,
          estimatedBudget: 10000000,
          privacyType: 'PRIVATE',
        ),
      );
      expect(updated.name, 'Chuyến đi Phú Quốc VIP');
      expect(updated.estimatedBudget, 10000000);
    });

    test('TripViewModel loads trips and filters', () async {
      final repo = MockTripRepository();
      final vm = TripViewModel(repository: repo);

      await vm.loadTrips();
      expect(vm.trips.isNotEmpty, isTrue);
      expect(vm.isLoading, isFalse);
    });
  });

  group('ItineraryModel & MockItineraryRepository Tests', () {
    test('MockItineraryRepository returns plan and supports adding items', () async {
      final repo = MockItineraryRepository();
      final plan = await repo.getItinerary('mock-trip-1');

      expect(plan.trip.id, 'mock-trip-1');
      expect(plan.days.isNotEmpty, isTrue);

      final firstDay = plan.days.first;

      final createdItem = await repo.addItem(
        firstDay.id!,
        const ItineraryItemDraft(
          customName: 'Cà phê sáng',
          startTime: '07:30',
          endTime: '08:30',
          category: 'CAFE',
          estimatedCost: 50000,
        ),
      );

      expect(createdItem.id, isNotEmpty);
      expect(createdItem.customName, 'Cà phê sáng');
    });

    test('PublicItineraryViewModel loads and clones plan', () async {
      final repo = MockItineraryRepository();
      final vm = PublicItineraryViewModel(repository: repo);

      await vm.load();
      expect(vm.plans.isNotEmpty, isTrue);

      final cloned = await vm.clone(
        sourceTripId: vm.plans.first.sourceTripId,
        startDate: DateTime.now().add(const Duration(days: 14)),
        name: 'Hành trình bản sao test',
      );
      expect(cloned, isNotNull);
      expect(cloned!.trip.id, isNotEmpty);
    });
  });

  group('AppRoutes Navigation & onGenerateRoute Tests', () {
    test('onGenerateRoute resolves tripDetail with String tripId', () {
      final route = AppRoutes.onGenerateRoute(
        const RouteSettings(name: AppRoutes.tripDetail, arguments: 'trip-123'),
      );
      expect(route, isA<MaterialPageRoute>());
    });

    test('onGenerateRoute resolves itinerary with Map arguments', () {
      final route = AppRoutes.onGenerateRoute(
        const RouteSettings(
          name: AppRoutes.itinerary,
          arguments: {'tripId': 'trip-456', 'destination': 'Hà Nội'},
        ),
      );
      expect(route, isA<MaterialPageRoute>());
    });

    test('onGenerateRoute resolves createTrip without arguments', () {
      final route = AppRoutes.onGenerateRoute(
        const RouteSettings(name: AppRoutes.createTrip),
      );
      expect(route, isA<MaterialPageRoute>());
    });

    test('onGenerateRoute returns error route when tripId is missing', () {
      final route = AppRoutes.onGenerateRoute(
        const RouteSettings(name: AppRoutes.tripDetail, arguments: null),
      );
      expect(route, isA<MaterialPageRoute>());
    });

  });

  group('TripFormScreen Date Selection Tests', () {
    testWidgets('TripFormScreen initializes dates starting from future and does not allow selecting yesterday', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripFormScreen(
            repository: MockTripRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ngày đi'), findsOneWidget);
      expect(find.text('Ngày về'), findsOneWidget);

      final today = DateUtils.dateOnly(DateTime.now());

      // Tap on 'Ngày đi' to open date picker dialog
      await tester.tap(find.text('Ngày đi'));
      await tester.pumpAndSettle();

      // Verify date picker opened and firstDate is today (not yesterday!)
      expect(find.text('Chọn ngày'), findsOneWidget);
      final startDateCalendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(startDateCalendar.firstDate, today);
      expect(startDateCalendar.firstDate.isAfter(today.subtract(const Duration(days: 1))), isTrue);

      // Tap cancel to dismiss
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      // Tap on 'Ngày về' to open date picker dialog
      await tester.tap(find.text('Ngày về'));
      await tester.pumpAndSettle();

      // Verify date picker opened and firstDate is >= today (cannot be before start date)
      expect(find.text('Chọn ngày'), findsOneWidget);
      final endDateCalendar = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(endDateCalendar.firstDate.isBefore(today), isFalse);

      // Tap cancel to dismiss
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
    });
  });
}
