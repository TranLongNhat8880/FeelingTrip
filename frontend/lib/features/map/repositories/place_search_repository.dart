import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/place_search_result.dart';

class PlaceSearchRepository {
  static String get tileUrlTemplate =>
      '${ApiEndpoints.baseUrl}${ApiEndpoints.placeGeocode}/tiles/{z}/{x}/{y}.png';

  Future<bool> isConfigured() async {
    try {
      final response = await ApiClient.get(
        '${ApiEndpoints.placeGeocode}/configuration',
      );
      final data = response['data'];
      if (data is! Map || data['configured'] is! bool) {
        throw const FormatException('Invalid map configuration');
      }
      return data['configured'] as bool;
    } catch (error) {
      throw _errorFor(error);
    }
  }

  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final text = query.trim();
    if (text.length < 3) return const [];
    return _request('search', {'text': text});
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
    final results = await _request('reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
    });
    if (results.isEmpty) return null;
    final address = results.first;
    return address.copyWith(latitude: latitude, longitude: longitude);
  }

  Future<List<PlaceSearchResult>> _request(
    String path,
    Map<String, String> parameters,
  ) async {
    try {
      final query = Uri(queryParameters: parameters).query;
      final response = await ApiClient.get(
        '${ApiEndpoints.placeGeocode}/$path?$query',
      );
      final data = response['data'];
      if (data is! Map || data['features'] is! List) {
        throw const FormatException('Invalid map response');
      }
      final results = <PlaceSearchResult>[];
      for (final feature in data['features'] as List) {
        if (feature is! Map) continue;
        final PlaceSearchResult result;
        try {
          result = PlaceSearchResult.fromGeoJsonFeature(
            Map<String, dynamic>.from(feature),
          );
        } on FormatException {
          continue;
        }
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
    } catch (error) {
      throw _errorFor(error);
    }
  }

  PlaceSearchException _errorFor(Object error) {
    if (error is ApiException) return PlaceSearchException(error.message);
    if (error is TimeoutException) {
      return const PlaceSearchException(
        'Tra cứu địa điểm quá lâu. Vui lòng thử lại.',
      );
    }
    if (error is http.ClientException) {
      return const PlaceSearchException(
        'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }
    return const PlaceSearchException('Không đọc được dữ liệu địa điểm.');
  }
}

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}
