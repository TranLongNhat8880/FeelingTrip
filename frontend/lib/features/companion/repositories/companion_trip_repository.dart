import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'mock_companion_repository.dart';

// Chọn chuyến đi và đổi quyền riêng tư khi người dùng xác nhận đăng tuyển.
class CompanionTripRepository {
  Future<bool> hasPostForTrip(String tripId) async {
    if (ApiEndpoints.useMockData) {
      return MockCompanionRepository().hasPostForTrip(tripId);
    }
    final response = await ApiClient.get(
      '${ApiEndpoints.companions}/posted-trips',
    );
    return (response['data'] as List).any((id) => id.toString() == tripId);
  }

  Future<bool> isPublicTrip(String tripId) async {
    if (ApiEndpoints.useMockData) return true;
    final response = await ApiClient.get('${ApiEndpoints.trips}/$tripId');
    return response['data']['privacyType'] == 'PUBLIC';
  }

  Future<void> makePublic(String tripId) async {
    if (ApiEndpoints.useMockData) return;
    final response = await ApiClient.get('${ApiEndpoints.trips}/$tripId');
    final trip = response['data'];
    if (trip['privacyType'] == 'PUBLIC') return;
    await ApiClient.patch(
      '${ApiEndpoints.trips}/$tripId',
      body: {'privacyType': 'PUBLIC', 'expectedUpdatedAt': trip['updatedAt']},
    );
  }

  Future<List<Map<String, String>>> getMyTrips() async {
    final response = await ApiClient.get(
      '${ApiEndpoints.companions}/posted-trips',
    );
    final postedTripIds = (response['data'] as List)
        .map((id) => id.toString())
        .toSet();
    final trips = <Map<String, String>>[];
    var page = 1;
    while (true) {
      final response = await ApiClient.get(
        '${ApiEndpoints.trips}/my-trips?page=$page&limit=50',
      );
      final data = response['data'] as Map<String, dynamic>;
      for (final trip in data['items'] as List) {
        if (trip['memberRole'] != 'LEADER' ||
            ['COMPLETED', 'CANCELLED'].contains(trip['status'])) {
          continue;
        }
        trips.add({
          'id': trip['id'].toString(),
          'hasCompanionPost':
              '${postedTripIds.contains(trip['id'].toString())}',
          'privacyType': trip['privacyType'] ?? 'PRIVATE',
          'name': trip['name'] ?? '',
          'destination': trip['destination'] ?? '',
          'dates':
              '${DateFormat('dd/MM/yyyy').format(DateTime.parse(trip['startDate']).toLocal())} – ${DateFormat('dd/MM/yyyy').format(DateTime.parse(trip['endDate']).toLocal())}',
          'status': trip['status'] ?? '',
          'image': trip['coverImageUrl'] ?? '',
        });
      }
      if (page >= ((data['pagination']['totalPages'] as num?) ?? 1)) break;
      page++;
    }
    return trips;
  }
}
