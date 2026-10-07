import 'dart:convert';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/storage_helper.dart';
import '../models/itinerary_model.dart';
import 'itinerary_repository.dart';

class ApiItineraryRepository implements ItineraryRepository {
  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    if (value is! Map) {
      throw const FormatException('Dữ liệu lịch trình không hợp lệ');
    }
    return Map<String, dynamic>.from(value);
  }

  dynamic _rawData(Map<String, dynamic> response) => response['data'];

  @override
  Future<ItineraryPlan> getItinerary(String tripId) async =>
      ItineraryPlan.fromJson(
        _data(
          await ApiClient.get(
            '${ApiEndpoints.itineraries}/trips/${Uri.encodeComponent(tripId)}',
          ),
        ),
      );

  @override
  Future<ItineraryDay> createDay(
    String tripId, {
    required int dayNumber,
    String? title,
  }) async => ItineraryDay.fromJson(
    _data(
      await ApiClient.post(
        '${ApiEndpoints.itineraries}/trips/${Uri.encodeComponent(tripId)}/days',
        body: {
          'dayNumber': dayNumber,
          if (title?.trim().isNotEmpty == true) 'title': title!.trim(),
        },
      ),
    ),
  );

  @override
  Future<ItineraryDay> updateDay(
    ItineraryDay day, {
    required String title,
  }) async => ItineraryDay.fromJson(
    _data(
      await ApiClient.patch(
        '${ApiEndpoints.itineraries}/days/${Uri.encodeComponent(day.id!)}',
        body: {'title': title.trim(), 'expectedVersion': day.version},
      ),
    ),
  );

  @override
  Future<ItineraryItem> addItem(
    String dayId,
    ItineraryItemDraft draft,
  ) async => ItineraryItem.fromJson(
    _data(
      await ApiClient.post(
        '${ApiEndpoints.itineraries}/days/${Uri.encodeComponent(dayId)}/items',
        body: draft.toCreateJson(),
      ),
    ),
  );

  @override
  Future<ItineraryItem> updateItem(
    ItineraryItem item,
    ItineraryItemDraft draft,
  ) async => ItineraryItem.fromJson(
    _data(
      await ApiClient.patch(
        '${ApiEndpoints.itineraries}/items/${Uri.encodeComponent(item.id)}',
        body: draft.toUpdateJson(item.version),
      ),
    ),
  );

  @override
  Future<void> deleteItem(ItineraryItem item) async {
    await _deleteWithBody(
      '${ApiEndpoints.itineraries}/items/${Uri.encodeComponent(item.id)}',
      {'expectedVersion': item.version},
    );
  }

  @override
  Future<ItineraryItem> setCompletion(
    ItineraryItem item, {
    required bool isCompleted,
  }) async => ItineraryItem.fromJson(
    _data(
      await ApiClient.patch(
        '${ApiEndpoints.itineraries}/items/${Uri.encodeComponent(item.id)}/completion',
        body: {'isCompleted': isCompleted, 'expectedVersion': item.version},
      ),
    ),
  );

  @override
  Future<ItineraryDay> reorderItems(
    ItineraryDay day,
    List<String> orderedItemIds,
  ) async => ItineraryDay.fromJson(
    _data(
      await ApiClient.patch(
        '${ApiEndpoints.itineraries}/days/${Uri.encodeComponent(day.id!)}/items/reorder',
        body: {
          'orderedItemIds': orderedItemIds,
          'expectedVersion': day.version,
        },
      ),
    ),
  );

  @override
  Future<List<SwapCandidate>> getSwapCandidates(
    String itemId, {
    double radiusKm = 3,
    int limit = 10,
  }) async {
    final query = Uri(
      queryParameters: {'radiusKm': '$radiusKm', 'limit': '$limit'},
    ).query;
    final value = _rawData(
      await ApiClient.get(
        '${ApiEndpoints.itineraries}/items/${Uri.encodeComponent(itemId)}/swap-candidates?$query',
      ),
    );
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => SwapCandidate.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }
    return const [];
  }

  @override
  Future<ItineraryItem> applySmartSwap(
    ItineraryItem item,
    SwapCandidate candidate,
  ) async => ItineraryItem.fromJson(
    _data(
      await ApiClient.post(
        '${ApiEndpoints.itineraries}/items/${Uri.encodeComponent(item.id)}/swap',
        body: {
          'newPlaceId': candidate.placeId,
          'candidateToken': candidate.candidateToken,
          'expectedVersion': item.version,
        },
      ),
    ),
  );

  @override
  Future<List<ItineraryPlaceOption>> searchPlaces({
    required String destination,
    String? keyword,
  }) async {
    final query = Uri(
      queryParameters: {
        'destination': destination,
        if (keyword?.trim().isNotEmpty == true) 'keyword': keyword!.trim(),
        'page': '1',
        'limit': '20',
      },
    ).query;
    final data = _data(await ApiClient.get('${ApiEndpoints.places}?$query'));
    final value = data['items'];
    return value is List
        ? value
              .whereType<Map>()
              .map(
                (row) => ItineraryPlaceOption.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList()
        : const [];
  }

  @override
  Future<PublicItineraryPage> getPublicPlans({
    String? destination,
    int? durationDays,
    String? keyword,
  }) async {
    final query = Uri(
      queryParameters: {
        if (destination?.trim().isNotEmpty == true)
          'destination': destination!.trim(),
        if (durationDays != null) 'durationDays': '$durationDays',
        if (keyword?.trim().isNotEmpty == true) 'keyword': keyword!.trim(),
        'page': '1',
        'limit': '50',
      },
    ).query;
    return PublicItineraryPage.fromJson(
      _data(await ApiClient.get('${ApiEndpoints.itineraries}/public?$query')),
    );
  }

  @override
  Future<PublicItineraryDetail> getPublicPlan(
    String sourceTripId,
  ) async => PublicItineraryDetail.fromJson(
    _data(
      await ApiClient.get(
        '${ApiEndpoints.itineraries}/public/${Uri.encodeComponent(sourceTripId)}',
      ),
    ),
  );

  @override
  Future<ItineraryPlan> clonePlan(
    String sourceTripId, {
    required DateTime startDate,
    String? name,
  }) async => ItineraryPlan.fromJson(
    _data(
      await ApiClient.post(
        '${ApiEndpoints.itineraries}/public/${Uri.encodeComponent(sourceTripId)}/clone',
        body: {
          'startDate': _apiDate(startDate),
          if (name?.trim().isNotEmpty == true) 'name': name!.trim(),
        },
      ),
    ),
  );

  Future<Map<String, dynamic>> _deleteWithBody(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await StorageHelper.getToken();
    final response = await ApiClient.client
        .delete(
          Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = ApiException(
        statusCode: response.statusCode,
        message: '${decoded['message'] ?? 'Đã xảy ra lỗi'}',
        code: decoded['code'] as String?,
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        ApiClient.onAuthError?.call(error);
      }
      throw error;
    }
    return decoded;
  }
}

String _apiDate(DateTime value) => value.toIso8601String().split('T').first;
