import 'package:flutter/widgets.dart';
import '../models/companion_post_model.dart';
import '../repositories/companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../../../core/constants/api_endpoints.dart';

// ================================================================================
// VIEWMODEL: CompanionFeed
// ================================================================================
// Quản lý state cho màn hình Feed (danh sách bài tìm bạn đồng hành).
// Hỗ trợ phân trang (load more), filter và sort.
// ================================================================================

class CompanionFeedViewModel extends ChangeNotifier {
  CompanionFeedViewModel({CompanionRepository? repository})
    : _repo =
          repository ??
          (ApiEndpoints.useMockData
              ? MockCompanionRepository()
              : ApiCompanionRepository());

  final CompanionRepository _repo;

  // State
  List<CompanionPost> _posts = [];
  PaginationInfo? _pagination;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _disposed = false;
  int _requestId = 0;

  // Filter state
  String _sortBy = 'newest';
  String _status = 'OPEN';
  String _destination = '';
  String _genderPreference = '';

  // Getters
  List<CompanionPost> get posts => _posts;
  PaginationInfo? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  bool get hasNextPage => _pagination?.hasNextPage ?? false;

  String get sortBy => _sortBy;
  String get status => _status;
  String get destination => _destination;
  String get genderPreference => _genderPreference;

  // ─── Load lần đầu / refresh ───────────────────────────────────────────────

  Future<void> load({bool refresh = false}) async {
    if (_disposed || (_isLoading && !refresh)) return;
    final requestId = ++_requestId;
    if (refresh) {
      _posts = [];
      _pagination = null;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repo.getFeed(
        page: 1,
        sortBy: _sortBy,
        status: _status,
        destination: _destination.isNotEmpty ? _destination : null,
        genderPreference: _genderPreference.isNotEmpty
            ? _genderPreference
            : null,
      );
      if (_disposed || requestId != _requestId) return;
      _posts = result.posts;
      _pagination = result.pagination;
    } catch (e) {
      if (_disposed || requestId != _requestId) return;
      _errorMessage = 'Không thể tải danh sách. Vui lòng thử lại.';
    } finally {
      if (!_disposed && requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ─── Load thêm (infinite scroll) ─────────────────────────────────────────

  Future<void> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !hasNextPage) return;
    final requestId = _requestId;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final nextPage = (_pagination?.currentPage ?? 1) + 1;
      final result = await _repo.getFeed(
        page: nextPage,
        sortBy: _sortBy,
        status: _status,
        destination: _destination.isNotEmpty ? _destination : null,
        genderPreference: _genderPreference.isNotEmpty
            ? _genderPreference
            : null,
      );
      if (_disposed || requestId != _requestId) return;
      _posts = [..._posts, ...result.posts];
      _pagination = result.pagination;
    } catch (_) {
      // Lỗi load more không hiện modal, chỉ stop spinner
    } finally {
      if (!_disposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // ─── Áp dụng filter ───────────────────────────────────────────────────────

  void applyFilter({
    String? sortBy,
    String? status,
    String? destination,
    String? genderPreference,
  }) {
    bool changed = false;
    if (sortBy != null && sortBy != _sortBy) {
      _sortBy = sortBy;
      changed = true;
    }
    if (status != null && status != _status) {
      _status = status;
      changed = true;
    }
    if (destination != null && destination != _destination) {
      _destination = destination;
      changed = true;
    }
    if (genderPreference != null && genderPreference != _genderPreference) {
      _genderPreference = genderPreference;
      changed = true;
    }
    if (changed) load(refresh: true);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
