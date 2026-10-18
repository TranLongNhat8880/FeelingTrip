import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/trip_reviews_model.dart';
import '../repositories/trip_reviews_repository.dart';

class TripReviewsViewModel extends ChangeNotifier {
  TripReviewsViewModel({
    required this.tripId,
    TripReviewsRepository? repository,
  }) : _repository = repository ?? ApiTripReviewsRepository();

  final String tripId;
  final TripReviewsRepository _repository;
  final List<TripReviewItem> _items = [];
  List<TripReviewItem> get items => List.unmodifiable(_items);
  TripReviewsPage? summary;
  bool loading = false, loadingMore = false;
  String? error;
  bool _disposed = false, _retryMore = false;
  int _page = 0;
  bool get hasMore => summary?.hasMore == true;

  Future<void> retry() => load(more: _retryMore);

  Future<void> load({bool more = false}) async {
    if (_disposed || loading || (more && !hasMore)) return;
    loading = true;
    loadingMore = more;
    _retryMore = more;
    error = null;
    notifyListeners();
    final requestedPage = more ? _page + 1 : 1;
    try {
      final result = await _repository
          .getTripReviews(tripId, page: requestedPage)
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;
      if (result.tripId.toLowerCase() != tripId.toLowerCase() ||
          result.page != requestedPage) {
        throw const FormatException('Đánh giá không khớp lịch trình.');
      }
      final merged = more ? [..._items, ...result.items] : result.items;
      _items
        ..clear()
        ..addAll({for (final item in merged) item.id: item}.values);
      summary = result;
      _page = result.page;
    } catch (exception) {
      if (_disposed) return;
      if (exception is ApiException &&
          [401, 403, 404].contains(exception.statusCode)) {
        // Do not retain comments after the trip is made private or access expires.
        _items.clear();
        summary = null;
        _page = 0;
        _retryMore = false;
        error = exception.statusCode == 404
            ? 'Không thể xem đánh giá. Lịch trình không còn công khai hoặc không còn tồn tại.'
            : 'Không thể xem đánh giá. Hãy kiểm tra phiên đăng nhập của bạn.';
      } else {
        error = more
            ? 'Chưa tải được các đánh giá tiếp theo. Hãy thử lại.'
            : 'Chưa tải được đánh giá chuyến đi. Hãy thử lại.';
      }
    } finally {
      if (!_disposed) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
