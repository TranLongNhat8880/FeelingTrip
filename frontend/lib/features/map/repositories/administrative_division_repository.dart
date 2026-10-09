import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/administrative_division_model.dart';

// ============================================================================
// REPOSITORY: Đơn vị hành chính Việt Nam
// API v1: Tỉnh/Thành -> Quận/Huyện -> Phường/Xã (trước sáp nhập 07/2025).
// API v2: Tỉnh/Thành -> Phường/Xã (sau sáp nhập 07/2025).
// ============================================================================

class AdministrativeDivisionRepository {
  AdministrativeDivisionRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const String _baseUrl = 'https://provinces.open-api.vn/api';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final bool _ownsClient;

  Future<List<AdministrativeDivision>> getProvinces(
    AdministrativeDivisionVersion version,
  ) async {
    final data = await _getJson(
      Uri.parse('$_baseUrl/${version.apiVersion}/p/'),
    );
    return AdministrativeDivision.listFromJson(data);
  }

  Future<List<AdministrativeDivision>> getDistricts(int provinceCode) async {
    final data = await _getJson(
      Uri.parse('$_baseUrl/v1/p/$provinceCode?depth=2'),
    );

    if (data is! Map) {
      throw const FormatException('Dữ liệu tỉnh/thành phố không hợp lệ');
    }

    return AdministrativeDivision.listFromJson(data['districts']);
  }

  Future<List<AdministrativeDivision>> getWardsByDistrict(
    int districtCode,
  ) async {
    final data = await _getJson(
      Uri.parse('$_baseUrl/v1/d/$districtCode?depth=2'),
    );

    if (data is! Map) {
      throw const FormatException('Dữ liệu quận/huyện không hợp lệ');
    }

    return AdministrativeDivision.listFromJson(data['wards']);
  }

  Future<List<AdministrativeDivision>> getWardsByProvince(
    int provinceCode,
  ) async {
    final data = await _getJson(
      Uri.parse('$_baseUrl/v2/p/$provinceCode?depth=2'),
    );

    if (data is! Map) {
      throw const FormatException('Dữ liệu tỉnh/thành phố không hợp lệ');
    }

    return AdministrativeDivision.listFromJson(data['wards']);
  }

  Future<Object?> _getJson(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw AdministrativeDivisionException(
          'API địa chỉ trả lỗi HTTP ${response.statusCode}.',
        );
      }

      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const AdministrativeDivisionException(
        'Tải dữ liệu địa chỉ quá lâu. Vui lòng thử lại.',
      );
    } on FormatException {
      rethrow;
    } on AdministrativeDivisionException {
      rethrow;
    } catch (_) {
      throw const AdministrativeDivisionException(
        'Không thể kết nối dịch vụ địa chỉ Việt Nam.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class AdministrativeDivisionException implements Exception {
  const AdministrativeDivisionException(this.message);

  final String message;

  @override
  String toString() => message;
}
