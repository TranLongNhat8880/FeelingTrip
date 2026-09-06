// ================================================================================
// CẤU HÌNH API ENDPOINTS
// ================================================================================
// Tất cả URL API gọi đến Backend đều nằm ở đây.
// KHÔNG viết URL trực tiếp trong service/repository.
//
// Cách dùng:
//   dio.post(ApiEndpoints.login, data: {...})
//   dio.get('${ApiEndpoints.trips}/$tripId')
// ================================================================================

class ApiEndpoints {
  ApiEndpoints._();

  // === Base URL ===
  // Đổi thành URL Railway khi deploy
  static const String baseUrl = 'http://10.0.2.2:5000/api/v1';
  // 10.0.2.2 = localhost khi chạy Android Emulator
  // Nếu chạy trên máy thật (qua WiFi), đổi thành IP máy tính: 'http://192.168.x.x:5000/api/v1'

  // === Auth ===
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String googleLogin = '/auth/google';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String forgotPassword = '/auth/forgot-pass';

  // === Users ===
  static const String users = '/users';
  static const String profile = '/users/profile';

  // === Trips ===
  static const String trips = '/trips';

  // === Itineraries ===
  static const String itineraries = '/itineraries';

  // === Expenses ===
  static const String expenses = '/expenses';

  // === Companions ===
  static const String companions = '/companions';

  // === Reviews ===
  static const String reviews = '/reviews';
}
