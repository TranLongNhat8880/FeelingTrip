int vnd(dynamic value) =>
    value is num ? value.round() : num.tryParse('$value')?.round() ?? 0;
Map<String, dynamic> object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> objects(dynamic value) =>
    value is List ? value.whereType<Map>().map(object).toList() : [];

const expenseCategories = {
  'FOOD': 'Ăn uống',
  'TRANSPORTATION': 'Di chuyển',
  'ACCOMMODATION': 'Lưu trú',
  'TICKETS': 'Vé tham quan',
  'SHOPPING': 'Mua sắm',
  'OTHER': 'Khác',
};
const splitTypes = {
  'EQUAL': 'Chia đều',
  'EXACT': 'Số tiền cụ thể',
  'PERCENTAGE': 'Theo phần trăm',
};

class ExpenseRecord {
  ExpenseRecord.fromJson(Map<String, dynamic> json)
    : id = '${json['id']}',
      title = '${json['title']}',
      amount = vnd(json['amount']),
      payerName = '${json['payer_name'] ?? 'Thành viên'}',
      category = '${json['category'] ?? 'OTHER'}',
      itineraryItemId = json['itinerary_item_id'] as String?,
      date = DateTime.tryParse('${json['expense_date']}')?.toLocal(),
      splits = objects(json['splits']);
  final String id, title, payerName, category;
  final String? itineraryItemId;
  final int amount;
  final DateTime? date;
  final List<Map<String, dynamic>> splits;
}

class PlannedCost {
  PlannedCost.fromJson(Map<String, dynamic> json)
    : id = '${json['id']}',
      title = '${json['customName']}',
      category = '${json['category'] ?? 'OTHER'}',
      dayNumber = vnd(json['dayNumber']),
      amount = vnd(json['estimatedCost']),
      date = DateTime.tryParse('${json['tripDate']}'),
      expenseId = json['expenseId'] as String?,
      actualAmount = json['actualAmount'] == null
          ? null
          : vnd(json['actualAmount']);
  final String id, title, category;
  final int dayNumber, amount;
  final DateTime? date;
  final String? expenseId;
  final int? actualAmount;
  String get expenseCategory => switch (category) {
    'RESTAURANT' || 'CAFE' => 'FOOD',
    'HOTEL' => 'ACCOMMODATION',
    'ATTRACTION' || 'ENTERTAINMENT' || 'CULTURE' => 'TICKETS',
    'SHOPPING' => 'SHOPPING',
    _ => 'OTHER',
  };
}

class Settlement {
  Settlement.fromJson(Map<String, dynamic> json)
    : id = '${json['id']}',
      fromId = '${object(json['fromUser'])['id']}',
      toId = '${object(json['toUser'])['id']}',
      fromName = '${object(json['fromUser'])['fullName'] ?? 'Thành viên'}',
      toName = '${object(json['toUser'])['fullName'] ?? 'Thành viên'}',
      amount = vnd(json['amount']),
      status = '${json['status']}',
      paidAt = DateTime.tryParse('${json['paidAt']}')?.toLocal();
  final String id, fromId, toId, fromName, toName, status;
  final int amount;
  final DateTime? paidAt;
  bool get isOpen => status == 'PENDING' || status == 'REPORTED';
}

class ExpenseSnapshot {
  const ExpenseSnapshot({
    required this.summary,
    required this.expenses,
    required this.balances,
    required this.settlements,
    this.plannedCosts = const [],
  });
  final Map<String, dynamic> summary;
  final List<ExpenseRecord> expenses;
  final List<Map<String, dynamic>> balances;
  final List<Settlement> settlements;
  final List<PlannedCost> plannedCosts;
  int get spent => vnd(summary['totalSpent']);
  int get budget => vnd(summary['estimatedBudget']);
  int get remaining => vnd(summary['remainingBudget']);
  int get pendingEstimated => vnd(summary['pendingEstimated']);
  int get projected =>
      vnd(summary['projectedTotal'] ?? spent + pendingEstimated);
  int get projectedRemaining => budget - projected;
}

class PaymentStatus {
  PaymentStatus.fromJson(Map<String, dynamic> json)
    : status = '${json['status']}',
      amount = vnd(json['amount']),
      automatic = json['automaticConfirmationAvailable'] == true,
      qrUrl = json['vietqrUrl'] as String?,
      accountNumber = '${json['bankAccountNumber'] ?? ''}',
      accountName = '${json['bankAccountName'] ?? json['recipientName'] ?? ''}',
      reference = '${json['paymentReference'] ?? ''}';
  final String status, accountNumber, accountName, reference;
  final int amount;
  final bool automatic;
  final String? qrUrl;
}
