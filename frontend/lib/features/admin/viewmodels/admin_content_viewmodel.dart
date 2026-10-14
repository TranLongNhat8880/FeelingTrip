import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/admin_content_model.dart';
import '../repositories/admin_content_repository.dart';

class AdminContentViewModel extends ChangeNotifier {
  final repository = AdminContentRepository();
  List<AdminReport> reports = [];
  List<LibraryPlan> plans = [];
  bool loading = false, updating = false;
  String? error;
  bool _disposed = false;
  int _loadId = 0;
  Future<void> loadReports(String status, String search) async {
    if (_disposed || updating) return;
    final id = ++_loadId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await repository.reports(status, search);
      if (!_disposed && id == _loadId) reports = rows;
    } catch (e) {
      if (id == _loadId) error = _message(e);
    } finally {
      if (!_disposed && id == _loadId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadPlans({
    bool admin = false,
    String source = 'SYSTEM',
    String search = '',
    String sort = 'newest',
    String status = '',
  }) async {
    if (_disposed || updating) return;
    final id = ++_loadId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await repository.plans(
        admin: admin,
        source: source,
        search: search,
        sort: sort,
        status: status,
      );
      if (!_disposed && id == _loadId) plans = rows;
    } catch (e) {
      if (id == _loadId) error = _message(e);
    } finally {
      if (!_disposed && id == _loadId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> update(Future<void> Function() action) async {
    if (updating || _disposed) return false;
    updating = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return !_disposed;
    } catch (e) {
      error = _message(e);
      return false;
    } finally {
      updating = false;
      if (!_disposed) notifyListeners();
    }
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : e is FormatException
      ? 'Dữ liệu không hợp lệ'
      : e.toString().replaceFirst('Exception: ', '');
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
