/// Read-only reviews of the source trip in the community itinerary library.
/// These are not companion reviews or a separate chat/comment thread.
class TripReviewAuthor {
  const TripReviewAuthor({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });
  final String id, displayName;
  final String? avatarUrl;

  factory TripReviewAuthor.fromJson(Map<String, dynamic> json) =>
      TripReviewAuthor(
        id: _requiredString(json['id']),
        displayName: _requiredString(json['displayName']),
        avatarUrl: _optionalString(json['avatarUrl']),
      );
}

class TripReviewItem {
  const TripReviewItem({
    required this.id,
    required this.tripId,
    required this.rating,
    required this.createdAt,
    required this.reviewer,
    this.comment,
  });
  final String id, tripId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final TripReviewAuthor reviewer;

  factory TripReviewItem.fromJson(Map<String, dynamic> json) {
    final rating = _integer(json['rating']);
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (rating < 1 || rating > 5 || createdAt == null) {
      throw const FormatException('Đánh giá chuyến đi không hợp lệ.');
    }
    return TripReviewItem(
      id: _requiredString(json['id']),
      tripId: _requiredString(json['tripId']),
      rating: rating,
      createdAt: createdAt,
      comment: _optionalString(json['comment']),
      reviewer: TripReviewAuthor.fromJson(_map(json['reviewer'])),
    );
  }
}

class TripReviewsPage {
  const TripReviewsPage({
    required this.tripId,
    required this.averageRating,
    required this.reviewCount,
    required this.items,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
  final String tripId;
  final double averageRating;
  final int reviewCount, page, limit, totalPages;
  final List<TripReviewItem> items;
  bool get hasMore => page < totalPages;

  factory TripReviewsPage.fromJson(Map<String, dynamic> json) {
    final tripId = _requiredString(json['tripId']);
    final averageRating = double.tryParse('${json['averageRating']}');
    final count = _integer(json['reviewCount']);
    final pagination = _map(json['pagination']);
    final page = _integer(pagination['page']);
    final limit = _integer(pagination['limit']);
    final total = _integer(pagination['total']);
    final totalPages = _integer(pagination['totalPages']);
    if (json['items'] is! List ||
        averageRating == null ||
        !averageRating.isFinite ||
        averageRating < 0 ||
        averageRating > 5 ||
        count < 0 ||
        total != count ||
        page < 1 ||
        limit < 1 ||
        limit > 50 ||
        totalPages != (count / limit).ceil() ||
        (count == 0 && averageRating != 0)) {
      throw const FormatException('Danh sách đánh giá không hợp lệ.');
    }
    final items = (json['items'] as List)
        .map((item) => TripReviewItem.fromJson(_map(item)))
        .toList();
    if (items.length > limit ||
        items.length > count ||
        items.any(
          (item) => item.tripId.toLowerCase() != tripId.toLowerCase(),
        )) {
      throw const FormatException('Danh sách đánh giá không khớp chuyến đi.');
    }
    return TripReviewsPage(
      tripId: tripId,
      averageRating: averageRating,
      reviewCount: count,
      items: List.unmodifiable(items),
      page: page,
      limit: limit,
      totalPages: totalPages,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Thiếu dữ liệu đánh giá.');
  return Map<String, dynamic>.from(value);
}

String _requiredString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Thiếu thông tin đánh giá.');
  }
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Thông tin đánh giá không hợp lệ.');
  }
  return value.trim().isEmpty ? null : value;
}

int _integer(Object? value) {
  final result = int.tryParse('$value');
  if (result == null) {
    throw const FormatException('Số liệu đánh giá không hợp lệ.');
  }
  return result;
}
