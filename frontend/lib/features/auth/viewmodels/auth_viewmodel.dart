import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/mock_auth_repository.dart';
// import '../repositories/api_auth_repository.dart';  // ← Bật khi API sẵn sàng

// ================================================================================
// VIEWMODEL: Authentication
// ================================================================================
// Quản lý STATE (trạng thái) cho các màn hình auth (Login, Register).
// View (Screen) lắng nghe ViewModel → khi state thay đổi, UI tự cập nhật.
//
// ViewModel KHÔNG biết giao diện trông như nào.
// ViewModel KHÔNG import bất kỳ Widget nào.
// ViewModel chỉ: nhận action → gọi repository → cập nhật state → notifyListeners()
//
// ⭐ CHUYỂN ĐỔI MOCK ↔ API:
//   Đổi dòng _repo = MockAuthRepository() → _repo = ApiAuthRepository()
// ================================================================================

class AuthViewModel extends ChangeNotifier {
  // === Repository (nguồn dữ liệu) ===
  // 🔄 ĐỔI Ở ĐÂY để chuyển Mock ↔ API
  final AuthRepository _repo = MockAuthRepository();
  // final AuthRepository _repo = ApiAuthRepository();  // ← Bật khi API sẵn sàng

  // === State ===
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // === Getters (View đọc state qua đây) ===
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  // === Actions (View gọi khi user tương tác) ===

  /// Đăng nhập
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // → UI hiện loading spinner

    try {
      final result = await _repo.login(email, password);
      _user = result.user;
      // TODO: Lưu token vào storage
      // await StorageHelper.saveToken(result.token);
      _isLoading = false;
      notifyListeners(); // → UI hiện thành công
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners(); // → UI hiện lỗi
      return false;
    }
  }

  /// Đăng ký
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repo.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất
  void logout() {
    _user = null;
    _errorMessage = null;
    // TODO: await StorageHelper.clearAll();
    notifyListeners();
  }

  /// Xóa thông báo lỗi
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
