import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import 'storage_helper.dart';

// ================================================================================
// API CLIENT - GỌI BACKEND
// ================================================================================
// File này wrap toàn bộ HTTP requests (GET, POST, PUT, DELETE).
// Tự động gắn JWT token vào header nếu đã đăng nhập.
//
// Cách dùng trong repository:
//   final response = await ApiClient.post(ApiEndpoints.login, body: {...});
//   final data = response['data'];
// ================================================================================

class ApiClient {
  /// Headers mặc định, tự gắn token nếu có
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageHelper.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET request
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await http.get(url, headers: headers);
    return _handleResponse(response);
  }

  /// POST request
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await http.put(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await http.delete(url, headers: headers);
    return _handleResponse(response);
  }

  /// Xử lý response chung
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: body['message'] ?? 'Đã xảy ra lỗi',
      );
    }
  }
}

// === Custom Exception cho API ===
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
