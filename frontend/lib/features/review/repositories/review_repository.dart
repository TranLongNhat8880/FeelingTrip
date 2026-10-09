import '../models/review_model.dart';

abstract class ReviewRepository {
  Future<ReviewModel> reviewTrip({
    required String tripId,
    required int rating,
    String? comment,
  });

  Future<ReviewModel> reviewMember({
    required String tripId,
    required String revieweeId,
    required int rating,
    String? comment,
  });

  Future<UserReportModel> createReport({
    String? reportedUserId,
    String? reportedTripId,
    required String reason,
    List<int>? evidenceBytes,
    String? evidenceFileName,
  });

  Future<void> blockUser(String userId);

  Future<void> unblockUser(String userId);

  Future<List<BlockedUserModel>> getBlockedUsers();

  Future<List<EmergencyContactModel>> getEmergencyContacts();

  Future<EmergencyContactModel> createEmergencyContact({
    required String fullName,
    required String phone,
    String? relationship,
  });

  Future<EmergencyContactModel> updateEmergencyContact({
    required String contactId,
    required String fullName,
    required String phone,
    String? relationship,
  });

  Future<void> deleteEmergencyContact(String contactId);
}
