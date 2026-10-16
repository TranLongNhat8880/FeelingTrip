import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.role = 'USER',
    this.status = 'ACTIVE',
    this.verification = 'UNVERIFIED',
    this.submittedAt,
    this.reason,
    this.cccdNumber,
    this.frontImage,
    this.backImage,
    this.selfieImage,
  });
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String role;
  String status;
  String verification;
  final DateTime? submittedAt;
  String? reason;
  final String? cccdNumber, frontImage, backImage, selfieImage;
  String? document(String label) => label == 'CCCD mặt trước'
      ? frontImage
      : label == 'CCCD mặt sau'
      ? backImage
      : selfieImage;
  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'].toString(),
    name: json['fullName'] ?? '',
    email: json['email'] ?? '',
    avatarUrl: json['avatarUrl'],
    role: json['role'] ?? 'USER',
    status: json['status'] ?? 'ACTIVE',
    verification: json['verificationStatus'] ?? 'UNVERIFIED',
    submittedAt: DateTime.tryParse(json['submittedAt'] ?? '')?.toLocal(),
    cccdNumber: json['cccdNumber'],
    frontImage: json['cccdFrontImage'],
    backImage: json['cccdBackImage'],
    selfieImage: json['selfieImage'],
  );
}

abstract class AdminRepository {
  Future<List<AdminUser>> getUsers();
  Future<void> review(String id, bool approve, {String? reason});
  Future<void> updateStatus(String id, String status);
}

class ApiAdminRepository implements AdminRepository {
  @override
  Future<List<AdminUser>> getUsers() async {
    final users = <String, AdminUser>{};
    // Danh sách tài khoản không có ảnh CCCD; ảnh chỉ lấy từ endpoint admin/pending.
    for (final endpoint in ['users', 'ekyc/pending']) {
      var page = 1;
      while (true) {
        final response = await ApiClient.get(
          '/admin/$endpoint?page=$page&limit=100',
        );
        final data = response['data'] as Map<String, dynamic>;
        final rows = data[endpoint == 'users' ? 'users' : 'profiles'] as List;
        for (final row in rows) {
          final previous = users[row['id']];
          final user = AdminUser.fromJson({
            ...row as Map<String, dynamic>,
            if (endpoint != 'users' && previous != null) ...{
              'role': previous.role,
              'avatarUrl': row['avatarUrl'] ?? previous.avatarUrl,
            },
          });
          if (endpoint != 'users') {
            final previous = users[user.id];
            if (previous != null) user.status = previous.status;
          }
          users[user.id] = user;
        }
        if (page >= ((data['pagination']['totalPages'] as num?) ?? 1)) break;
        page++;
      }
    }
    return users.values.toList();
  }

  @override
  Future<void> review(String id, bool approve, {String? reason}) async {
    await ApiClient.put(
      '/admin/ekyc/$id/${approve ? 'approve' : 'reject'}',
      body: approve ? null : {'reason': reason},
    );
  }

  @override
  Future<void> updateStatus(String id, String status) async {
    await ApiClient.put('/admin/users/$id/status', body: {'status': status});
  }
}

class MockAdminRepository implements AdminRepository {
  final users = [
    AdminUser(
      id: 'a1',
      name: 'Nguyễn Ngọc Anh',
      email: 'ngocanh@example.com',
      verification: 'PENDING',
      submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AdminUser(
      id: 'a2',
      name: 'Trần Minh Khang',
      email: 'minhkhang@example.com',
      verification: 'PENDING',
      submittedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AdminUser(
      id: 'a3',
      name: 'Lê Hoàng Long',
      email: 'hoanglong@example.com',
      verification: 'VERIFIED',
    ),
    AdminUser(
      id: 'a4',
      name: 'Phạm Thu Hà',
      email: 'thuha@example.com',
      status: 'BANNED',
    ),
    AdminUser(
      id: 'a5',
      name: 'Quản trị viên',
      email: 'admin@example.com',
      role: 'ADMIN',
      verification: 'VERIFIED',
    ),
  ];
  @override
  Future<List<AdminUser>> getUsers() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return users;
  }

  @override
  Future<void> review(String id, bool approve, {String? reason}) async {}
  @override
  Future<void> updateStatus(String id, String status) async {}
}

class AdminViewModel extends ChangeNotifier {
  AdminViewModel({AdminRepository? repository})
    : _repository =
          repository ??
          (ApiEndpoints.useMockData
              ? MockAdminRepository()
              : ApiAdminRepository());
  final AdminRepository _repository;
  List<AdminUser> users = [];
  bool isLoading = false;
  bool isUpdating = false;
  String? errorMessage;
  bool _disposed = false;
  String search = '';
  String status = '';
  List<AdminUser> get pending =>
      users.where((user) => user.verification == 'PENDING').toList();
  List<AdminUser> get filteredUsers => users.where((user) {
    final matches = '${user.name} ${user.email}'.toLowerCase().contains(
      search.toLowerCase(),
    );
    return matches && (status.isEmpty || status == user.status);
  }).toList();
  Future<void> load() async {
    if (_disposed || isLoading || isUpdating) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.getUsers();
      if (!_disposed) users = result;
    } catch (error) {
      errorMessage = error is ApiException
          ? error.message
          : 'Không tải được dữ liệu quản trị.';
    } finally {
      isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void filter({String? query, String? userStatus}) {
    if (query != null) search = query;
    if (userStatus != null) status = userStatus;
    notifyListeners();
  }

  Future<bool> _update(
    Future<void> Function() action,
    void Function() change,
  ) async {
    if (_disposed || isUpdating) return false;
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
          : 'Thao tác chưa thành công. Vui lòng thử lại.';
      return false;
    } finally {
      isUpdating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> review(AdminUser user, bool approve, {String? reason}) async {
    if (user.verification != 'PENDING') return false;
    return _update(
      () => _repository.review(user.id, approve, reason: reason),
      () {
        user.verification = approve ? 'VERIFIED' : 'REJECTED';
        user.reason = approve ? null : reason;
      },
    );
  }

  Future<bool> updateStatus(AdminUser user) async {
    if (user.role == 'ADMIN') return false;
    final status = user.status == 'BANNED' ? 'ACTIVE' : 'BANNED';
    return _update(
      () => _repository.updateStatus(user.id, status),
      () => user.status = status,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
