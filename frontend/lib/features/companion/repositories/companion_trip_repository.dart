import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

// Chỉ đọc chuyến đi để chọn khi đăng bài, không thay luồng quản lý trip.
class CompanionTripRepository {
  Future<List<Map<String, String>>> getMyTrips() async {
    final response = await ApiClient.get('${ApiEndpoints.companions}/posted-trips');
    final postedTripIds = (response['data'] as List).map((id) => id.toString()).toSet();
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
          'hasCompanionPost': '${postedTripIds.contains(trip['id'].toString())}',
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
