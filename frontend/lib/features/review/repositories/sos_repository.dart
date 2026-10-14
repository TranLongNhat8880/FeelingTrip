import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/sos_model.dart';

abstract class SosRepository {
  Future<SosAlert?> getActive(String tripId);
  Future<SosAlert> create({
    required String tripId,
    required SosLocation location,
    required String message,
  });
  Future<SosAlert> finish(String id, String status);
}

class SosHistoryPage {
  const SosHistoryPage({required this.items, required this.hasMore});
  final List<SosAlert> items;
  final bool hasMore;
}

abstract class SosHistoryRepository {
  Future<SosHistoryPage> getHistory({int offset = 0, int limit = 20});
}

class ApiSosRepository implements SosRepository, SosHistoryRepository {
  @override
  Future<SosHistoryPage> getHistory({int offset = 0, int limit = 20}) async {
    final query = Uri(
      queryParameters: {'offset': '$offset', 'limit': '$limit'},
    ).query;
    final response = await ApiClient.get(
      '${ApiEndpoints.reviews}/sos/history?$query',
    );
    final data = response['data'];
    if (data is! Map || data['items'] is! List || data['hasMore'] is! bool) {
      throw const FormatException('Phản hồi lịch sử SOS không hợp lệ.');
    }
    final items = (data['items'] as List).map(_alert).toList();
    if (items.length > limit || (data['hasMore'] == true && items.isEmpty)) {
      throw const FormatException('Phân trang SOS không hợp lệ.');
    }
    return SosHistoryPage(items: items, hasMore: data['hasMore']);
  }

  SosAlert _alert(Object? data) {
    if (data is! Map) throw const FormatException('Phản hồi SOS không hợp lệ.');
    return SosAlert.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<SosAlert?> getActive(String tripId) async {
    final query = Uri(queryParameters: {'tripId': tripId}).query;
    final response = await ApiClient.get(
      '${ApiEndpoints.reviews}/sos/active?$query',
    );
    if (!response.containsKey('data')) {
      throw const FormatException('Thiếu trạng thái SOS.');
    }
    return response['data'] == null ? null : _alert(response['data']);
  }

  @override
  Future<SosAlert> create({
    required String tripId,
    required SosLocation location,
    required String message,
  }) async {
    final response = await ApiClient.post(
      '${ApiEndpoints.reviews}/sos',
      body: {
        'tripId': tripId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'message': message,
      },
    );
    return _alert(response['data']);
  }

  @override
  Future<SosAlert> finish(String id, String status) async {
    if (!['RESOLVED', 'FALSE_ALARM'].contains(status)) {
      throw ArgumentError('Trạng thái SOS không hợp lệ');
    }
    final response = await ApiClient.put(
      '${ApiEndpoints.reviews}/sos/${Uri.encodeComponent(id)}/status',
      body: {'status': status},
    );
    return _alert(response['data']);
  }
}
