import '../../itinerary/repositories/itinerary_repository.dart';
import '../../itinerary/repositories/mock_itinerary_repository.dart';
import '../models/trip_model.dart';
import 'trip_repository.dart';

class MockTripRepository implements TripRepository {
  MockTripRepository({
    ItineraryRepository? itineraryRepository,
    Map<String, String>? itineraryValidationErrorsByTripId,
  })  : _itineraryRepository = itineraryRepository,
        _itineraryValidationErrorsByTripId =
            itineraryValidationErrorsByTripId ?? {} {
    _trips.addAll([
      _trip(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Hành trình Đà Nẵng – Hội An',
        destination: 'Đà Nẵng',
        start: DateTime.now().add(const Duration(days: 12)),
        end: DateTime.now().add(const Duration(days: 15)),
        budget: 6000000,
        role: 'LEADER',
        image:
            'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=900&q=80',
      ),
      _trip(
        id: '22222222-2222-4222-8222-222222222222',
        name: 'Săn mây Đà Lạt',
        destination: 'Đà Lạt',
        start: DateTime.now().add(const Duration(days: 2)),
        end: DateTime.now().add(const Duration(days: 4)),
        budget: 3500000,
        role: 'MEMBER',
        status: 'ONGOING',
        image:
            'https://images.unsplash.com/photo-1528127269322-539801943592?w=900&q=80',
      ),
      _trip(
        id: '33333333-3333-4333-8333-333333333333',
        name: 'Khám phá Phú Quốc',
        destination: 'Phú Quốc',
        start: DateTime.now().subtract(const Duration(days: 40)),
        end: DateTime.now().subtract(const Duration(days: 36)),
        budget: 9000000,
        role: 'LEADER',
        status: 'COMPLETED',
        image:
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&q=80',
      ),
    ]);
  }

  final List<TripModel> _trips = [];
  final ItineraryRepository? _itineraryRepository;
  final Map<String, String> _itineraryValidationErrorsByTripId;

  void setItineraryValidationError(String tripId, String errorMessage) {
    _itineraryValidationErrorsByTripId[tripId] = errorMessage;
  }

  TripModel _trip({
    required String id,
    required String name,
    required String destination,
    required DateTime start,
    required DateTime end,
    required int budget,
    required String role,
    String status = 'UPCOMING',
    String privacyType = 'PRIVATE',
    String? image,
    String? destinationProvider,
    String? destinationExternalId,
    double? destinationLatitude,
    double? destinationLongitude,
  }) {
    final now = DateTime.now();
    final members = [
      TripMember(
        userId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        displayName: 'Nguyễn Minh Phú',
        role: role,
        membershipStatus: 'ACTIVE',
        joinedAt: now.subtract(const Duration(days: 20)),
      ),
      TripMember(
        userId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        displayName: 'Trần Thu Hà',
        role: role == 'LEADER' ? 'MEMBER' : 'LEADER',
        membershipStatus: 'ACTIVE',
        joinedAt: now.subtract(const Duration(days: 15)),
      ),
    ];
    return TripModel(
      id: id,
      name: name,
      destination: destination,
      startDate: start,
      endDate: end,
      estimatedBudget: budget,
      coverImageUrl: image,
      description: 'Một hành trình nhiều trải nghiệm cùng những người bạn mới.',
      privacyType: privacyType,
      status: status,
      memberRole: role,
      memberCount: members.length,
      members: members,
      inviteCode: role == 'LEADER' ? 'A1B2C3' : null,
      inviteCodeStatus: role == 'LEADER' ? 'ACTIVE' : null,
      destinationProvider: destinationProvider,
      destinationExternalId: destinationExternalId,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now,
    );
  }

  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<TripPage> getMyTrips({
    String? status,
    bool includeHistory = true,
  }) async {
    await _wait();
    final items = status == null
        ? List<TripModel>.of(_trips)
        : _trips.where((trip) => trip.status == status).toList();
    return TripPage(items: items, total: items.length);
  }

  @override
  Future<TripModel> getTripById(String tripId) async {
    await _wait();
    return _trips.firstWhere((trip) => trip.id == tripId);
  }

  @override
  Future<TripModel> createTrip(TripFormData data) async {
    await _wait();
    final trip = _trip(
      id: '44444444-4444-4444-8444-${DateTime.now().millisecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}',
      name: data.name?.trim().isNotEmpty == true
          ? data.name!.trim()
          : 'Chuyến đi ${data.destination}',
      destination: data.destination,
      start: data.startDate,
      end: data.endDate,
      budget: data.estimatedBudget,
      role: 'LEADER',
      privacyType: data.privacyType,
      image: data.coverImageUrl,
      destinationProvider: data.destinationProvider,
      destinationExternalId: data.destinationExternalId,
      destinationLatitude: data.destinationLatitude,
      destinationLongitude: data.destinationLongitude,
    );
    _trips.insert(0, trip);
    return trip;
  }

  @override
  Future<TripModel> updateTrip(TripModel trip, TripFormData data) async {
    await _wait();
    final updated = _copy(
      trip,
      name: data.name,
      destination: data.destination,
      startDate: data.startDate,
      endDate: data.endDate,
      estimatedBudget: data.estimatedBudget,
      privacyType: data.privacyType,
      description: data.description,
      coverImageUrl: data.coverImageUrl,
      destinationProvider: data.destinationProvider,
      destinationExternalId: data.destinationExternalId,
      destinationLatitude: data.destinationLatitude,
      destinationLongitude: data.destinationLongitude,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<TripModel> transitionStatus(TripModel trip, String status) async {
    await _wait();
    if (status == 'ONGOING') {
      if (_itineraryValidationErrorsByTripId.containsKey(trip.id)) {
        throw Exception(_itineraryValidationErrorsByTripId[trip.id]!);
      }
      final itinRepo = _itineraryRepository ?? MockItineraryRepository.shared;
      final plan = await itinRepo.getItinerary(trip.id);
      if (plan.days.isEmpty) {
        throw Exception(
          'Chuyến đi chưa có lịch trình. Vui lòng tạo lịch trình trước khi bắt đầu.',
        );
      }
      final allItems = plan.days.expand((d) => d.items).toList();
      if (allItems.isEmpty) {
        throw Exception(
          'Lịch trình chưa có điểm đến nào. Vui lòng thêm ít nhất một điểm đến trước khi bắt đầu.',
        );
      }

      for (final day in plan.days) {
        final dayLabel = 'Ngày ${day.dayNumber}';
        for (int i = 0; i < day.items.length; i++) {
          final item = day.items[i];
          final start = item.startTime;
          final end = item.endTime;
          if (start.compareTo(end) >= 0) {
            throw Exception(
              'Lịch trình chưa hợp lệ để bắt đầu chuyến đi: $dayLabel: "${item.customName}" có thời gian không hợp lệ ($start >= $end)',
            );
          }
          if (i < day.items.length - 1) {
            final next = day.items[i + 1];
            if (end.compareTo(next.startTime) > 0) {
              throw Exception(
                'Lịch trình chưa hợp lệ để bắt đầu chuyến đi: $dayLabel: "${item.customName}" (kết thúc $end) chồng lấn với "${next.customName}" (bắt đầu ${next.startTime})',
              );
            }
          }
        }
      }
    }
    final updated = _copy(trip, status: status);
    _replace(updated);
    return updated;
  }

  @override
  Future<TripModel> cancelTrip(TripModel trip, {String? reason}) async {
    await _wait();
    final updated = _copy(trip, status: 'CANCELLED');
    _replace(updated);
    return updated;
  }

  @override
  Future<TripModel> joinByCode(String inviteCode) async {
    await _wait();
    if (inviteCode.trim().toUpperCase() != 'A1B2C3') {
      throw Exception('Mã mời không hợp lệ');
    }
    return _trips.first;
  }

  @override
  Future<void> leaveTrip(String tripId) async {
    await _wait();
    _trips.removeWhere((trip) => trip.id == tripId);
  }

  @override
  Future<void> kickMember(String tripId, String userId) async {
    await _wait();
    final trip = await getTripById(tripId);
    _replace(
      _copy(
        trip,
        members: trip.members
            .where((member) => member.userId != userId)
            .toList(),
      ),
    );
  }

  @override
  Future<TripModel> transferLeader(
    TripModel trip,
    String newLeaderUserId,
  ) async {
    await _wait();
    final updated = _copy(trip, memberRole: 'MEMBER');
    _replace(updated);
    return updated;
  }

  @override
  Future<String> generateInviteCode(String tripId) async {
    await _wait();
    return 'D4E5F6';
  }

  @override
  Future<void> revokeInviteCode(String tripId) => _wait();

  @override
  Future<List<TripInvitation>> getMyInvitations({
    String status = 'PENDING',
  }) async {
    await _wait();
    return [
      TripInvitation(
        id: '55555555-5555-4555-8555-555555555555',
        tripId: _trips.first.id,
        tripName: _trips.first.name,
        destination: _trips.first.destination,
        inviterName: 'Trần Thu Hà',
        status: 'PENDING',
        expiresAt: DateTime.now().add(const Duration(days: 2)),
      ),
    ];
  }

  @override
  Future<List<TripInvitation>> getTripInvitations(
    String tripId, {
    String status = 'PENDING',
  }) async {
    await _wait();
    return [];
  }

  @override
  Future<TripInvitation> sendInvitation(
    String tripId,
    String inviteeUserId, {
    int expiresInHours = 72,
  }) async {
    await _wait();
    final trip = await getTripById(tripId);
    return TripInvitation(
      id: '66666666-6666-4666-8666-666666666666',
      tripId: trip.id,
      tripName: trip.name,
      destination: trip.destination,
      inviterName: 'Bạn',
      inviteeUserId: inviteeUserId,
      inviteeName: 'Người được mời',
      status: 'PENDING',
    );
  }

  @override
  Future<void> acceptInvitation(String invitationId) => _wait();
  @override
  Future<void> rejectInvitation(String invitationId) => _wait();
  @override
  Future<void> revokeInvitation(String tripId, String invitationId) => _wait();

  void _replace(TripModel trip) {
    final index = _trips.indexWhere((item) => item.id == trip.id);
    if (index >= 0) _trips[index] = trip;
  }

  TripModel _copy(
    TripModel trip, {
    String? name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    int? estimatedBudget,
    String? privacyType,
    String? status,
    String? description,
    String? coverImageUrl,
    String? memberRole,
    List<TripMember>? members,
    String? destinationProvider,
    String? destinationExternalId,
    double? destinationLatitude,
    double? destinationLongitude,
  }) => TripModel(
    id: trip.id,
    name: name ?? trip.name,
    destination: destination ?? trip.destination,
    startDate: startDate ?? trip.startDate,
    endDate: endDate ?? trip.endDate,
    estimatedBudget: estimatedBudget ?? trip.estimatedBudget,
    privacyType: privacyType ?? trip.privacyType,
    status: status ?? trip.status,
    description: description ?? trip.description,
    coverImageUrl: coverImageUrl ?? trip.coverImageUrl,
    memberRole: memberRole ?? trip.memberRole,
    membershipStatus: trip.membershipStatus,
    memberCount: members?.length ?? trip.memberCount,
    members: members ?? trip.members,
    inviteCode: trip.inviteCode,
    inviteCodeStatus: trip.inviteCodeStatus,
    destinationProvider: destinationProvider ?? trip.destinationProvider,
    destinationExternalId:
        destinationExternalId ?? trip.destinationExternalId,
    destinationLatitude: destinationLatitude ?? trip.destinationLatitude,
    destinationLongitude: destinationLongitude ?? trip.destinationLongitude,
    createdAt: trip.createdAt,
    updatedAt: DateTime.now(),
  );
}
