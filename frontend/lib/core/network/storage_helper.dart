import 'package:shared_preferences/shared_preferences.dart';

// ================================================================================
// LƯU TRỮ DỮ LIỆU CỤC BỘ (Local Storage)
// ================================================================================
// Lưu token, thông tin user vào bộ nhớ điện thoại.
// Khi mở lại app sẽ đọc token → tự đăng nhập.
//
// Cách dùng:
//   await StorageHelper.saveToken('eyJhbG...');
//   final token = await StorageHelper.getToken();
//   await StorageHelper.clearAll(); // khi logout
// ================================================================================

class StorageHelper {
  static const String _tokenKey = 'jwt_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';

  // === Token ===
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // === User Info ===
  static Future<void> saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, id);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // === Clear All (dùng khi Logout) ===
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // === Kiểm tra đã đăng nhập chưa ===
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
