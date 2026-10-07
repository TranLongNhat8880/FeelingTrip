import 'package:feeling_trip/features/map/models/place_distance_model.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/place_form_data.dart';
import '../models/place_model.dart';
import 'place_repository.dart';

// ============================================================================
// API REPOSITORY: Places
// Gọi API thật của backend để lấy danh sách và chi tiết địa điểm.
// ============================================================================

class ApiPlaceRepository implements PlaceRepository {
  @override
  Future<PlacePage> searchPlaces({
    String? keyword,
    String? destination,
    String? category,
    int? priceLevel,
    String sortBy = 'newest',
    int page = 1,
    int limit = 20,
  }) async {
    final queryParameters = <String, String>{
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (destination != null && destination.trim().isNotEmpty)
        'destination': destination.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (priceLevel != null) 'priceLevel': priceLevel.toString(),
      'sortBy': sortBy,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final queryString = Uri(queryParameters: queryParameters).query;
    final endpoint = '${ApiEndpoints.places}?$queryString';

    final response = await ApiClient.get(endpoint);
    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('Dữ liệu danh sách địa điểm không hợp lệ');
    }

    return PlacePage.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<PlaceModel> getPlaceById(String placeId) async {
    final normalizedId = placeId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        placeId,
        'placeId',
        'Mã địa điểm không được để trống',
      );
    }

    final encodedId = Uri.encodeComponent(normalizedId);

    final response = await ApiClient.get('${ApiEndpoints.places}/$encodedId');

    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('Dữ liệu chi tiết địa điểm không hợp lệ');
    }

    return PlaceModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<PlaceDistanceResult> calculateDistance({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    String travelMode = 'driving',
  }) async {
    final queryParameters = <String, String>{
      'originLat': originLatitude.toString(),
      'originLng': originLongitude.toString(),
      'destLat': destinationLatitude.toString(),
      'destLng': destinationLongitude.toString(),
      'travelMode': travelMode,
    };

    final queryString = Uri(queryParameters: queryParameters).query;

    final response = await ApiClient.get(
      '${ApiEndpoints.places}/distance?$queryString',
    );

    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('Dữ liệu khoảng cách không hợp lệ');
    }

    return PlaceDistanceResult.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<PlacePage> getManagePlaces({
    String? keyword,
    String? destination,
    String? category,
    int? priceLevel,
    bool? isActive,
    String sortBy = 'newest',
    int page = 1,
    int limit = 20,
  }) async {
    final queryParameters = <String, String>{
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (destination != null && destination.trim().isNotEmpty)
        'destination': destination.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (priceLevel != null) 'priceLevel': priceLevel.toString(),
      if (isActive != null) 'isActive': isActive.toString(),
      'sortBy': sortBy,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final queryString = Uri(queryParameters: queryParameters).query;

    final response = await ApiClient.get(
      '${ApiEndpoints.places}/manage?$queryString',
    );

    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('Dữ liệu quản lý địa điểm không hợp lệ');
    }

    return PlacePage.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<PlaceModel> updatePlaceStatus({
    required String placeId,
    required bool isActive,
  }) async {
    final normalizedId = placeId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        placeId,
        'placeId',
        'Mã địa điểm không được để trống',
      );
    }

    final encodedId = Uri.encodeComponent(normalizedId);

    final response = await ApiClient.patch(
      '${ApiEndpoints.places}/$encodedId/status',
      body: {'isActive': isActive},
    );

    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('Dữ liệu trạng thái địa điểm không hợp lệ');
    }

    return PlaceModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<PlaceModel> createPlace({
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  }) async {
    final files = imageBytes == null
        ? const <MultipartFileData>[]
        : [
            MultipartFileData(
              fieldName: 'image',
              fileName: imageFileName ?? 'place-image.jpg',
              bytes: imageBytes,
            ),
          ];

    final response = await ApiClient.multipart(
      'POST',
      ApiEndpoints.places,
      fields: data.toMultipartFields(),
      files: files,
    );

    final responseData = response['data'];

    if (responseData is! Map) {
      throw const FormatException('Dữ liệu địa điểm mới không hợp lệ');
    }

    return PlaceModel.fromJson(Map<String, dynamic>.from(responseData));
  }

  @override
  Future<PlaceModel> updatePlace({
    required String placeId,
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  }) async {
    final normalizedId = placeId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        placeId,
        'placeId',
        'Mã địa điểm không được để trống',
      );
    }

    final encodedId = Uri.encodeComponent(normalizedId);

    final files = imageBytes == null
        ? const <MultipartFileData>[]
        : [
            MultipartFileData(
              fieldName: 'image',
              fileName: imageFileName ?? 'place-image.jpg',
              bytes: imageBytes,
            ),
          ];

    final response = await ApiClient.multipart(
      'PUT',
      '${ApiEndpoints.places}/$encodedId',
      fields: data.toMultipartFields(),
      files: files,
    );

    final responseData = response['data'];

    if (responseData is! Map) {
      throw const FormatException('Dữ liệu địa điểm cập nhật không hợp lệ');
    }

    return PlaceModel.fromJson(Map<String, dynamic>.from(responseData));
  }
}
