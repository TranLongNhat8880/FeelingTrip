import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/storage_helper.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/api_auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthRepository? repository})
    : _repo = repository ?? ApiAuthRepository();
  final AuthRepository _repo;
  UserModel? _user;
  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;
  String? _pendingVerificationEmail;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  Future<void> restoreSession() async {
    try {
      _user = (await StorageHelper.getSession())?.user;
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
    notifyListeners();
    try {
      final result = await _repo
          .login(email.trim(), password)
          .timeout(const Duration(seconds: 20));
      await StorageHelper.saveSession(result.token, result.user);
      _user = result.user;
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 403 && e.code == 'EMAIL_NOT_VERIFIED') {
        _pendingVerificationEmail = email.trim().toLowerCase();
      }
      _errorMessage = e.message;
      return false;
    } on TimeoutException {
      _errorMessage = 'Kết nối quá lâu. Vui lòng thử lại.';
      return false;
    } catch (_) {
      _errorMessage = 'Không thể đăng nhập. Kiểm tra kết nối và thử lại nhé.';
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
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Chưa đăng xuất được. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
