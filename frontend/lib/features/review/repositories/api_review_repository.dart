import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/review_model.dart';
import 'review_repository.dart';

class ApiReviewRepository implements ReviewRepository {
  Map<String, dynamic> _mapData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const FormatException('Dữ liệu phản hồi không hợp lệ');
    }
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<ReviewModel> reviewTrip({
    required String tripId,
    required int rating,
    String? comment,
  }) async {
    final response = await ApiClient.post(
      '${ApiEndpoints.reviews}/trip',
      body: {
        'tripId': tripId,
        'rating': rating,
        'comment': comment?.trim() ?? '',
      },
    );

    return ReviewModel.fromJson(_mapData(response));
  }

  @override
  Future<ReviewModel> reviewMember({
    required String tripId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    final response = await ApiClient.post(
      '${ApiEndpoints.reviews}/member',
      body: {
        'tripId': tripId,
        'revieweeId': revieweeId,
        'rating': rating,
        'comment': comment?.trim() ?? '',
      },
    );

    return ReviewModel.fromJson(_mapData(response));
  }

  @override
  Future<UserReportModel> createReport({
    String? reportedUserId,
    String? reportedTripId,
    required String reason,
    List<int>? evidenceBytes,
    String? evidenceFileName,
  }) async {
    final fields = <String, String>{
      'reportedUserId': ?reportedUserId,
      'reportedTripId': ?reportedTripId,
      'reason': reason.trim(),
    };

    final response = evidenceBytes == null
        ? await ApiClient.post('${ApiEndpoints.reviews}/report', body: fields)
        : await ApiClient.multipart(
            'POST',
            '${ApiEndpoints.reviews}/report',
            fields: fields,
            files: [
              MultipartFileData(
                fieldName: 'evidence',
                fileName: evidenceFileName ?? 'evidence.jpg',
                bytes: evidenceBytes,
              ),
            ],
          );

    return UserReportModel.fromJson(_mapData(response));
  }

  @override
  Future<void> blockUser(String userId) async {
    await ApiClient.post(
      '${ApiEndpoints.reviews}/block',
      body: {'blockedUserId': userId},
    );
  }

  @override
  Future<void> unblockUser(String userId) async {
    await ApiClient.delete('${ApiEndpoints.reviews}/block/$userId');
  }

  @override
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    final response = await ApiClient.get(
      '${ApiEndpoints.reviews}/blocked-users',
    );
    final data = response['data'];

    if (data is! List) {
      throw const FormatException('Danh sách chặn không hợp lệ');
    }

    return data
        .whereType<Map>()
        .map(
          (item) => BlockedUserModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<EmergencyContactModel>> getEmergencyContacts() async {
    final response = await ApiClient.get(
      '${ApiEndpoints.reviews}/emergency-contacts',
    );
    final data = response['data'];

    if (data is! List) {
      throw const FormatException('Danh sách liên hệ khẩn cấp không hợp lệ');
    }

    return data
        .whereType<Map>()
        .map(
          (item) =>
              EmergencyContactModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<EmergencyContactModel> createEmergencyContact({
    required String fullName,
    required String phone,
    String? relationship,
  }) async {
    final response = await ApiClient.post(
      '${ApiEndpoints.reviews}/emergency-contacts',
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'relationship': relationship?.trim() ?? '',
      },
    );

    return EmergencyContactModel.fromJson(_mapData(response));
  }

  @override
  Future<EmergencyContactModel> updateEmergencyContact({
    required String contactId,
    required String fullName,
    required String phone,
    String? relationship,
  }) async {
    final response = await ApiClient.put(
      '${ApiEndpoints.reviews}/emergency-contacts/$contactId',
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'relationship': relationship?.trim() ?? '',
      },
    );

    return EmergencyContactModel.fromJson(_mapData(response));
  }

  @override
  Future<void> deleteEmergencyContact(String contactId) async {
    await ApiClient.delete(
      '${ApiEndpoints.reviews}/emergency-contacts/$contactId',
    );
  }
}
