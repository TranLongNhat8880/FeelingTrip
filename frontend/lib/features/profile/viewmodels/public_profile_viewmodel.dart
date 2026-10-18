import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/trust_score_model.dart';
import '../repositories/api_profile_repository.dart';
import '../repositories/profile_repository.dart';

/// Read-only state, separate from the signed-in user's editable profile.
class PublicProfileViewModel extends ChangeNotifier {
  PublicProfileViewModel({ProfileRepository? repository})
    : _repository = repository ?? ApiProfileRepository();

  final ProfileRepository _repository;
  TrustScoreModel? _profile;
  String? _errorMessage;
  bool _loading = false;
  bool _notFound = false;
  bool _disposed = false;
  int _request = 0;

  TrustScoreModel? get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loading;
  bool get notFound => _notFound;

  Future<void> load(String userId) async {
    if (_disposed) return;
    final request = ++_request;
    final id = userId.trim();
    _profile = null;
    _errorMessage = null;
    _notFound = false;
    _loading = id.isNotEmpty;
    if (id.isEmpty) _errorMessage = 'Thiếu mã người dùng (userId).';
    notifyListeners();
    if (id.isEmpty) return;
    try {
      final profile = await _repository
          .getTrustScore(id)
          .timeout(const Duration(seconds: 20));
      if (_disposed || request != _request) return;
      if (profile.id.toLowerCase() != id.toLowerCase() ||
          profile.reviewCount < 0 ||
          !profile.trustScore.isFinite ||
          profile.trustScore < 0 ||
          profile.trustScore > 5) {
        throw const FormatException('Dữ liệu hồ sơ người dùng không hợp lệ.');
      }
      _profile = profile;
    } catch (error) {
      if (_disposed || request != _request) return;
      if (error is ApiException && error.statusCode == 404) {
        _notFound = true;
        _errorMessage =
            'Người dùng không tồn tại hoặc tài khoản không còn hoạt động.';
      } else if (error is TimeoutException) {
        _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      } else if (error is ApiException && error.statusCode < 500) {
        _errorMessage = error.message;
      } else {
        _errorMessage = 'Không thể tải hồ sơ người dùng. Vui lòng thử lại.';
      }
    } finally {
      if (!_disposed && request == _request) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
