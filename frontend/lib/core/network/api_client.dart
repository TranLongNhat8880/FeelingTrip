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

class MultipartFileData {
  const MultipartFileData({
    required this.fieldName,
    required this.fileName,
    required this.bytes,
  });

  final String fieldName;
  final String fileName;
  final List<int> bytes;
}

class ApiClient {
  static http.Client client = http.Client();
  static void Function(ApiException)? onAuthError;

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

    final response = await client
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// POST request
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await client
        .post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// PATCH request
  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await http.patch(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    return _handleResponse(response);
  }

  /// Gửi multipart/form-data kèm một hoặc nhiều file.
  static Future<Map<String, dynamic>> multipart(
    String method,
    String endpoint, {
    Map<String, String> fields = const {},
    List<MultipartFileData> files = const [],
  }) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');

    final headers = await _getHeaders();

    // MultipartRequest tự tạo Content-Type kèm boundary.
    headers.remove('Content-Type');

    final request = http.MultipartRequest(method.toUpperCase(), url);

    request.headers.addAll(headers);
    request.fields.addAll(fields);

    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          file.fieldName,
          file.bytes,
          filename: file.fileName,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
  }

  /// PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await client
        .put(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final url = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    final headers = await _getHeaders();

    final response = await client
        .delete(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// Xử lý response chung
  static Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = response.body.isEmpty
          ? {}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Backend trả dữ liệu không hợp lệ. Kiểm tra địa chỉ API.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      final error = ApiException(
        statusCode: response.statusCode,
        message: body['message'] ?? 'Đã xảy ra lỗi',
        code: body['code'] as String?,
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        onAuthError?.call(error);
      }
      throw error;
    }
  }
}

// === Custom Exception cho API ===
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException({required this.statusCode, required this.message, this.code});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
