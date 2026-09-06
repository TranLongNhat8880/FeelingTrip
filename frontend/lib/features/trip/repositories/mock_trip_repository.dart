import '../models/trip_model.dart';
import 'trip_repository.dart';

// ================================================================================
// MOCK REPOSITORY: Trip (DỮ LIỆU GIẢ)
// ================================================================================

class MockTripRepository implements TripRepository {
  // Data giả
  final List<TripModel> _mockTrips = [
    TripModel(
      id: 1,
      name: 'Du lịch Đà Nẵng - Hội An',
      destination: 'Đà Nẵng',
      startDate: DateTime(2026, 10, 15),
      endDate: DateTime(2026, 10, 18),
      budget: 5000000,
      status: 'upcoming',
      isPublic: true,
      createdBy: 1,
    ),
    TripModel(
      id: 2,
      name: 'Khám phá Đà Lạt',
      destination: 'Đà Lạt',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 4),
      budget: 3000000,
      status: 'completed',
      isPublic: false,
      createdBy: 1,
    ),
    TripModel(
      id: 3,
      name: 'Phú Quốc cùng nhóm',
      destination: 'Phú Quốc',
      startDate: DateTime(2026, 12, 20),
      endDate: DateTime(2026, 12, 25),
      budget: 8000000,
      status: 'upcoming',
      isPublic: true,
      createdBy: 1,
    ),
  ];

  @override
  Future<List<TripModel>> getMyTrips() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _mockTrips;
  }

  @override
  Future<TripModel> getTripById(int id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockTrips.firstWhere((t) => t.id == id);
  }

  @override
  Future<TripModel> createTrip(TripModel trip) async {
    await Future.delayed(const Duration(seconds: 1));
    return trip;
  }

  @override
  Future<TripModel> updateTrip(int id, TripModel trip) async {
    await Future.delayed(const Duration(seconds: 1));
    return trip;
  }

  @override
  Future<void> deleteTrip(int id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockTrips.removeWhere((t) => t.id == id);
  }
}
