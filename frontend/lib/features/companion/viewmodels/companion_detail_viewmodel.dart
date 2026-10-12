import 'package:flutter/widgets.dart';
import '../models/companion_post_model.dart';
import '../repositories/companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

// ================================================================================
// VIEWMODEL: CompanionDetail
// ================================================================================
// Quản lý state cho màn hình Chi tiết bài đăng.
// Bao gồm logic gửi yêu cầu tham gia.
// ================================================================================

class CompanionDetailViewModel extends ChangeNotifier {
  CompanionDetailViewModel({CompanionRepository? repository})
    : _repo =
          repository ??
          (ApiEndpoints.useMockData
              ? MockCompanionRepository()
              : ApiCompanionRepository());

  final CompanionRepository _repo;

  CompanionPost? _post;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _disposed = false;
  String? requestStatus;
  bool get hasSentRequest => requestStatus != null;

  CompanionPost? get post => _post;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // ─── Load chi tiết bài đăng ───────────────────────────────────────────────

  Future<void> load(String postId) async {
    if (_disposed || _isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final post = await _repo.getPostDetail(postId);
      if (_disposed) return;
      _post = post;
      requestStatus = post.myRequestStatus;
    } catch (e) {
      if (_disposed) return;
      if (e is ApiException && e.statusCode == 404) {
        _post = null;
        requestStatus = null;
      }
      _errorMessage = e is ApiException
          ? e.message
          : 'Không thể tải bài đăng. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ─── Gửi yêu cầu tham gia ─────────────────────────────────────────────────

  Future<bool> sendJoinRequest({
    required String postId,
    String? introduction,
  }) async {
    if (_disposed || _isSubmitting || hasSentRequest) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repo.createJoinRequest(postId: postId, introduction: introduction);
      if (_disposed) return false;
      requestStatus = 'PENDING';
      try {
        final updated = await _repo.getPostDetail(postId);
        if (!_disposed) {
          _post = updated;
          requestStatus = updated.myRequestStatus;
        }
      } catch (_) {}
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> cancelRequest() async {
    if (_disposed ||
        _isSubmitting ||
        requestStatus != 'PENDING' ||
        _post == null) {
      return false;
    }
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_post!.myRequestId == null) {
        final latest = await _repo.getPostDetail(_post!.id);
        if (_disposed) return false;
        _post = latest;
      }
      if (_post!.myRequestId == null) {
        throw Exception('Yêu cầu không còn tồn tại. Hãy tải lại bài đăng.');
      }
      await _repo.deleteJoinRequest(_post!.myRequestId!);
      if (_disposed) return false;
      requestStatus = null;
      return true;
    } catch (e) {
      if (e is ApiException &&
          [400, 404, 409].contains(e.statusCode) &&
          !_disposed) {
        await load(_post!.id);
      }
      _errorMessage = e is ApiException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
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
