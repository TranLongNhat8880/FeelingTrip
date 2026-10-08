import 'package:flutter/widgets.dart';
import '../models/companion_post_model.dart';
import '../models/companion_request_model.dart';
import '../repositories/companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../../../core/constants/api_endpoints.dart';

// ================================================================================
// VIEWMODEL: CompanionRequests
// ================================================================================
// Quản lý state màn hình Danh sách yêu cầu nhận được.
// Leader có thể xét duyệt (ACCEPT/REJECT) từ đây.
// ================================================================================

class CompanionRequestsViewModel extends ChangeNotifier {
  CompanionRequestsViewModel({CompanionRepository? repository})
    : _repo =
          repository ??
          (ApiEndpoints.useMockData
              ? MockCompanionRepository()
              : ApiCompanionRepository());

  final CompanionRepository _repo;

  List<CompanionRequest> _requests = [];
  PaginationInfo? _pagination;
  bool _isLoading = false;
  bool _isReviewing = false; // đang xét duyệt 1 request
  String? _errorMessage;
  String _filterStatus =
      'PENDING'; // '' = all, 'PENDING', 'ACCEPTED', 'REJECTED'

  String search = '';
  String selectedPostId = '';
  bool _disposed = false;
  int _requestId = 0;
  List<CompanionRequest> get requests => _requests;
  List<CompanionRequest> get visibleRequests => _requests
      .where(
        (request) =>
            (_filterStatus.isEmpty || request.status == _filterStatus) &&
            (selectedPostId.isEmpty || request.postId == selectedPostId) &&
            request.requester.displayName.toLowerCase().contains(
              search.toLowerCase(),
            ),
      )
      .toList();
  void filterLocal({String? query, String? postId}) {
    if (query != null) search = query;
    if (postId != null) selectedPostId = postId;
    notifyListeners();
  }

  PaginationInfo? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get isReviewing => _isReviewing;
  String? get errorMessage => _errorMessage;
  String get filterStatus => _filterStatus;

  // ─── Load danh sách ───────────────────────────────────────────────────────

  Future<void> load({bool refresh = false}) async {
    if (_disposed || (_isLoading && !refresh)) return;
    final requestId = ++_requestId;
    if (refresh) _requests = [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final allRequests = <CompanionRequest>[];
      var page = 1;
      while (true) {
        final result = await _repo.getMyReceivedRequests(
          page: page,
          limit: 50,
          status: _filterStatus.isNotEmpty ? _filterStatus : null,
        );
        if (_disposed || requestId != _requestId) return;
        allRequests.addAll(result.requests);
        _pagination = result.pagination;
        if (!result.pagination.hasNextPage) break;
        page++;
      }
      _requests = allRequests;
    } catch (e) {
      if (_disposed || requestId != _requestId) return;
      _errorMessage = 'Không thể tải danh sách yêu cầu. Vui lòng thử lại.';
    } finally {
      if (!_disposed && requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ─── Xét duyệt yêu cầu ────────────────────────────────────────────────────

  Future<bool> reviewRequest(String requestId, String status) async {
    if (_disposed || _isReviewing) return false;
    _isReviewing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repo.reviewJoinRequest(requestId, status);
      // Cập nhật local state
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx] = CompanionRequest(
          id: _requests[idx].id,
          postId: _requests[idx].postId,
          tripName: _requests[idx].tripName,
          introduction: _requests[idx].introduction,
          status: status,
          createdAt: _requests[idx].createdAt,
          requester: _requests[idx].requester,
        );
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isReviewing = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ─── Lọc theo trạng thái ──────────────────────────────────────────────────

  void setFilter(String status) {
    if (_filterStatus == status) return;
    _filterStatus = status;
    load(refresh: true);
  }

  void clearMessages() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
