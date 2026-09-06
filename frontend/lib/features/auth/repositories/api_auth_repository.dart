import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

// ================================================================================
// API REPOSITORY: Authentication (GỌI BACKEND THẬT)
// ================================================================================
// Gọi các API thật từ Backend Node.js/Express.
// Dùng ApiClient để gửi HTTP request và parse response.
//
// Khi nào dùng:
//   - Backend đã code xong API tương ứng
//   - Chuyển từ Mock sang thật: chỉ cần đổi 1 dòng trong ViewModel
// ================================================================================

class ApiAuthRepository implements AuthRepository {
  @override
  Future<({UserModel user, String token})> login(
    String email,
    String password,
  ) async {
    final response = await ApiClient.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
    );

    // response format từ Backend:
    // { "success": true, "message": "...", "data": { "user": {...}, "token": "..." } }
    final data = response['data'];

    return (
      user: UserModel.fromJson(data['user']),
      token: data['token'] as String,
    );
  }

  @override
  Future<({UserModel user, String token})> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await ApiClient.post(
      ApiEndpoints.register,
      body: {
        'email': email,
        'password': password,
        'fullName': fullName,
        'phone': phone,
      },
    );

    final data = response['data'];
    return (
      user: UserModel.fromJson(data['user']),
      token: data['token'] as String,
    );
  }

  @override
  Future<({UserModel user, String token})> googleLogin(String idToken) async {
    final response = await ApiClient.post(
      ApiEndpoints.googleLogin,
      body: {'idToken': idToken},
    );

    final data = response['data'];
    return (
      user: UserModel.fromJson(data['user']),
      token: data['token'] as String,
    );
  }
}
