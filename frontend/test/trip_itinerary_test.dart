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
        'destinationProvider': 'GEOAPIFY',
        'destinationExternalId': 'ext-danang-123',
        'destinationLatitude': 16.0544,
        'destinationLongitude': 108.2022,
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
      expect(trip.destinationProvider, 'GEOAPIFY');
      expect(trip.destinationExternalId, 'ext-danang-123');
      expect(trip.destinationLatitude, 16.0544);
      expect(trip.destinationLongitude, 108.2022);
      expect(trip.isLeader, isTrue);
      expect(trip.isPublic, isTrue);
      expect(trip.isEditable, isTrue);
      expect(trip.members.length, 1);
    });

    test('TripFormData serializes destination coordinates', () {
      final data = TripFormData(
        destination: 'Đà Lạt',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 3),
        estimatedBudget: 3000000,
        privacyType: 'PRIVATE',
        destinationProvider: 'GEOAPIFY',
        destinationExternalId: 'ext-dalat-1',
        destinationLatitude: 11.9404,
        destinationLongitude: 108.4583,
      );

      final json = data.toJson();
      expect(json['destinationProvider'], 'GEOAPIFY');
      expect(json['destinationExternalId'], 'ext-dalat-1');
      expect(json['destinationLatitude'], 11.9404);
      expect(json['destinationLongitude'], 108.4583);

      final multipart = data.toMultipartFields();
      expect(multipart['destinationProvider'], 'GEOAPIFY');
      expect(multipart['destinationExternalId'], 'ext-dalat-1');
      expect(multipart['destinationLatitude'], '11.9404');
      expect(multipart['destinationLongitude'], '108.4583');
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
    test('TripViewModel excludes trips where membershipStatus is REMOVED', () async {
      final repo = _RemovedMemberTripRepository();
      final vm = TripViewModel(repository: repo);

      await vm.loadTrips();
      expect(vm.trips.any((t) => t.membershipStatus == 'REMOVED'), isFalse);
      expect(vm.trips.length, 1);
      expect(vm.trips.first.name, 'Chuyến đi hoạt động');
    });


    test('TripViewModel handles itinerary conflict validation gate error on transitionStatus (Approach C)', () async {
      final repo = _FailingConflictTripRepository();
      final vm = TripViewModel(repository: repo);
      await vm.loadTrips();
      final upcomingTrip = vm.trips.firstWhere((t) => t.status == 'UPCOMING');
      await vm.loadTrip(upcomingTrip.id);

      final success = await vm.transitionStatus('ONGOING');
      expect(success, isFalse);
      expect(vm.errorMessage, contains('chồng lấn'));
      expect(vm.selectedTrip?.status, 'UPCOMING');
    });

    test('MockTripRepository rejects ONGOING when trip has no itinerary days', () async {
      final itinRepo = MockItineraryRepository();
      itinRepo.setDaysForTrip('trip-no-days', []);
      final repo = MockTripRepository(itineraryRepository: itinRepo);

      final trip = TripModel(
        id: 'trip-no-days',
        name: 'Chuyến đi trống ngày',
        destination: 'Hà Nội',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 7)),
        estimatedBudget: 2000000,
        privacyType: 'PRIVATE',
        status: 'UPCOMING',
        memberRole: 'LEADER',
      );

      expect(
        () => repo.transitionStatus(trip, 'ONGOING'),
        throwsA(predicate((e) => e.toString().contains('chưa có lịch trình'))),
      );
    });

    test('MockTripRepository rejects ONGOING when days have no destinations', () async {
      final itinRepo = MockItineraryRepository();
      itinRepo.setDaysForTrip('trip-no-items', [
        ItineraryDay(
          id: 'day-empty',
          tripId: 'trip-no-items',
          dayNumber: 1,
          title: 'Ngày 1',
          tripDate: DateTime.now().add(const Duration(days: 5)),
          materialized: true,
          items: const [],
        ),
      ]);
      final repo = MockTripRepository(itineraryRepository: itinRepo);

      final trip = TripModel(
        id: 'trip-no-items',
        name: 'Chuyến đi chưa có điểm đến',
        destination: 'Hà Nội',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 7)),
        estimatedBudget: 2000000,
        privacyType: 'PRIVATE',
        status: 'UPCOMING',
        memberRole: 'LEADER',
      );

      expect(
        () => repo.transitionStatus(trip, 'ONGOING'),
        throwsA(predicate((e) => e.toString().contains('chưa có điểm đến'))),
      );
    });

    test('MockTripRepository rejects ONGOING when items have overlapping time slots', () async {
      final itinRepo = MockItineraryRepository();
      itinRepo.setDaysForTrip('trip-overlap', [
        ItineraryDay(
          id: 'day-overlap',
          tripId: 'trip-overlap',
          dayNumber: 1,
          title: 'Ngày 1',
          tripDate: DateTime.now().add(const Duration(days: 5)),
          materialized: true,
          items: const [
            ItineraryItem(
              id: 'item-1',
              itineraryId: 'day-overlap',
              customName: 'Nhà hát Lớn Hà Nội',
              category: 'ATTRACTION',
              startTime: '09:43',
              endTime: '11:13',
              estimatedCost: 0,
              isCompleted: false,
              version: '1',
            ),
            ItineraryItem(
              id: 'item-2',
              itineraryId: 'day-overlap',
              customName: 'Bảo tàng Dân tộc học Việt Nam',
              category: 'ATTRACTION',
              startTime: '08:00',
              endTime: '09:30',
              estimatedCost: 0,
              isCompleted: false,
              version: '1',
            ),
          ],
        ),
      ]);
      final repo = MockTripRepository(itineraryRepository: itinRepo);

      final trip = TripModel(
        id: 'trip-overlap',
        name: 'Chuyến đi lỗi giờ',
        destination: 'Hà Nội',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 7)),
        estimatedBudget: 2000000,
        privacyType: 'PRIVATE',
        status: 'UPCOMING',
        memberRole: 'LEADER',
      );

      expect(
        () => repo.transitionStatus(trip, 'ONGOING'),
        throwsA(predicate((e) =>
            e.toString().contains('chồng lấn') &&
            e.toString().contains('Nhà hát Lớn Hà Nội') &&
            e.toString().contains('Bảo tàng Dân tộc học'))),
      );
    });

    test('MockTripRepository allows ONGOING when items are valid and sequential', () async {
      final itinRepo = MockItineraryRepository();
      itinRepo.setDaysForTrip('trip-valid', [
        ItineraryDay(
          id: 'day-valid',
          tripId: 'trip-valid',
          dayNumber: 1,
          title: 'Ngày 1',
          tripDate: DateTime.now().add(const Duration(days: 5)),
          materialized: true,
          items: const [
            ItineraryItem(
              id: 'item-1',
              itineraryId: 'day-valid',
              customName: 'Bảo tàng Dân tộc học Việt Nam',
              category: 'ATTRACTION',
              startTime: '08:00',
              endTime: '09:30',
              estimatedCost: 0,
              isCompleted: false,
              version: '1',
            ),
            ItineraryItem(
              id: 'item-2',
              itineraryId: 'day-valid',
              customName: 'Nhà hát Lớn Hà Nội',
              category: 'ATTRACTION',
              startTime: '09:43',
              endTime: '11:13',
              estimatedCost: 0,
              isCompleted: false,
              version: '1',
            ),
          ],
        ),
      ]);
      final repo = MockTripRepository(itineraryRepository: itinRepo);

      final trip = TripModel(
        id: 'trip-valid',
        name: 'Chuyến đi hợp lệ',
        destination: 'Hà Nội',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 7)),
        estimatedBudget: 2000000,
        privacyType: 'PRIVATE',
        status: 'UPCOMING',
        memberRole: 'LEADER',
      );

      final updated = await repo.transitionStatus(trip, 'ONGOING');
      expect(updated.status, 'ONGOING');
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

    test('ItineraryItem parses locationSource and coordinates, gates Smart Swap', () {
      final catalogItem = ItineraryItem.fromJson({
        'id': 'item-1',
        'itineraryId': 'day-1',
        'placeId': 'place-uuid-1',
        'customName': 'Hồ Xuân Hương',
        'category': 'ATTRACTION',
        'startTime': '08:00',
        'endTime': '09:30',
        'locationSource': 'CATALOG',
        'latitude': 11.9404,
        'longitude': 108.4583,
      });
      expect(catalogItem.locationSource, 'CATALOG');
      expect(catalogItem.latitude, 11.9404);
      expect(catalogItem.longitude, 108.4583);
      expect(catalogItem.canSmartSwap, isTrue);
      expect(catalogItem.supportsSmartSwap, isTrue);

      final geoapifyItem = ItineraryItem.fromJson({
        'id': 'item-2',
        'itineraryId': 'day-1',
        'customName': 'Quảng trường Lâm Viên',
        'category': 'SIGHTSEEING',
        'startTime': '10:00',
        'endTime': '11:00',
        'locationSource': 'GEOAPIFY',
        'externalProvider': 'GEOAPIFY',
        'externalPlaceId': 'geo-123',
        'latitude': 11.9366,
        'longitude': 108.4452,
      });
      expect(geoapifyItem.locationSource, 'GEOAPIFY');
      expect(geoapifyItem.externalProvider, 'GEOAPIFY');
      expect(geoapifyItem.externalPlaceId, 'geo-123');
      expect(geoapifyItem.canSmartSwap, isFalse);
      expect(geoapifyItem.supportsSmartSwap, isFalse);

      final manualItem = ItineraryItem.fromJson({
        'id': 'item-3',
        'itineraryId': 'day-1',
        'customName': 'Ghé quán ven đường',
        'category': 'RESTAURANT',
        'startTime': '12:00',
        'endTime': '13:00',
        'locationSource': 'MANUAL',
      });
      expect(manualItem.locationSource, 'MANUAL');
      expect(manualItem.canSmartSwap, isFalse);
      expect(manualItem.supportsSmartSwap, isFalse);
    });

    test('ItineraryItemDraft serializes locationSource and coordinates', () {
      const draft = ItineraryItemDraft(
        customName: 'Chợ đêm',
        category: 'SHOPPING',
        startTime: '19:00',
        endTime: '21:00',
        estimatedCost: 0,
        locationSource: 'GEOAPIFY',
        externalProvider: 'GEOAPIFY',
        externalPlaceId: 'geo-456',
        latitude: 11.9412,
        longitude: 108.4378,
      );

      final json = draft.toCreateJson();
      expect(json['locationSource'], 'GEOAPIFY');
      expect(json['externalProvider'], 'GEOAPIFY');
      expect(json['externalPlaceId'], 'geo-456');
      expect(json['latitude'], 11.9412);
      expect(json['longitude'], 108.4378);

      final updateJson = draft.toUpdateJson('v1');
      expect(updateJson['expectedVersion'], 'v1');
      expect(updateJson['locationSource'], 'GEOAPIFY');
      expect(updateJson['latitude'], 11.9412);
      expect(updateJson['longitude'], 108.4378);
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

    test('MockItineraryRepository reorders items and recalculates sequential times (Approach A)', () async {
      final repo = MockItineraryRepository();
      final plan = await repo.getItinerary('trip-reorder-test');
      final day = plan.days.first;

      final item2 = await repo.addItem(
        day.id!,
        const ItineraryItemDraft(
          customName: 'Thung Lũng Tình Yêu',
          startTime: '10:00',
          endTime: '11:30',
          category: 'ATTRACTION',
          estimatedCost: 0,
        ),
      );

      final item3 = await repo.addItem(
        day.id!,
        const ItineraryItemDraft(
          customName: 'Ăn trưa',
          startTime: '11:30',
          endTime: '12:30',
          category: 'RESTAURANT',
          estimatedCost: 0,
        ),
      );

      final updatedPlan = await repo.getItinerary('trip-reorder-test');
      final currentDay = updatedPlan.days.first;
      expect(currentDay.items.length, 3);
      final item1 = currentDay.items[0];

      // Reorder items: [item2.id, item3.id, item1.id]
      final reorderedDay = await repo.reorderItems(
        currentDay,
        [item2.id, item3.id, item1.id],
      );

      // Item 2 starts at 10:00, dur 90m -> 10:00 - 11:30
      // Item 3 starts at 11:30, dur 60m -> 11:30 - 12:30
      // Item 1 starts at 12:30, dur 120m -> 12:30 - 14:30
      expect(reorderedDay.items[0].id, item2.id);
      expect(reorderedDay.items[0].startTime, '10:00');
      expect(reorderedDay.items[0].endTime, '11:30');

      expect(reorderedDay.items[1].id, item3.id);
      expect(reorderedDay.items[1].startTime, '11:30');
      expect(reorderedDay.items[1].endTime, '12:30');

      expect(reorderedDay.items[2].id, item1.id);
      expect(reorderedDay.items[2].startTime, '12:30');
      expect(reorderedDay.items[2].endTime, '14:30');
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

class _FailingConflictTripRepository extends MockTripRepository {
  @override
  Future<TripModel> transitionStatus(TripModel trip, String status) async {
    if (status == 'ONGOING') {
      throw Exception('Lịch trình chưa hợp lệ để bắt đầu chuyến đi: Ngày 1: "Điểm A" (kết thúc 10:00) chồng lấn với "Điểm B" (bắt đầu 09:30)');
    }
    return super.transitionStatus(trip, status);
  }
}

class _RemovedMemberTripRepository extends MockTripRepository {
  @override
  Future<TripPage> getMyTrips({String? status, bool includeHistory = true}) async {
    final activeTrip = TripModel(
      id: 'active-trip-1',
      name: 'Chuyến đi hoạt động',
      destination: 'Hà Nội',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 7)),
      estimatedBudget: 3000000,
      privacyType: 'PRIVATE',
      status: 'UPCOMING',
      membershipStatus: 'ACTIVE',
    );
    final removedTrip = TripModel(
      id: 'removed-trip-1',
      name: 'Chuyến đi bị kích',
      destination: 'Đà Lạt',
      startDate: DateTime.now().add(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 4)),
      estimatedBudget: 2000000,
      privacyType: 'PRIVATE',
      status: 'UPCOMING',
      membershipStatus: 'REMOVED',
    );
    return TripPage(items: [activeTrip, removedTrip], total: 2);
  }
}

