import '../models/user_model.dart';

// ================================================================================
// REPOSITORY ABSTRACT: Authentication
// ================================================================================
// "Hợp đồng" cho mọi nguồn dữ liệu Auth (API thật hoặc Mock giả).
//
// ViewModel chỉ biết class này, KHÔNG biết đang dùng API hay Mock.
// → Chuyển đổi nguồn data chỉ cần đổi 1 dòng, không sửa ViewModel.
//
// Cách dùng:
//   AuthRepository repo = MockAuthRepository();  // ← dev mode
//   AuthRepository repo = ApiAuthRepository();    // ← production mode
// ================================================================================

abstract class AuthRepository {
  /// Đăng nhập bằng email + password, trả về {user, token}
  Future<({UserModel user, String token})> login(String email, String password);

  /// Đăng ký tài khoản mới
  Future<({UserModel user, String token, String? message})> register({
    required String email,
    required String password,
    required String fullName,
    required bool termsAccepted,
    required String termsVersion,
    String? phone,
  });

  Future<({UserModel user, String token})> verifyOtp(String email, String otp);
  Future<String> resendOtp(String email);

  /// Đăng nhập bằng Google (gửi idToken từ Google SDK)
  Future<({UserModel user, String token})> googleLogin(String idToken);
}
