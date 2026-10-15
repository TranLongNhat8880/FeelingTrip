import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/trip_reviews_model.dart';

abstract class TripReviewsRepository {
  Future<TripReviewsPage> getTripReviews(
    String tripId, {
    int page = 1,
    int limit = 20,
  });
}

class ApiTripReviewsRepository implements TripReviewsRepository {
  @override
  Future<TripReviewsPage> getTripReviews(
    String tripId, {
    int page = 1,
    int limit = 20,
  }) async {
    final id = tripId.trim();
    if (id.isEmpty || page < 1 || page > 100000 || limit < 1 || limit > 50) {
      throw ArgumentError('Mã chuyến đi hoặc phân trang không hợp lệ.');
    }
    final query = Uri(
      queryParameters: {'page': '$page', 'limit': '$limit'},
    ).query;
    final response = await ApiClient.get(
      '${ApiEndpoints.reviews}/trip/${Uri.encodeComponent(id)}?$query',
    );
    final data = response['data'];
    if (data is! Map) throw const FormatException('Thiếu danh sách đánh giá.');
    final result = TripReviewsPage.fromJson(Map<String, dynamic>.from(data));
    if (result.tripId.toLowerCase() != id.toLowerCase() ||
        result.page != page ||
        result.limit != limit) {
      throw const FormatException(
        'Phản hồi không khớp chuyến đi/phân trang yêu cầu.',
      );
    }
    return result;
  }
}
