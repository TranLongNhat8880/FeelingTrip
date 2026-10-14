import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/bank_account_model.dart';
import '../models/profile_form_data.dart';
import '../models/profile_model.dart';
import '../models/trust_score_model.dart';
import '../repositories/api_profile_repository.dart';
import '../repositories/profile_repository.dart';

// ============================================================================
// VIEWMODEL: Profile
// Quản lý hồ sơ, điểm tín nhiệm, eKYC và tài khoản Bank Hub.
// ============================================================================

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({ProfileRepository? repository})
    : _repository = repository ?? ApiProfileRepository();

  final ProfileRepository _repository;

  ProfileModel? _profile;
  TrustScoreModel? _trustScore;
  List<BankAccountModel> _bankAccounts = [];

  bool _isLoadingProfile = false;
  bool _isSavingProfile = false;
  bool _isSubmittingEkyc = false;
  bool _isLoadingBankAccounts = false;
  bool _isCreatingBankLink = false;

  String? _errorMessage;
  bool _disposed = false;

  ProfileModel? get profile => _profile;
  TrustScoreModel? get trustScore => _trustScore;

  List<BankAccountModel> get bankAccounts => List.unmodifiable(_bankAccounts);

  bool get isLoadingProfile => _isLoadingProfile;
  bool get isSavingProfile => _isSavingProfile;
  bool get isSubmittingEkyc => _isSubmittingEkyc;
  bool get isLoadingBankAccounts => _isLoadingBankAccounts;
  bool get isCreatingBankLink => _isCreatingBankLink;

  bool get hasBankAccounts => _bankAccounts.isNotEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> loadProfile() async {
    if (_disposed || _isLoadingProfile) return;

    _isLoadingProfile = true;
    _errorMessage = null;
    _notify();

    try {
      final loadedProfile = await _repository.getProfile().timeout(
        const Duration(seconds: 20),
      );

      if (_disposed) return;

      _profile = loadedProfile;
      _notify();

      try {
        _trustScore = await _repository
            .getTrustScore(loadedProfile.id)
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        // Điểm tín nhiệm là dữ liệu phụ, lỗi không làm mất hồ sơ chính.
        _trustScore = null;
      }
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể tải hồ sơ cá nhân.');
    } finally {
      _isLoadingProfile = false;
      _notify();
    }
  }

  Future<bool> updateProfile({
    required ProfileFormData data,
    List<int>? avatarBytes,
    String? avatarFileName,
  }) async {
    if (_disposed || _isSavingProfile) return false;

    _isSavingProfile = true;
    _errorMessage = null;
    _notify();

    try {
      final updatedProfile = await _repository
          .updateProfile(
            data: data,
            avatarBytes: avatarBytes,
            avatarFileName: avatarFileName,
          )
          .timeout(const Duration(seconds: 30));

      if (_disposed) return false;

      _profile = updatedProfile;

      try {
        _trustScore = await _repository
            .getTrustScore(updatedProfile.id)
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        // Không chặn kết quả cập nhật hồ sơ nếu điểm tín nhiệm tải lỗi.
      }

      return true;
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể cập nhật hồ sơ.');
      return false;
    } finally {
      _isSavingProfile = false;
      _notify();
    }
  }

  Future<bool> submitEkyc({
    required String cccdNumber,
    required List<int> frontImageBytes,
    required String frontImageFileName,
    required List<int> backImageBytes,
    required String backImageFileName,
    required List<int> selfieImageBytes,
    required String selfieImageFileName,
  }) async {
    if (_disposed || _isSubmittingEkyc) return false;

    _isSubmittingEkyc = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository
          .submitEkyc(
            cccdNumber: cccdNumber,
            frontImageBytes: frontImageBytes,
            frontImageFileName: frontImageFileName,
            backImageBytes: backImageBytes,
            backImageFileName: backImageFileName,
            selfieImageBytes: selfieImageBytes,
            selfieImageFileName: selfieImageFileName,
          )
          .timeout(const Duration(seconds: 45));

      if (_disposed) return false;

      _profile = await _repository.getProfile().timeout(
        const Duration(seconds: 20),
      );

      return true;
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể gửi hồ sơ xác minh.');
      return false;
    } finally {
      _isSubmittingEkyc = false;
      _notify();
    }
  }

  Future<void> loadBankAccounts() async {
    if (_disposed || _isLoadingBankAccounts) return;

    _isLoadingBankAccounts = true;
    _errorMessage = null;
    _notify();

    try {
      _bankAccounts = await _repository.getBankAccounts().timeout(
        const Duration(seconds: 20),
      );
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể tải tài khoản ngân hàng.');
    } finally {
      _isLoadingBankAccounts = false;
      _notify();
    }
  }

  Future<BankHostedLink?> createBankHostedLink({
    required BankLinkPurpose purpose,
    String? accountId,
  }) async {
    if (_disposed || _isCreatingBankLink) return null;

    _isCreatingBankLink = true;
    _errorMessage = null;
    _notify();

    try {
      return await _repository
          .createBankHostedLink(purpose: purpose, accountId: accountId)
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể tạo liên kết Bank Hub.');
      return null;
    } finally {
      _isCreatingBankLink = false;
      _notify();
    }
  }

  Future<void> refreshAfterBankReturn() async {
    await loadBankAccounts();

    if (_disposed) return;

    try {
      _profile = await _repository.getProfile().timeout(
        const Duration(seconds: 20),
      );
    } catch (error) {
      _errorMessage = _messageFor(
        error,
        'Chưa cập nhật được trạng thái liên kết ngân hàng.',
      );
    } finally {
      _notify();
    }
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  String _messageFor(Object error, String fallback) {
    if (error is ApiException) {
      return error.message;
    }

    if (error is TimeoutException) {
      return 'Kết nối quá lâu. Vui lòng thử lại.';
    }

    if (error is FormatException) {
      return error.message;
    }

    return fallback;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
