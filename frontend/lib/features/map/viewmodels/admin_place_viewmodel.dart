import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/place_form_data.dart';
import '../models/place_model.dart';
import '../repositories/api_place_repository.dart';
import '../repositories/place_repository.dart';

// ============================================================================
// VIEWMODEL: Admin quản lý kho địa điểm
// ============================================================================

class AdminPlaceViewModel extends ChangeNotifier {
  AdminPlaceViewModel({PlaceRepository? repository})
    : _repository = repository ?? ApiPlaceRepository();

  final PlaceRepository _repository;

  List<PlaceModel> _places = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSaving = false;
  String? _updatingPlaceId;
  String? _errorMessage;

  String? _keyword;
  String? _category;
  bool? _isActiveFilter;
  String _sortBy = 'newest';

  int _currentPage = 1;
  int _totalPages = 0;
  int _totalItems = 0;
  int _loadVersion = 0;

  List<PlaceModel> get places => List.unmodifiable(_places);

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSaving => _isSaving;
  String? get updatingPlaceId => _updatingPlaceId;
  String? get errorMessage => _errorMessage;

  String? get keyword => _keyword;
  String? get category => _category;
  bool? get isActiveFilter => _isActiveFilter;
  String get sortBy => _sortBy;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;

  bool get hasPlaces => _places.isNotEmpty;
  bool get hasMore => _currentPage < _totalPages;

  bool isUpdating(String placeId) {
    return _updatingPlaceId == placeId;
  }

  /// Tải lại trang đầu tiên theo bộ lọc hiện tại.
  Future<void> loadPlaces() async {
    final requestVersion = ++_loadVersion;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository
          .getManagePlaces(
            keyword: _keyword,
            category: _category,
            isActive: _isActiveFilter,
            sortBy: _sortBy,
            page: 1,
          )
          .timeout(const Duration(seconds: 20));

      if (requestVersion != _loadVersion) return;

      _places = result.items;
      _currentPage = result.page;
      _totalPages = result.totalPages;
      _totalItems = result.total;
    } on ApiException catch (error) {
      if (requestVersion == _loadVersion) {
        _errorMessage = error.message;
      }
    } on TimeoutException {
      if (requestVersion == _loadVersion) {
        _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      }
    } catch (_) {
      if (requestVersion == _loadVersion) {
        _errorMessage = 'Không thể tải kho địa điểm.';
      }
    } finally {
      if (requestVersion == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Áp dụng bộ lọc quản lý và tải lại trang đầu.
  Future<void> applyFilters({
    String? keyword,
    String? category,
    bool? isActive,
    String sortBy = 'newest',
  }) async {
    _keyword = _normalizeText(keyword);
    _category = _normalizeText(category);
    _isActiveFilter = isActive;
    _sortBy = sortBy;

    await loadPlaces();
  }

  /// Xóa toàn bộ bộ lọc.
  Future<void> clearFilters() async {
    _keyword = null;
    _category = null;
    _isActiveFilter = null;
    _sortBy = 'newest';

    await loadPlaces();
  }

  /// Tải trang tiếp theo.
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) {
      return;
    }

    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository
          .getManagePlaces(
            keyword: _keyword,
            category: _category,
            isActive: _isActiveFilter,
            sortBy: _sortBy,
            page: _currentPage + 1,
          )
          .timeout(const Duration(seconds: 20));

      _places = [..._places, ...result.items];
      _currentPage = result.page;
      _totalPages = result.totalPages;
      _totalItems = result.total;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
    } catch (_) {
      _errorMessage = 'Không thể tải thêm địa điểm.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Ẩn địa điểm đang hoạt động hoặc khôi phục địa điểm đã ẩn.
  Future<bool> togglePlaceStatus(PlaceModel place) async {
    if (_updatingPlaceId != null) return false;

    final nextStatus = !place.isActive;

    _updatingPlaceId = place.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedPlace = await _repository
          .updatePlaceStatus(placeId: place.id, isActive: nextStatus)
          .timeout(const Duration(seconds: 20));

      final noLongerMatchesFilter =
          _isActiveFilter != null && updatedPlace.isActive != _isActiveFilter;

      if (noLongerMatchesFilter) {
        _places = _places
            .where((item) => item.id != place.id)
            .toList(growable: false);

        if (_totalItems > 0) {
          _totalItems -= 1;
        }
      } else {
        _places = _places
            .map((item) => item.id == updatedPlace.id ? updatedPlace : item)
            .toList(growable: false);
      }

      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      return false;
    } catch (_) {
      _errorMessage = 'Không thể cập nhật trạng thái địa điểm.';
      return false;
    } finally {
      _updatingPlaceId = null;
      notifyListeners();
    }
  }

  /// Thêm một địa điểm mới vào kho.
  Future<PlaceModel?> createPlace({
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  }) async {
    if (_isSaving) return null;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _repository
          .createPlace(
            data: data,
            imageBytes: imageBytes,
            imageFileName: imageFileName,
          )
          .timeout(const Duration(seconds: 30));
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } on TimeoutException {
      _errorMessage = 'Tải ảnh hoặc lưu địa điểm quá lâu. Vui lòng thử lại.';
      return null;
    } catch (_) {
      _errorMessage = 'Không thể thêm địa điểm.';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Cập nhật thông tin của một địa điểm.
  Future<PlaceModel?> updatePlace({
    required String placeId,
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  }) async {
    if (_isSaving) return null;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _repository
          .updatePlace(
            placeId: placeId,
            data: data,
            imageBytes: imageBytes,
            imageFileName: imageFileName,
          )
          .timeout(const Duration(seconds: 30));
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } on TimeoutException {
      _errorMessage =
          'Tải ảnh hoặc cập nhật địa điểm quá lâu. Vui lòng thử lại.';
      return null;
    } catch (_) {
      _errorMessage = 'Không thể cập nhật địa điểm.';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String? _normalizeText(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
