import '../models/itinerary_model.dart';

abstract class ItineraryRepository {
  Future<ItineraryPlan> getItinerary(String tripId);

  Future<ItineraryDay> createDay(
    String tripId, {
    required int dayNumber,
    String? title,
  });

  Future<ItineraryDay> updateDay(ItineraryDay day, {required String title});

  Future<ItineraryItem> addItem(String dayId, ItineraryItemDraft draft);

  Future<ItineraryItem> updateItem(
    ItineraryItem item,
    ItineraryItemDraft draft,
  );

  Future<void> deleteItem(ItineraryItem item);

  Future<ItineraryItem> setCompletion(
    ItineraryItem item, {
    required bool isCompleted,
  });

  Future<ItineraryDay> reorderItems(
    ItineraryDay day,
    List<String> orderedItemIds,
  );

  Future<List<SwapCandidate>> getSwapCandidates(
    String itemId, {
    double radiusKm = 3,
    int limit = 10,
  });

  Future<ItineraryItem> applySmartSwap(
    ItineraryItem item,
    SwapCandidate candidate,
  );

  Future<List<ItineraryPlaceOption>> searchPlaces({
    required String destination,
    String? keyword,
  });

  Future<PublicItineraryPage> getPublicPlans({
    String? destination,
    int? durationDays,
    String? keyword,
  });

  Future<PublicItineraryDetail> getPublicPlan(String sourceTripId);

  Future<ItineraryPlan> clonePlan(
    String sourceTripId, {
    required DateTime startDate,
    String? name,
  });
}
