import '../models/user_model.dart';
import 'auth_repository.dart';

// ================================================================================
// MOCK REPOSITORY: Authentication (DỮ LIỆU GIẢ)
// ================================================================================
// Trả về dữ liệu giả để phát triển UI khi Backend chưa sẵn sàng.
// Có delay giả lập để UI hiển thị loading giống thật.
//
// Khi nào dùng:
//   - Backend chưa code xong API
//   - Test UI offline (không cần mạng)
//   - Demo app cho khách hàng/giảng viên
// ================================================================================

class MockAuthRepository implements AuthRepository {
  @override
  Future<({UserModel user, String token})> login(
    String email,
    String password,
  ) async {
    // Giả lập thời gian chờ API (1 giây)
    await Future.delayed(const Duration(seconds: 1));

    // Giả lập check thông tin
    if (email == 'error@test.com') {
      throw Exception('Email hoặc mật khẩu không đúng');
    }

    // Trả về data giả
    return (
      user: UserModel(
        id: 1,
        email: email,
        fullName: 'Nguyễn Văn Test',
        phone: '0901234567',
        role: 'USER',
      ),
      token: 'mock_jwt_token_abc123',
    );
  }

  @override
  Future<({UserModel user, String token})> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    if (email == 'exists@test.com') {
      throw Exception('Email đã được đăng ký');
    }

    return (
      user: UserModel(
        id: 2,
        email: email,
        fullName: fullName,
        phone: phone,
        role: 'USER',
      ),
      token: 'mock_jwt_token_new_user_456',
    );
  }

  @override
  Future<({UserModel user, String token})> googleLogin(String idToken) async {
    await Future.delayed(const Duration(seconds: 1));

    return (
      user: UserModel(
        id: 3,
        email: 'google_user@gmail.com',
        fullName: 'Google User',
        avatarUrl: 'https://via.placeholder.com/150',
        role: 'USER',
      ),
      token: 'mock_jwt_token_google_789',
    );
  }
}
