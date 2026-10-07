import 'dart:convert';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/storage_helper.dart';
import '../models/trip_model.dart';
import 'trip_repository.dart';

class ApiTripRepository implements TripRepository {
  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final value = response['data'];
    if (value is! Map) {
      throw const FormatException('Dữ liệu chuyến đi không hợp lệ');
    }
    return Map<String, dynamic>.from(value);
  }

  List<TripInvitation> _invitations(Map<String, dynamic> response) =>
      ((_data(response)['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => TripInvitation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

  @override
  Future<TripPage> getMyTrips({
    String? status,
    bool includeHistory = true,
  }) async {
    final query = Uri(
      queryParameters: {
        'status': ?status,
        'includeHistory': '$includeHistory',
        'page': '1',
        'limit': '50',
      },
    ).query;
    return TripPage.fromJson(
      _data(await ApiClient.get('${ApiEndpoints.trips}/my-trips?$query')),
    );
  }

  @override
  Future<TripModel> getTripById(String tripId) async => TripModel.fromJson(
    _data(await ApiClient.get('${ApiEndpoints.trips}/$tripId')),
  );

  @override
  Future<TripModel> createTrip(TripFormData data) async {
    final response = data.coverImageBytes == null
        ? await ApiClient.post(ApiEndpoints.trips, body: data.toJson())
        : await ApiClient.multipart(
            'POST',
            ApiEndpoints.trips,
            fields: data.toMultipartFields(),
            files: [
              MultipartFileData(
                fieldName: 'coverImage',
                fileName: data.coverImageFileName ?? 'trip-cover.jpg',
                bytes: data.coverImageBytes!,
              ),
            ],
          );
    return TripModel.fromJson(_data(response));
  }

  @override
  Future<TripModel> updateTrip(TripModel trip, TripFormData data) async {
    final expectedUpdatedAt = trip.updatedAt?.toUtc().toIso8601String();
    final response = data.coverImageBytes == null
        ? await ApiClient.patch(
            '${ApiEndpoints.trips}/${trip.id}',
            body: {...data.toJson(), 'expectedUpdatedAt': expectedUpdatedAt},
          )
        : await ApiClient.multipart(
            'PATCH',
            '${ApiEndpoints.trips}/${trip.id}',
            fields: data.toMultipartFields(
              expectedUpdatedAt: expectedUpdatedAt,
            ),
            files: [
              MultipartFileData(
                fieldName: 'coverImage',
                fileName: data.coverImageFileName ?? 'trip-cover.jpg',
                bytes: data.coverImageBytes!,
              ),
            ],
          );
    return TripModel.fromJson(_data(response));
  }

  @override
  Future<TripModel> transitionStatus(TripModel trip, String status) async =>
      TripModel.fromJson(
        _data(
          await ApiClient.patch(
            '${ApiEndpoints.trips}/${trip.id}/status',
            body: {
              'status': status,
              'expectedUpdatedAt': trip.updatedAt?.toUtc().toIso8601String(),
            },
          ),
        ),
      );

  @override
  Future<TripModel> cancelTrip(TripModel trip, {String? reason}) async {
    final normalizedReason = reason?.trim();
    final body = <String, dynamic>{
      if (trip.updatedAt != null)
        'expectedUpdatedAt': trip.updatedAt!.toUtc().toIso8601String(),
      if (normalizedReason?.isNotEmpty == true) 'reason': normalizedReason,
    };
    return TripModel.fromJson(
      _data(
        await _deleteWithBody(
          '${ApiEndpoints.trips}/${Uri.encodeComponent(trip.id)}',
          body,
        ),
      ),
    );
  }

  @override
  Future<TripModel> joinByCode(String inviteCode) async {
    final data = _data(
      await ApiClient.post(
        '${ApiEndpoints.trips}/join-by-code',
        body: {'inviteCode': inviteCode.trim().toUpperCase()},
      ),
    );
    return TripModel.fromJson(Map<String, dynamic>.from(data['trip'] as Map));
  }

  @override
  Future<void> leaveTrip(String tripId) async {
    await ApiClient.post('${ApiEndpoints.trips}/$tripId/leave');
  }

  @override
  Future<void> kickMember(String tripId, String userId) async {
    await ApiClient.delete('${ApiEndpoints.trips}/$tripId/members/$userId');
  }

  @override
  Future<TripModel> transferLeader(
    TripModel trip,
    String newLeaderUserId,
  ) async => TripModel.fromJson(
    _data(
      await ApiClient.post(
        '${ApiEndpoints.trips}/${trip.id}/leader-transfer',
        body: {
          'newLeaderUserId': newLeaderUserId,
          'expectedUpdatedAt': trip.updatedAt?.toUtc().toIso8601String(),
        },
      ),
    ),
  );

  @override
  Future<String> generateInviteCode(String tripId) async =>
      '${_data(await ApiClient.post('${ApiEndpoints.trips}/$tripId/invite-code'))['inviteCode']}';

  @override
  Future<void> revokeInviteCode(String tripId) async {
    await ApiClient.delete('${ApiEndpoints.trips}/$tripId/invite-code');
  }

  @override
  Future<List<TripInvitation>> getMyInvitations({
    String status = 'PENDING',
  }) async => _invitations(
    await ApiClient.get(
      '${ApiEndpoints.trips}/invitations/me?status=$status&page=1&limit=50',
    ),
  );

  @override
  Future<List<TripInvitation>> getTripInvitations(
    String tripId, {
    String status = 'PENDING',
  }) async => _invitations(
    await ApiClient.get(
      '${ApiEndpoints.trips}/$tripId/invitations?status=$status&page=1&limit=50',
    ),
  );

  @override
  Future<TripInvitation> sendInvitation(
    String tripId,
    String inviteeUserId, {
    int expiresInHours = 72,
  }) async => TripInvitation.fromJson(
    _data(
      await ApiClient.post(
        '${ApiEndpoints.trips}/$tripId/invitations',
        body: {
          'inviteeUserId': inviteeUserId,
          'expiresInHours': expiresInHours,
        },
      ),
    ),
  );

  @override
  Future<void> acceptInvitation(String invitationId) async {
    await ApiClient.post(
      '${ApiEndpoints.trips}/invitations/$invitationId/accept',
    );
  }

  @override
  Future<void> rejectInvitation(String invitationId) async {
    await ApiClient.post(
      '${ApiEndpoints.trips}/invitations/$invitationId/reject',
    );
  }

  @override
  Future<void> revokeInvitation(String tripId, String invitationId) async {
    await ApiClient.delete(
      '${ApiEndpoints.trips}/$tripId/invitations/$invitationId',
    );
  }

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
