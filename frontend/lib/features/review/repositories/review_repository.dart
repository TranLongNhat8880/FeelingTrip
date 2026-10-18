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
}
