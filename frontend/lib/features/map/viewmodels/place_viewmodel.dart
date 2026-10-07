import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/place_distance_model.dart';
import '../models/place_model.dart';
import '../repositories/api_place_repository.dart';
import '../repositories/place_repository.dart';

// ============================================================================
// VIEWMODEL: Places
// Quản lý trạng thái danh sách, bộ lọc, phân trang và chi tiết địa điểm.
// ============================================================================

class PlaceViewModel extends ChangeNotifier {
  PlaceViewModel({PlaceRepository? repository})
    : _repository = repository ?? ApiPlaceRepository();

  final PlaceRepository _repository;

  List<PlaceModel> _places = [];
  PlaceModel? _selectedPlace;
  PlaceDistanceResult? _distanceResult;
  bool _isCalculatingDistance = false;
  String? _distanceErrorMessage;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  String? _keyword;
  String? _destination;
  String? _category;
  int? _priceLevel;
  String _sortBy = 'newest';

  int _currentPage = 1;
  int _totalPages = 0;
  int _totalItems = 0;

  List<PlaceModel> get places => List.unmodifiable(_places);
  PlaceModel? get selectedPlace => _selectedPlace;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  String? get keyword => _keyword;
  String? get destination => _destination;
  String? get category => _category;
  int? get priceLevel => _priceLevel;
  String get sortBy => _sortBy;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;

  bool get hasMore => _currentPage < _totalPages;
  bool get hasPlaces => _places.isNotEmpty;
  PlaceDistanceResult? get distanceResult => _distanceResult;
  bool get isCalculatingDistance => _isCalculatingDistance;
  String? get distanceErrorMessage => _distanceErrorMessage;

  /// Tải trang đầu tiên với bộ lọc hiện tại.
  Future<void> loadPlaces() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository
          .searchPlaces(
            keyword: _keyword,
            destination: _destination,
            category: _category,
            priceLevel: _priceLevel,
            sortBy: _sortBy,
            page: 1,
          )
          .timeout(const Duration(seconds: 20));

      _places = result.items;
      _currentPage = result.page;
      _totalPages = result.totalPages;
      _totalItems = result.total;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
    } catch (_) {
      _errorMessage = 'Không thể tải danh sách địa điểm.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Áp dụng bộ lọc mới và tải lại từ trang đầu.
  Future<void> search({
    String? keyword,
    String? destination,
    String? category,
    int? priceLevel,
    String sortBy = 'newest',
  }) async {
    _keyword = _normalizeText(keyword);
    _destination = _normalizeText(destination);
    _category = _normalizeText(category);
    _priceLevel = priceLevel;
    _sortBy = sortBy;

    await loadPlaces();
  }

  /// Tải trang tiếp theo và nối vào danh sách hiện tại.
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository
          .searchPlaces(
            keyword: _keyword,
            destination: _destination,
            category: _category,
            priceLevel: _priceLevel,
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

  /// Lấy chi tiết một địa điểm theo ID.
  Future<bool> loadPlaceDetail(String placeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedPlace = await _repository
          .getPlaceById(placeId)
          .timeout(const Duration(seconds: 20));

      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      return false;
    } catch (_) {
      _errorMessage = 'Không thể tải thông tin địa điểm.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Xóa toàn bộ bộ lọc và tải lại danh sách.
  Future<void> clearFilters() async {
    _keyword = null;
    _destination = null;
    _category = null;
    _priceLevel = null;
    _sortBy = 'newest';

    await loadPlaces();
  }

  void clearSelectedPlace() {
    _selectedPlace = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> calculateDistance({
    required PlaceModel origin,
    required PlaceModel destination,
    String travelMode = 'driving',
  }) async {
    if (_isCalculatingDistance) return false;

    if (!origin.hasCoordinates || !destination.hasCoordinates) {
      _distanceErrorMessage =
          'Cả hai địa điểm phải có tọa độ để tính khoảng cách.';
      notifyListeners();
      return false;
    }

    _isCalculatingDistance = true;
    _distanceResult = null;
    _distanceErrorMessage = null;
    notifyListeners();

    try {
      _distanceResult = await _repository
          .calculateDistance(
            originLatitude: origin.latitude!,
            originLongitude: origin.longitude!,
            destinationLatitude: destination.latitude!,
            destinationLongitude: destination.longitude!,
            travelMode: travelMode,
          )
          .timeout(const Duration(seconds: 20));

      return true;
    } on ApiException catch (error) {
      _distanceErrorMessage = error.message;
      return false;
    } on TimeoutException {
      _distanceErrorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      return false;
    } catch (_) {
      _distanceErrorMessage = 'Không thể tính khoảng cách giữa hai địa điểm.';
      return false;
    } finally {
      _isCalculatingDistance = false;
      notifyListeners();
    }
  }

  void clearDistanceResult() {
    _distanceResult = null;
    _distanceErrorMessage = null;
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
