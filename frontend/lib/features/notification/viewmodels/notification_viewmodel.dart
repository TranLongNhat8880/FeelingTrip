import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.postId,
    this.isRead = false,
  });
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final String? postId;
  bool isRead;
  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'].toString(),
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        type: json['type'] ?? 'SYSTEM',
        createdAt: DateTime.parse(json['created_at']).toLocal(),
        isRead: json['is_read'] == true,
        postId: (json['data'] as Map?)?['postId'] as String?,
      );
}

abstract class NotificationRepository {
  Future<List<NotificationItem>> getNotifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> delete(String id);
  Future<void> deleteAll();
}

class ApiNotificationRepository implements NotificationRepository {
  @override
  Future<List<NotificationItem>> getNotifications() async {
    final items = <NotificationItem>[];
    var page = 1;
    // API trả mảng, không có tổng số trang. Đọc các trang đến khi hết dữ liệu.
    while (true) {
      final response = await ApiClient.get(
        '/notifications?page=$page&limit=100&sortBy=createdAt',
      );
      final rows = response['data'] as List;
      items.addAll(
        rows.map(
          (row) => NotificationItem.fromJson(row as Map<String, dynamic>),
        ),
      );
      if (rows.length < 100) break;
      page++;
    }
    return items;
  }

  @override
  Future<void> markRead(String id) async {
    await ApiClient.put('/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await ApiClient.put('/notifications/read-all');
  }

  @override
  Future<void> delete(String id) async {
    await ApiClient.delete('/notifications/$id');
  }

  @override
  Future<void> deleteAll() async {
    await ApiClient.delete('/notifications');
  }
}

class MockNotificationRepository implements NotificationRepository {
  final items = [
    NotificationItem(
      id: 'n1',
      title: 'Có người muốn đồng hành cùng bạn',
      message:
          'Ngọc Anh gửi lời giới thiệu cho chuyến Hội An. Hãy xem yêu cầu trước khi quyết định.',
      type: 'REQUEST',
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    NotificationItem(
      id: 'n2',
      title: 'Khám phá hành trình Hội An',
      message:
          'Đoàn đang tuyển thêm bạn đồng hành. Xem thông tin chuyến đi và những người cùng tham gia.',
      type: 'TRIP_UPDATE',
      postId: 'post-1',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationItem(
      id: 'n3',
      title: 'Hồ sơ của bạn đã được xác minh',
      message:
          'Bạn có thể đăng bài tuyển bạn đồng hành cho chuyến đi mình quản lý.',
      type: 'SYSTEM',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];
  @override
  Future<List<NotificationItem>> getNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return items;
  }

  @override
  Future<void> markRead(String id) async {
    items.firstWhere((item) => item.id == id).isRead = true;
  }

  @override
  Future<void> markAllRead() async {
    for (final item in items) {
      item.isRead = true;
    }
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> deleteAll() async {
    items.clear();
  }
}

class NotificationViewModel extends ChangeNotifier {
  NotificationViewModel({NotificationRepository? repository})
    : _repository =
          repository ??
          (ApiEndpoints.useMockData
              ? MockNotificationRepository()
              : ApiNotificationRepository());
  final NotificationRepository _repository;
  List<NotificationItem> items = [];
  bool isLoading = false;
  bool isUpdating = false;
  bool unreadOnly = true;
  String? errorMessage;
  bool _disposed = false;
  int get unreadCount => items.where((item) => !item.isRead).length;
  List<NotificationItem> get visibleItems =>
      items.where((item) => !unreadOnly || !item.isRead).toList();
  Future<void> load() async {
    if (_disposed || isLoading || isUpdating) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.getNotifications();
      if (!_disposed) items = List.of(result);
    } catch (error) {
      errorMessage = error is ApiException
          ? error.message
          : 'Không tải được thông báo. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void filter(bool value) {
    unreadOnly = value;
    notifyListeners();
  }

  Future<bool> _update(
    Future<void> Function() action,
    void Function() change,
  ) async {
    if (_disposed || isUpdating || isLoading) return false;
    isUpdating = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      if (_disposed) return false;
      change();
      return true;
    } catch (error) {
      errorMessage = error is ApiException
          ? error.message
          : 'Chưa cập nhật được thông báo. Vui lòng thử lại.';
      return false;
    } finally {
      isUpdating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> markRead(NotificationItem item) =>
      _update(() => _repository.markRead(item.id), () => item.isRead = true);
  Future<bool> markAllRead() => _update(_repository.markAllRead, () {
    for (final item in items) {
      item.isRead = true;
    }
  });
  Future<bool> delete(NotificationItem item) => _update(
    () => _repository.delete(item.id),
    () => items.removeWhere((value) => value.id == item.id),
  );
  Future<bool> deleteAll() => _update(_repository.deleteAll, () => items = []);
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
