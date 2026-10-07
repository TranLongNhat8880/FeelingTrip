import '../models/trip_model.dart';

abstract class TripRepository {
  Future<TripPage> getMyTrips({String? status, bool includeHistory = true});
  Future<TripModel> getTripById(String tripId);
  Future<TripModel> createTrip(TripFormData data);
  Future<TripModel> updateTrip(TripModel trip, TripFormData data);
  Future<TripModel> transitionStatus(TripModel trip, String status);
  Future<TripModel> cancelTrip(TripModel trip, {String? reason});
  Future<TripModel> joinByCode(String inviteCode);
  Future<void> leaveTrip(String tripId);
  Future<void> kickMember(String tripId, String userId);
  Future<TripModel> transferLeader(TripModel trip, String newLeaderUserId);
  Future<String> generateInviteCode(String tripId);
  Future<void> revokeInviteCode(String tripId);
  Future<List<TripInvitation>> getMyInvitations({String status = 'PENDING'});
  Future<List<TripInvitation>> getTripInvitations(
    String tripId, {
    String status = 'PENDING',
  });
  Future<TripInvitation> sendInvitation(
    String tripId,
    String inviteeUserId, {
    int expiresInHours = 72,
  });
  Future<void> acceptInvitation(String invitationId);
  Future<void> rejectInvitation(String invitationId);
  Future<void> revokeInvitation(String tripId, String invitationId);
}
