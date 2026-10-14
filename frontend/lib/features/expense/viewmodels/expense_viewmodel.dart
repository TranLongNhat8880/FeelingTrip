import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../trip/models/trip_model.dart';
import '../../trip/repositories/api_trip_repository.dart';
import '../../trip/repositories/trip_repository.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

class ExpenseViewModel extends ChangeNotifier {
  ExpenseViewModel({
    required this.tripId,
    ExpenseRepository? repository,
    TripRepository? tripRepository,
  }) : repository = repository ?? ApiExpenseRepository(),
       tripRepository = tripRepository ?? ApiTripRepository();
  final String tripId;
  final ExpenseRepository repository;
  final TripRepository tripRepository;
  TripModel? trip;
  ExpenseSnapshot? data;
  bool loading = false, saving = false, _disposed = false;
  String? error, notice;
  Future<void>? _loadTask;
  List<Settlement> get open =>
      data?.settlements.where((s) => s.isOpen).toList() ?? [];
  List<Settlement> get paid =>
      data?.settlements.where((s) => s.status == 'PAID').toList() ?? [];
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  String _message(Object e) => e is ApiException
      ? e.message
      : e is FormatException
      ? 'Dữ liệu trả về chưa hợp lệ. Vui lòng tải lại.'
      : 'Không kết nối được hệ thống. Vui lòng thử lại.';
  Future<void> load() {
    return _loadTask ??= _reload().whenComplete(() => _loadTask = null);
  }

  Future<void> _reload() async {
    loading = true;
    error = null;
    _emit();
    try {
      final results = await Future.wait<Object>([
        tripRepository.getTripById(tripId),
        repository.load(tripId),
      ]);
      trip = results[0] as TripModel;
      data = results[1] as ExpenseSnapshot;
    } catch (e) {
      error = _message(e);
    } finally {
      loading = false;
      _emit();
    }
  }

  Future<bool> create(Map<String, dynamic> payload) async {
    if (saving) return false;
    saving = true;
    error = null;
    notice = null;
    _emit();
    bool created = false;
    try {
      await _loadTask;
      await repository.create({...payload, 'tripId': tripId});
      created = true;
      try {
        await repository.optimize(tripId);
      } catch (e) {
        notice = 'Khoản chi đã lưu. Chưa tính lại được công nợ: ${_message(e)}';
      }
      await _loadTask;
      await load();
    } catch (e) {
      error = _message(e);
    } finally {
      saving = false;
      _emit();
    }
    return created;
  }

  Future<void> optimize() async {
    if (saving) return;
    saving = true;
    error = null;
    notice = null;
    _emit();
    try {
      await _loadTask;
      await repository.optimize(tripId);
      await _loadTask;
      await load();
    } catch (e) {
      error = _message(e);
    } finally {
      saving = false;
      _emit();
    }
  }

  Future<bool> updateBudget(int amount) async {
    if (saving) return false;
    saving = true;
    error = null;
    _emit();
    try {
      await _loadTask;
      await repository.updateBudget(tripId, amount);
      await _loadTask;
      await load();
      return true;
    } catch (e) {
      error = _message(e);
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  Future<bool> linkExpense(String expenseId, String itemId) async {
    if (saving) return false;
    saving = true;
    error = null;
    _emit();
    try {
      await _loadTask;
      await repository.linkExpense(expenseId, itemId);
      await _loadTask;
      await load();
      return true;
    } catch (e) {
      error = _message(e);
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
