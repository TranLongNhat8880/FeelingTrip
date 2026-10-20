import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/storage_helper.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/mock_auth_repository.dart';
import '../repositories/api_auth_repository.dart';
import '../../../core/constants/api_endpoints.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthRepository? repository})
    : _repo =
          repository ??
          (ApiEndpoints.useMockData
              ? MockAuthRepository()
              : ApiAuthRepository()) {
    if (!ApiEndpoints.useMockData) ApiClient.onAuthError = _sessionError;
  }
  void _sessionError(ApiException error) {
    if (_user == null) return;
    if (error.statusCode == 403 &&
        error.message == 'Tài khoản bị khóa hoặc chưa xác thực email') {
      _blockedEmail = _user!.email;
    } else if (error.statusCode != 401) {
      return;
    }
    _user = null;
    _sessionInvalidated = true;
    unawaited(StorageHelper.clearAll());
    notifyListeners();
  }

  final AuthRepository _repo;
  UserModel? _user;
  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;
  String? _blockedEmail;
  bool _sessionInvalidated = false;
  bool _disposed = false;
  bool get sessionInvalidated => _sessionInvalidated;
  String? get blockedEmail => _blockedEmail;
  String? _pendingVerificationEmail;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  /// Re-read verification from the API; never infer it from a client check.
  Future<bool> refreshUser() async {
    final original = _user;
    if (_disposed || original == null || _isLoading) return false;
    try {
      final token = await StorageHelper.getToken();
      if (token == null || _disposed || !identical(_user, original)) {
        return false;
      }
      final response = await ApiClient.get(ApiEndpoints.profile);
      final current = UserModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
      if (_disposed ||
          _isLoading ||
          !identical(_user, original) ||
          current.id != original.id) {
        return false;
      }
      final saved = await StorageHelper.updateSessionUser(token, current);
      if (!saved || _disposed || _isLoading || !identical(_user, original)) {
        return false;
      }
      _user = current;
      notifyListeners();
      return true;
    } catch (_) {
      // A refresh failure cannot undo a verification committed by the server.
      return false;
    }
  }

  Future<void> restoreSession() async {
    try {
      final session = await StorageHelper.getSession();
      if (session != null) {
        _user = session.user;
        if (!ApiEndpoints.useMockData) {
          final response = await ApiClient.get(ApiEndpoints.profile);
          if (_user != null) {
            _user = UserModel.fromJson(
              response['data'] as Map<String, dynamic>,
            );
            await StorageHelper.saveSession(session.token, _user!);
          }
        }
      }
    } catch (_) {
      _user = null;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    _pendingVerificationEmail = null;
    _blockedEmail = null;
    _sessionInvalidated = false;
    notifyListeners();
    try {
      final result = await _repo
          .login(email.trim(), password)
          .timeout(const Duration(seconds: 10));
      await StorageHelper.saveSession(result.token, result.user);
      _user = result.user;
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 403 &&
          (e.code == 'ACCOUNT_BANNED' || e.message == 'Tài khoản đã bị khóa')) {
        _blockedEmail = email.trim().toLowerCase();
      }
      if (e.statusCode == 403 && e.code == 'EMAIL_NOT_VERIFIED') {
        _pendingVerificationEmail = email.trim().toLowerCase();
      }
      _errorMessage = e.message;
      return false;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      return false;
    } catch (_) {
      _errorMessage = 'Không kết nối được backend. Kiểm tra server và thử lại.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<({bool success, String? message})> register({
    required String email,
    required String password,
    required String fullName,
    required bool termsAccepted,
    required String termsVersion,
    String? phone,
  }) async {
    if (_isLoading) return (success: false, message: null);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repo
          .register(
            email: email.trim(),
            password: password,
            fullName: fullName.trim(),
            termsAccepted: termsAccepted,
            termsVersion: termsVersion,
            phone: phone?.trim().isNotEmpty == true ? phone!.trim() : null,
          )
          .timeout(const Duration(seconds: 20));
      // Đăng ký chưa tạo phiên; chỉ xác thực OTP mới được đăng nhập.
      return (success: true, message: result.message);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return (success: false, message: e.message);
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      return (success: false, message: _errorMessage);
    } catch (_) {
      _errorMessage = 'Không thể đăng ký tài khoản. Vui lòng thử lại.';
      return (success: false, message: _errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repo
          .verifyOtp(email.trim().toLowerCase(), otp)
          .timeout(const Duration(seconds: 20));
      await StorageHelper.saveSession(result.token, result.user);
      _user = result.user;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      return false;
    } catch (_) {
      _errorMessage = 'Chưa xác thực được email. Vui lòng thử lại.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<({bool success, String? message})> resendOtp(String email) async {
    if (_isLoading) return (success: false, message: null);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final message = await _repo
          .resendOtp(email.trim().toLowerCase())
          .timeout(const Duration(seconds: 20));
      return (success: true, message: message);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Kiểm tra hộp thư trước khi gửi lại.';
    } catch (_) {
      _errorMessage = 'Chưa gửi được OTP. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return (success: false, message: _errorMessage);
  }

  Future<void> logout() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      await StorageHelper.clearAll();
      _user = null;
      _blockedEmail = null;
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Chưa đăng xuất được. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (ApiClient.onAuthError == _sessionError) ApiClient.onAuthError = null;
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    _pendingVerificationEmail = null;
    notifyListeners();
  }
}

class AuthScope extends InheritedNotifier<AuthViewModel> {
  const AuthScope({
    super.key,
    required AuthViewModel auth,
    required super.child,
  }) : super(notifier: auth);
  static AuthViewModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}
