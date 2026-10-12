import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/expense_model.dart';

abstract class ExpenseRepository {
  Future<ExpenseSnapshot> load(String tripId);
  Future<void> create(Map<String, dynamic> payload);
  Future<void> optimize(String tripId);
  Future<void> updateBudget(String tripId, int amount);
  Future<PaymentStatus> payment(String settlementId);
  Future<void> linkExpense(String expenseId, String itineraryItemId);
}

class ApiExpenseRepository implements ExpenseRepository {
  String get _base => ApiEndpoints.expenses;
  @override
  Future<void> linkExpense(String expenseId, String itineraryItemId) async {
    await ApiClient.put(
      '$_base/$expenseId/itinerary-item',
      body: {'itineraryItemId': itineraryItemId},
    );
  }

  @override
  Future<ExpenseSnapshot> load(String tripId) async {
    final results = await Future.wait([
      ApiClient.get('$_base/trip/$tripId'),
      ApiClient.get('$_base/trip/$tripId/balances'),
      ApiClient.get('$_base/trip/$tripId/settlements'),
      ApiClient.get('$_base/trip/$tripId/planned-costs'),
    ]);
    final raw = results[0]['data'];
    if (raw is! Map ||
        raw['summary'] is! Map ||
        raw['expenses'] is! List ||
        results[1]['data'] is! List ||
        results[2]['data'] is! List ||
        results[3]['data'] is! List) {
      throw const FormatException('Dữ liệu chi phí không hợp lệ');
    }
    final data = object(raw);
    return ExpenseSnapshot(
      summary: object(data['summary']),
      expenses: objects(data['expenses']).map(ExpenseRecord.fromJson).toList(),
      balances: objects(results[1]['data']),
      settlements: objects(
        results[2]['data'],
      ).map(Settlement.fromJson).toList(),
      plannedCosts: objects(
        results[3]['data'],
      ).map(PlannedCost.fromJson).toList(),
    );
  }

  @override
  Future<void> create(Map<String, dynamic> payload) async {
    await ApiClient.post(_base, body: payload);
  }

  @override
  Future<void> optimize(String tripId) async {
    await ApiClient.post('$_base/trip/$tripId/settle');
  }

  @override
  Future<void> updateBudget(String tripId, int amount) async {
    await ApiClient.put(
      '$_base/trip/$tripId/budget',
      body: {'estimatedBudget': amount},
    );
  }

  @override
  Future<PaymentStatus> payment(String settlementId) async {
    final raw = (await ApiClient.get(
      '$_base/settlement/$settlementId/status',
    ))['data'];
    if (raw is! Map ||
        !{'PENDING', 'REPORTED', 'PAID', 'CANCELLED'}.contains(raw['status']) ||
        num.tryParse('${raw['amount']}') == null ||
        vnd(raw['amount']) <= 0) {
      throw const FormatException('Dữ liệu thanh toán không hợp lệ');
    }
    return PaymentStatus.fromJson(object(raw));
  }
}
