import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/models/user_model.dart';

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
  static const String _sessionKey = 'auth_session';

  static Future<void> saveSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _sessionKey,
      jsonEncode({'token': token, 'user': user.toJson()}),
    )) {
      throw StateError('Không lưu được phiên đăng nhập');
    }
  }

  static Future<({String token, UserModel user})?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sessionKey);
    if (value == null) return null;
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      final token = data['token'] as String;
      final payload =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map<String, dynamic>;
      if ((payload['exp'] as num) * 1000 <=
          DateTime.now().millisecondsSinceEpoch) {
        await clearAll();
        return null;
      }
      return (
        token: token,
        user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    } catch (_) {
      await clearAll();
      return null;
    }
  }

  /// Update only the session that initiated a server refresh. A late response
  /// must never restore a logged-out session or overwrite another account.
  static Future<bool> updateSessionUser(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sessionKey);
    if (value == null) return false;
    final session = jsonDecode(value) as Map<String, dynamic>;
    if (session['token'] != token ||
        (session['user'] as Map<String, dynamic>)['id'] != user.id) {
      return false;
    }
    return prefs.setString(
      _sessionKey,
      jsonEncode({'token': token, 'user': user.toJson()}),
    );
  }

  // === Token ===
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString(_sessionKey);
    if (session != null) {
      return (jsonDecode(session) as Map<String, dynamic>)['token'] as String;
    }
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
    for (final key in [_sessionKey, _tokenKey, _userIdKey, _userEmailKey]) {
      await prefs.remove(key);
    }
  }

  // === Kiểm tra đã đăng nhập chưa ===
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
