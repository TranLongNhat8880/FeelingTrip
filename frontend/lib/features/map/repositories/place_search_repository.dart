import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/place_search_result.dart';

class PlaceSearchRepository {
  static String get _apiKey => dotenv.env['GEOAPIFY_API_KEY']?.trim() ?? '';

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final text = query.trim();

    if (text.length < 3) {
      return const [];
    }

    final results = await _request('/v1/geocode/autocomplete', {
      'text': text,
      'filter': 'countrycode:vn',
      'lang': 'vi',
      'limit': '5',
    });

    return results;
  }

  Future<PlaceSearchResult?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const PlaceSearchException('Tọa độ không hợp lệ.');
    }

    final results = await _request('/v1/geocode/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'lang': 'vi',
      'limit': '1',
    });

    if (results.isEmpty) {
      return null;
    }

    final address = results.first;

    // API trả địa chỉ gần nhất, nhưng vị trí lưu vẫn phải là
    // đúng điểm admin vừa chọn trên bản đồ.
    return PlaceSearchResult(
      id: address.id,
      name: address.name,
      formattedAddress: address.formattedAddress,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<PlaceSearchResult>> _request(
    String path,
    Map<String, String> parameters,
  ) async {
    if (!isConfigured) {
      throw const PlaceSearchException(
        'Chưa cấu hình GEOAPIFY_API_KEY trong frontend/.env.',
      );
    }

    final uri = Uri.https('api.geoapify.com', path, {
      ...parameters,
      'format': 'geojson',
      'apiKey': _apiKey.trim(),
    });

    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const PlaceSearchException(
          'API key bản đồ không hợp lệ hoặc chưa được cấp quyền.',
        );
      }

      if (response.statusCode == 429) {
        throw const PlaceSearchException(
          'Dịch vụ tìm kiếm đang giới hạn lượt gọi. Vui lòng thử lại sau.',
        );
      }

      if (response.statusCode != 200) {
        throw PlaceSearchException(
          'Không thể tra cứu địa điểm (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map || decoded['features'] is! List) {
        throw const PlaceSearchException(
          'Dịch vụ bản đồ trả dữ liệu không hợp lệ.',
        );
      }

      final features = decoded['features'] as List;
      final results = <PlaceSearchResult>[];

      for (final feature in features) {
        if (feature is! Map) continue;

        final result = PlaceSearchResult.fromGeoJsonFeature(
          Map<String, dynamic>.from(feature),
        );

        if (result.latitude.isFinite &&
            result.longitude.isFinite &&
            result.latitude >= -90 &&
            result.latitude <= 90 &&
            result.longitude >= -180 &&
            result.longitude <= 180) {
          results.add(result);
        }
      }

      return results;
    } on TimeoutException {
      throw const PlaceSearchException(
        'Tra cứu địa điểm quá lâu. Vui lòng thử lại.',
      );
    } on http.ClientException {
      throw const PlaceSearchException(
        'Không thể kết nối dịch vụ bản đồ. Kiểm tra kết nối mạng.',
      );
    } on FormatException {
      throw const PlaceSearchException('Không đọc được dữ liệu địa điểm.');
    }
  }
}

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
