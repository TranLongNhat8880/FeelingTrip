import '../models/itinerary_model.dart';
import 'itinerary_repository.dart';

class MockItineraryRepository implements ItineraryRepository {
  MockItineraryRepository();

  static final MockItineraryRepository shared = MockItineraryRepository();

  final Map<String, List<ItineraryDay>> _daysByTrip = {};
  int _sequence = 10;

  void setDaysForTrip(String tripId, List<ItineraryDay> days) =>
      _daysByTrip[tripId] = days;

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
    final ordered = orderedItemIds.map((id) => byId[id]!).toList();
    if (ordered.isNotEmpty) {
      int cursor = _toMinutes(ordered.first.startTime);
      for (int i = 0; i < ordered.length; i++) {
        final item = ordered[i];
        final dur = _toMinutes(item.endTime) - _toMinutes(item.startTime);
        if (dur > 0) {
          final newStart = _toTimeString(cursor);
          final newEnd = _toTimeString(cursor + dur);
          ordered[i] = _copyItem(item, startTime: newStart, endTime: newEnd);
          cursor += dur;
        }
      }
    }
    final updated = _copyDay(
      day,
      items: ordered,
      version: '${_sequence++}',
    );
    _replaceDay(updated);
    return updated;
  }

  static int _toMinutes(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  static String _toTimeString(int minutes) {
    final clamped = minutes.clamp(0, 23 * 60 + 59);
    final h = (clamped ~/ 60).toString().padLeft(2, '0');
    final m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
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

  static const List<ItineraryPlaceOption> _mockCatalogPlaces = [
    ItineraryPlaceOption(
      id: 'place-hanoi-1',
      name: 'Hồ Hoàn Kiếm',
      destination: 'Hà Nội',
      category: 'NATURE',
      address: 'Phố Đinh Tiên Hoàng, Hàng Trống, Hoàn Kiếm, Hà Nội',
      latitude: 21.0285,
      longitude: 105.8542,
      rating: 4.9,
    ),
    ItineraryPlaceOption(
      id: 'place-hanoi-2',
      name: 'Văn Miếu - Quốc Tử Giám',
      destination: 'Hà Nội',
      category: 'CULTURE',
      address: '58 Quốc Tử Giám, Văn Miếu, Đống Đa, Hà Nội',
      latitude: 21.0276,
      longitude: 105.8355,
      rating: 4.8,
    ),
    ItineraryPlaceOption(
      id: 'place-hanoi-3',
      name: 'Hồ Tây',
      destination: 'Hà Nội',
      category: 'NATURE',
      address: 'Đường Thanh Niên, Tây Hồ, Hà Nội',
      latitude: 21.0581,
      longitude: 105.8236,
      rating: 4.7,
    ),
    ItineraryPlaceOption(
      id: 'place-hanoi-4',
      name: 'Lăng Chủ tịch Hồ Chí Minh',
      destination: 'Hà Nội',
      category: 'CULTURE',
      address: 'Số 2 Hùng Vương, Điện Biên, Ba Đình, Hà Nội',
      latitude: 21.0368,
      longitude: 105.8346,
      rating: 4.9,
    ),
    ItineraryPlaceOption(
      id: 'place-hanoi-5',
      name: 'Khu du lịch Hàm Lợn',
      destination: 'Hà Nội',
      category: 'NATURE',
      address: 'Xã Nam Sơn, Huyện Sóc Sơn, Hà Nội',
      latitude: 21.3283,
      longitude: 105.7958,
      rating: 4.6,
    ),
    ItineraryPlaceOption(
      id: 'place-1',
      name: 'Hồ Xuân Hương',
      destination: 'Đà Lạt',
      category: 'NATURE',
      address: 'Trung tâm Đà Lạt, Lâm Đồng',
      latitude: 11.9404,
      longitude: 108.4452,
      rating: 4.8,
    ),
    ItineraryPlaceOption(
      id: 'place-2',
      name: 'Quảng trường Lâm Viên',
      destination: 'Đà Lạt',
      category: 'ATTRACTION',
      address: 'Đường Trần Quốc Toản, Phường 10, Đà Lạt',
      latitude: 11.9360,
      longitude: 108.4458,
      rating: 4.7,
    ),
    ItineraryPlaceOption(
      id: 'place-3',
      name: 'Thung Lũng Tình Yêu',
      destination: 'Đà Lạt',
      category: 'NATURE',
      address: '3 - 5 - 7 Đường Mai Anh Đào, Phường 8, Đà Lạt',
      latitude: 11.9792,
      longitude: 108.4502,
      rating: 4.6,
    ),
    ItineraryPlaceOption(
      id: 'place-danang-1',
      name: 'Cầu Rồng',
      destination: 'Đà Nẵng',
      category: 'ATTRACTION',
      address: 'Đường Nguyễn Văn Linh, Phước Ninh, Hải Châu, Đà Nẵng',
      latitude: 16.0611,
      longitude: 108.2208,
      rating: 4.8,
    ),
  ];

  @override
  Future<List<ItineraryPlaceOption>> searchPlaces({
    required String destination,
    String? keyword,
  }) async {
    await _delay();
    final dest = destination.trim().toLowerCase();
    final kw = keyword?.trim().toLowerCase();

    var matches = _mockCatalogPlaces.where((p) {
      if (dest.isEmpty) return true;
      final pDest = p.destination.toLowerCase();
      return pDest.contains(dest) ||
          dest.contains(pDest) ||
          (p.address?.toLowerCase().contains(dest) ?? false);
    }).toList();

    if (matches.isEmpty && dest.isNotEmpty) {
      matches = List.of(_mockCatalogPlaces);
    }

    if (kw != null && kw.isNotEmpty) {
      matches = matches.where((p) {
        return p.name.toLowerCase().contains(kw) ||
            p.destination.toLowerCase().contains(kw) ||
            (p.address?.toLowerCase().contains(kw) ?? false);
      }).toList();
    }

    return matches;
  }

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
    String? startTime,
    String? endTime,
    String? version,
  }) => ItineraryItem(
    id: item.id,
    itineraryId: item.itineraryId,
    placeId: item.placeId,
    customName: item.customName,
    customAddress: item.customAddress,
    category: item.category,
    startTime: startTime ?? item.startTime,
    endTime: endTime ?? item.endTime,
    note: item.note,
    estimatedCost: item.estimatedCost,
    isCompleted: isCompleted ?? item.isCompleted,
    createdAt: item.createdAt,
    version: version ?? item.version,
  );

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 250));
}
