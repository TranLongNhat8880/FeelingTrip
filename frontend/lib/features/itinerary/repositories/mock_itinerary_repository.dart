import '../models/itinerary_model.dart';
import 'itinerary_repository.dart';

class MockItineraryRepository implements ItineraryRepository {
  MockItineraryRepository();

  final Map<String, List<ItineraryDay>> _daysByTrip = {};
  int _sequence = 10;

  @override
  Future<ItineraryPlan> getItinerary(String tripId) async {
    await _delay();
    final days = _daysByTrip.putIfAbsent(tripId, () => _sampleDays(tripId));
    return ItineraryPlan(
      trip: ItineraryTripHeader(
        id: tripId,
        name: 'Chuyến đi Đà Lạt',
        startDate: DateTime.now().add(const Duration(days: 7)),
        endDate: DateTime.now().add(const Duration(days: 9)),
        status: 'UPCOMING',
        memberRole: 'LEADER',
      ),
      days: List.unmodifiable(days),
    );
  }

  @override
  Future<ItineraryDay> createDay(
    String tripId, {
    required int dayNumber,
    String? title,
  }) async {
    await _delay();
    final days = _daysByTrip.putIfAbsent(tripId, () => []);
    final existing = days
        .where((day) => day.dayNumber == dayNumber)
        .firstOrNull;
    if (existing != null && existing.materialized) return existing;
    final day = ItineraryDay(
      id: 'day-${_sequence++}',
      tripId: tripId,
      dayNumber: dayNumber,
      title: title ?? 'Ngày $dayNumber',
      tripDate: DateTime.now().add(Duration(days: 6 + dayNumber)),
      materialized: true,
      version: '${_sequence++}',
      items: const [],
    );
    days.removeWhere((value) => value.dayNumber == dayNumber);
    days.add(day);
    days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return day;
  }

  @override
  Future<ItineraryDay> updateDay(
    ItineraryDay day, {
    required String title,
  }) async {
    final updated = _copyDay(day, title: title, version: '${_sequence++}');
    _replaceDay(updated);
    return updated;
  }

  @override
  Future<ItineraryItem> addItem(String dayId, ItineraryItemDraft draft) async {
    await _delay();
    final day = _findDay(dayId);
    final item = ItineraryItem(
      id: 'item-${_sequence++}',
      itineraryId: dayId,
      placeId: draft.placeId,
      customName: draft.customName,
      customAddress: draft.customAddress,
      category: draft.category,
      latitude: draft.latitude,
      longitude: draft.longitude,
      locationSource: draft.locationSource,
      externalProvider: draft.externalProvider,
      externalPlaceId: draft.externalPlaceId,
      startTime: draft.startTime,
      endTime: draft.endTime,
      note: draft.note,
      estimatedCost: draft.estimatedCost,
      isCompleted: false,
      version: '${_sequence++}',
    );
    _replaceDay(_copyDay(day, items: [...day.items, item]));
    return item;
  }

  @override
  Future<ItineraryItem> updateItem(
    ItineraryItem item,
    ItineraryItemDraft draft,
  ) async {
    await _delay();
    final updated = ItineraryItem(
      id: item.id,
      itineraryId: item.itineraryId,
      placeId: draft.placeId ?? item.placeId,
      customName: draft.customName,
      customAddress: draft.customAddress,
      category: draft.category,
      latitude: draft.latitude ?? item.latitude,
      longitude: draft.longitude ?? item.longitude,
      locationSource: draft.locationSource,
      externalProvider: draft.externalProvider ?? item.externalProvider,
      externalPlaceId: draft.externalPlaceId ?? item.externalPlaceId,
      startTime: draft.startTime,
      endTime: draft.endTime,
      note: draft.note,
      estimatedCost: draft.estimatedCost,
      isCompleted: item.isCompleted,
      version: '${_sequence++}',
    );
    _replaceItem(updated);
    return updated;
  }

  @override
  Future<void> deleteItem(ItineraryItem item) async {
    final day = _findDay(item.itineraryId);
    _replaceDay(
      _copyDay(
        day,
        items: day.items.where((row) => row.id != item.id).toList(),
      ),
    );
  }

  @override
  Future<ItineraryItem> setCompletion(
    ItineraryItem item, {
    required bool isCompleted,
  }) async {
    final updated = _copyItem(
      item,
      isCompleted: isCompleted,
      version: '${_sequence++}',
    );
    _replaceItem(updated);
    return updated;
  }

  @override
  Future<ItineraryDay> reorderItems(
    ItineraryDay day,
    List<String> orderedItemIds,
  ) async {
    final byId = {for (final item in day.items) item.id: item};
    final updated = _copyDay(
      day,
      items: orderedItemIds.map((id) => byId[id]!).toList(),
      version: '${_sequence++}',
    );
    _replaceDay(updated);
    return updated;
  }

  @override
  Future<List<SwapCandidate>> getSwapCandidates(
    String itemId, {
    double radiusKm = 3,
    int limit = 10,
  }) async => const [
    SwapCandidate(
      placeId: 'place-swap',
      name: 'Quảng trường Lâm Viên',
      address: 'Phường 10, Đà Lạt',
      category: 'ATTRACTION',
      rating: 4.7,
      distanceFromOriginalKm: 1.2,
      routeDeltaKm: 0.4,
      candidateToken: 'mock-candidate-token-long-enough',
    ),
  ];

  @override
  Future<ItineraryItem> applySmartSwap(
    ItineraryItem item,
    SwapCandidate candidate,
  ) async {
    final updated = ItineraryItem(
      id: item.id,
      itineraryId: item.itineraryId,
      placeId: candidate.placeId,
      customName: candidate.name,
      customAddress: candidate.address,
      category: candidate.category,
      startTime: item.startTime,
      endTime: item.endTime,
      note: item.note,
      estimatedCost: item.estimatedCost,
      isCompleted: item.isCompleted,
      version: '${_sequence++}',
    );
    _replaceItem(updated);
    return updated;
  }

  @override
  Future<List<ItineraryPlaceOption>> searchPlaces({
    required String destination,
    String? keyword,
  }) async => const [
    ItineraryPlaceOption(
      id: 'place-1',
      name: 'Hồ Xuân Hương',
      destination: 'Đà Lạt',
      category: 'NATURE',
      address: 'Trung tâm Đà Lạt',
      rating: 4.8,
    ),
    ItineraryPlaceOption(
      id: 'place-2',
      name: 'Quảng trường Lâm Viên',
      destination: 'Đà Lạt',
      category: 'ATTRACTION',
      address: 'Đường Trần Quốc Toản',
      rating: 4.7,
    ),
  ];

  @override
  Future<PublicItineraryPage> getPublicPlans({
    String? destination,
    int? durationDays,
    String? keyword,
  }) async => PublicItineraryPage(items: [_publicSummary], total: 1);

  @override
  Future<PublicItineraryDetail> getPublicPlan(String sourceTripId) async =>
      PublicItineraryDetail(
        summary: _publicSummary,
        days: const [
          PublicItineraryDay(
            dayNumber: 1,
            title: 'Khám phá trung tâm',
            items: [
              PublicItineraryItem(
                customName: 'Hồ Xuân Hương',
                customAddress: 'Trung tâm Đà Lạt',
                category: 'NATURE',
                startTime: '08:00',
                endTime: '10:00',
              ),
            ],
          ),
        ],
      );

  @override
  Future<ItineraryPlan> clonePlan(
    String sourceTripId, {
    required DateTime startDate,
    String? name,
  }) async => getItinerary('trip-clone-${_sequence++}');

  PublicItinerarySummary get _publicSummary => const PublicItinerarySummary(
    sourceTripId: 'public-trip-1',
    name: 'Đà Lạt 3 ngày thư giãn',
    destination: 'Đà Lạt',
    durationDays: 3,
    averageRating: 4.8,
    reviewCount: 24,
    cloneCount: 16,
    description: 'Lịch trình nhẹ nhàng qua các điểm nổi bật ở Đà Lạt.',
  );

  List<ItineraryDay> _sampleDays(String tripId) => [
    ItineraryDay(
      id: 'day-1',
      tripId: tripId,
      dayNumber: 1,
      title: 'Khám phá trung tâm',
      tripDate: DateTime.now().add(const Duration(days: 7)),
      materialized: true,
      version: '1',
      items: const [
        ItineraryItem(
          id: 'item-1',
          itineraryId: 'day-1',
          placeId: 'place-1',
          customName: 'Hồ Xuân Hương',
          customAddress: 'Trung tâm Đà Lạt',
          category: 'NATURE',
          startTime: '08:00',
          endTime: '10:00',
          estimatedCost: 0,
          isCompleted: false,
          version: '1',
        ),
      ],
    ),
    ItineraryDay(
      tripId: tripId,
      dayNumber: 2,
      title: 'Ngày 2',
      tripDate: DateTime.now().add(const Duration(days: 8)),
      materialized: false,
      items: const [],
    ),
    ItineraryDay(
      tripId: tripId,
      dayNumber: 3,
      title: 'Ngày 3',
      tripDate: DateTime.now().add(const Duration(days: 9)),
      materialized: false,
      items: const [],
    ),
  ];

  ItineraryDay _findDay(String dayId) => _daysByTrip.values
      .expand((days) => days)
      .firstWhere((day) => day.id == dayId);

  void _replaceDay(ItineraryDay updated) {
    final days = _daysByTrip[updated.tripId]!;
    final index = days.indexWhere((day) => day.dayNumber == updated.dayNumber);
    if (index < 0) {
      days.add(updated);
    } else {
      days[index] = updated;
    }
  }

  void _replaceItem(ItineraryItem updated) {
    final day = _findDay(updated.itineraryId);
    _replaceDay(
      _copyDay(
        day,
        items: day.items
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      ),
    );
  }

  ItineraryDay _copyDay(
    ItineraryDay day, {
    String? title,
    String? version,
    List<ItineraryItem>? items,
  }) => ItineraryDay(
    id: day.id,
    tripId: day.tripId,
    dayNumber: day.dayNumber,
    title: title ?? day.title,
    tripDate: day.tripDate,
    materialized: day.materialized,
    createdAt: day.createdAt,
    version: version ?? day.version,
    items: items ?? day.items,
  );

  ItineraryItem _copyItem(
    ItineraryItem item, {
    bool? isCompleted,
    String? version,
  }) => ItineraryItem(
    id: item.id,
    itineraryId: item.itineraryId,
    placeId: item.placeId,
    customName: item.customName,
    customAddress: item.customAddress,
    category: item.category,
    startTime: item.startTime,
    endTime: item.endTime,
    note: item.note,
    estimatedCost: item.estimatedCost,
    isCompleted: isCompleted ?? item.isCompleted,
    createdAt: item.createdAt,
    version: version ?? item.version,
  );

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 250));
}
