import 'package:flutter/foundation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/itinerary_model.dart';
import '../repositories/api_itinerary_repository.dart';
import '../repositories/itinerary_repository.dart';
import '../repositories/mock_itinerary_repository.dart';

class ItineraryViewModel extends ChangeNotifier {
  ItineraryViewModel({ItineraryRepository? repository})
    : repository =
          repository ??
          (ApiEndpoints.useMockData
              ? MockItineraryRepository()
              : ApiItineraryRepository());

  final ItineraryRepository repository;
  ItineraryPlan? _plan;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  ItineraryPlan? get plan => _plan;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> load(String tripId) async {
    _setLoading(true);
    try {
      _plan = await repository.getItinerary(tripId);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(error, 'Không tải được lịch trình chuyến đi.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addItem(ItineraryDay day, ItineraryItemDraft draft) async =>
      _action(() async {
        var editableDay = day;
        if (!day.materialized || day.id == null) {
          editableDay = await repository.createDay(
            day.tripId,
            dayNumber: day.dayNumber,
            title: day.title,
          );
        }
        await repository.addItem(editableDay.id!, draft);
        await _reload();
      });

  Future<bool> updateItem(ItineraryItem item, ItineraryItemDraft draft) async =>
      _action(() async {
        if (item.isCompleted) {
          throw Exception('Không thể chỉnh sửa điểm dừng đã hoàn thành. Vui lòng bỏ đánh dấu hoàn thành trước.');
        }
        await repository.updateItem(item, draft);
        await _reload();
      });

  Future<bool> deleteItem(ItineraryItem item) async => _action(() async {
    if (item.isCompleted) {
      throw Exception('Không thể xóa điểm dừng đã hoàn thành. Vui lòng bỏ đánh dấu hoàn thành trước.');
    }
    await repository.deleteItem(item);
    await _reload();
  });

  Future<bool> toggleCompletion(ItineraryItem item) async => _action(() async {
    await repository.setCompletion(item, isCompleted: !item.isCompleted);
    await _reload();
  });

  Future<bool> updateDayTitle(ItineraryDay day, String title) async =>
      _action(() async {
        var editableDay = day;
        if (!day.materialized || day.id == null) {
          editableDay = await repository.createDay(
            day.tripId,
            dayNumber: day.dayNumber,
            title: title,
          );
        } else {
          await repository.updateDay(editableDay, title: title);
        }
        await _reload();
      });

  Future<bool> moveItem(ItineraryDay day, int oldIndex, int newIndex) async {
    if (day.id == null ||
        day.version == null ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= day.items.length ||
        newIndex < 0 ||
        newIndex >= day.items.length) {
      return false;
    }

    final originalItems = List<ItineraryItem>.of(day.items);
    final moved = day.items.removeAt(oldIndex);
    day.items.insert(newIndex, moved);

    for (int i = 0; i < originalItems.length; i++) {
      if (originalItems[i].isCompleted && day.items[i].id != originalItems[i].id) {
        day.items
          ..clear()
          ..addAll(originalItems);
        _errorMessage = 'Không thể thay đổi vị trí của điểm dừng đã hoàn thành.';
        notifyListeners();
        return false;
      }
    }

    // Gán ngay khung giờ của slot tương ứng để UI cập nhật tức thì
    for (int i = 0; i < day.items.length; i++) {
      day.items[i] = day.items[i].copyWith(
        startTime: originalItems[i].startTime,
        endTime: originalItems[i].endTime,
      );
    }

    final ids = day.items.map((item) => item.id).toList(growable: false);
    notifyListeners();

    final success = await _action(() async {
      await repository.reorderItems(day, ids);
      await _reload();
    });
    if (!success) {
      day.items
        ..clear()
        ..addAll(originalItems);
      notifyListeners();
    }
    return success;
  }

  Future<List<SwapCandidate>?> getSwapCandidates(ItineraryItem item) async {
    if (_isSubmitting) return null;
    if (item.isCompleted) {
      _errorMessage = 'Không thể đổi điểm dừng đã hoàn thành.';
      notifyListeners();
      return null;
    }
    _setSubmitting(true);
    try {
      final result = await repository.getSwapCandidates(item.id);
      _errorMessage = null;
      return result;
    } catch (error) {
      _errorMessage = _message(error, 'Không lấy được địa điểm thay thế.');
      return null;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<bool> applySmartSwap(
    ItineraryItem item,
    SwapCandidate candidate,
  ) async => _action(() async {
    if (item.isCompleted) {
      throw Exception('Không thể đổi điểm dừng đã hoàn thành.');
    }
    await repository.applySmartSwap(item, candidate);
    await _reload();
  });

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _reload() async {
    final tripId = _plan?.trip.id;
    if (tripId != null) _plan = await repository.getItinerary(tripId);
  }

  Future<bool> _action(Future<void> Function() operation) async {
    if (_isSubmitting) return false;
    _setSubmitting(true);
    try {
      await operation();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'Chưa thực hiện được thao tác.');
      notifyListeners();
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  String _message(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final raw = '$error';
    if (raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('TimeoutException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection refused')) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
    }
    if (error is FormatException || raw.contains('FormatException')) {
      return 'Dữ liệu phản hồi từ máy chủ không hợp lệ.';
    }
    final text = raw.replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
  }
}

class PublicItineraryViewModel extends ChangeNotifier {
  PublicItineraryViewModel({ItineraryRepository? repository})
    : repository =
          repository ??
          (ApiEndpoints.useMockData
              ? MockItineraryRepository()
              : ApiItineraryRepository());

  final ItineraryRepository repository;
  List<PublicItinerarySummary> plans = [];
  PublicItineraryDetail? selectedPlan;
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;

  Future<void> load({
    String? destination,
    int? durationDays,
    String? keyword,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final page = await repository.getPublicPlans(
        destination: destination,
        durationDays: durationDays,
        keyword: keyword,
      );
      plans = page.items;
      errorMessage = null;
    } catch (error) {
      errorMessage = _message(error, 'Không tải được kho lịch trình.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDetail(String sourceTripId) async {
    isLoading = true;
    notifyListeners();
    try {
      selectedPlan = await repository.getPublicPlan(sourceTripId);
      errorMessage = null;
    } catch (error) {
      errorMessage = _message(error, 'Không tải được chi tiết lịch trình.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ItineraryPlan?> clone({
    required String sourceTripId,
    required DateTime startDate,
    String? name,
  }) async {
    if (isSubmitting) return null;
    isSubmitting = true;
    notifyListeners();
    try {
      final result = await repository.clonePlan(
        sourceTripId,
        startDate: startDate,
        name: name,
      );
      errorMessage = null;
      return result;
    } catch (error) {
      errorMessage = _message(error, 'Không thể nhân bản lịch trình.');
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  String _message(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final text = '$error'.replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
  }
}
