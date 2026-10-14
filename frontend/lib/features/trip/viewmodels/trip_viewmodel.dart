import 'package:flutter/foundation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/trip_model.dart';
import '../repositories/api_trip_repository.dart';
import '../repositories/mock_trip_repository.dart';
import '../repositories/trip_repository.dart';

class TripViewModel extends ChangeNotifier {
  TripViewModel({TripRepository? repository})
    : repository =
          repository ??
          (ApiEndpoints.useMockData
              ? MockTripRepository()
              : ApiTripRepository());

  final TripRepository repository;
  List<TripModel> _trips = [];
  TripModel? _selectedTrip;
  List<TripInvitation> _invitations = [];
  List<TripInvitation> _tripInvitations = [];
  bool _isLoading = false;
  bool _isLoadingTripInvitations = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<TripModel> get trips => List.unmodifiable(_trips);
  TripModel? get selectedTrip => _selectedTrip;
  List<TripInvitation> get invitations => List.unmodifiable(_invitations);
  List<TripInvitation> get tripInvitations =>
      List.unmodifiable(_tripInvitations);
  bool get isLoading => _isLoading;
  bool get isLoadingTripInvitations => _isLoadingTripInvitations;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> loadTrips() async {
    _setLoading(true);
    try {
      final page = await repository.getMyTrips(includeHistory: true);
      _trips = page.items
          .where((trip) => trip.membershipStatus == 'ACTIVE')
          .toList();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(error, 'Không tải được danh sách chuyến đi.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTrip(String tripId) async {
    _setLoading(true);
    try {
      _selectedTrip = await repository.getTripById(tripId);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(error, 'Không tải được chi tiết chuyến đi.');
    } finally {
      _setLoading(false);
    }
  }

  Future<TripModel?> createTrip(TripFormData data) async =>
      _submit(() => repository.createTrip(data));

  Future<TripModel?> updateTrip(TripModel trip, TripFormData data) async =>
      _submit(() => repository.updateTrip(trip, data));

  Future<TripModel?> joinByCode(String code) async =>
      _submit(() => repository.joinByCode(code));

  Future<bool> transitionStatus(String status) async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return await _submit(() => repository.transitionStatus(trip, status)) !=
        null;
  }

  Future<bool> cancelTrip({String? reason}) async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return await _submit(() => repository.cancelTrip(trip, reason: reason)) !=
        null;
  }

  Future<String?> generateInviteCode() async {
    final trip = _selectedTrip;
    if (trip == null) return null;
    _setSubmitting(true);
    try {
      final code = await repository.generateInviteCode(trip.id);
      await loadTrip(trip.id);
      return code;
    } catch (error) {
      _errorMessage = _message(error, 'Không tạo được mã mời.');
      return null;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<bool> revokeInviteCode() async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return _action(() async {
      await repository.revokeInviteCode(trip.id);
      await loadTrip(trip.id);
    });
  }

  Future<bool> leaveTrip() async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return _action(() => repository.leaveTrip(trip.id));
  }

  Future<bool> kickMember(String userId) async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return _action(() async {
      await repository.kickMember(trip.id, userId);
      await loadTrip(trip.id);
    });
  }

  Future<bool> transferLeader(String userId) async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return await _submit(() => repository.transferLeader(trip, userId)) != null;
  }

  Future<void> loadMyInvitations() async {
    _setLoading(true);
    try {
      _invitations = await repository.getMyInvitations();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(error, 'Không tải được lời mời.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> respondInvitation(String id, {required bool accept}) async =>
      _action(() async {
        if (accept) {
          await repository.acceptInvitation(id);
        } else {
          await repository.rejectInvitation(id);
        }
        await loadMyInvitations();
      });

  Future<void> loadTripInvitations(String tripId) async {
    _tripInvitations = [];
    _setLoadingTripInvitations(true);
    try {
      _tripInvitations = await repository.getTripInvitations(tripId);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _message(
        error,
        'Không tải được danh sách lời mời của chuyến đi.',
      );
    } finally {
      _setLoadingTripInvitations(false);
    }
  }

  Future<bool> sendTripInvitation(
    String inviteeUserId, {
    int expiresInHours = 72,
  }) async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return _action(() async {
      final invitation = await repository.sendInvitation(
        trip.id,
        inviteeUserId.trim(),
        expiresInHours: expiresInHours,
      );
      _tripInvitations.insert(0, invitation);
    });
  }

  Future<bool> revokeTripInvitation(String invitationId) async {
    final trip = _selectedTrip;
    if (trip == null) return false;
    return _action(() async {
      await repository.revokeInvitation(trip.id, invitationId);
      _tripInvitations.removeWhere((item) => item.id == invitationId);
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<TripModel?> _submit(Future<TripModel> Function() operation) async {
    if (_isSubmitting) return null;
    _setSubmitting(true);
    try {
      final result = await operation();
      _selectedTrip = result;
      _replace(result);
      _errorMessage = null;
      return result;
    } catch (error) {
      _errorMessage = _message(error, 'Chưa thực hiện được thao tác.');
      return null;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<bool> _action(Future<void> Function() operation) async {
    if (_isSubmitting) return false;
    _setSubmitting(true);
    try {
      await operation();
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _message(error, 'Chưa thực hiện được thao tác.');
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  void _replace(TripModel trip) {
    final index = _trips.indexWhere((item) => item.id == trip.id);
    if (index < 0) {
      _trips.insert(0, trip);
    } else {
      _trips[index] = trip;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setLoadingTripInvitations(bool value) {
    _isLoadingTripInvitations = value;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  String _message(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final text = '$error'.replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
  }
}
