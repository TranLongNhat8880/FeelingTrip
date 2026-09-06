// ================================================================================
// MODEL: Trip (Chuyến đi)
// ================================================================================

class TripModel {
  final int id;
  final String name;
  final String? destination;
  final DateTime startDate;
  final DateTime endDate;
  final double? budget;
  final String? coverImageUrl;
  final String status; // 'upcoming', 'ongoing', 'completed', 'cancelled'
  final bool isPublic;
  final int createdBy;
  final DateTime? createdAt;

  TripModel({
    required this.id,
    required this.name,
    this.destination,
    required this.startDate,
    required this.endDate,
    this.budget,
    this.coverImageUrl,
    this.status = 'upcoming',
    this.isPublic = false,
    required this.createdBy,
    this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'],
      name: json['name'],
      destination: json['destination'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      budget: json['budget'] != null ? (json['budget'] as num).toDouble() : null,
      coverImageUrl: json['cover_image_url'],
      status: json['status'] ?? 'upcoming',
      isPublic: json['is_public'] ?? false,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'destination': destination,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'budget': budget,
      'is_public': isPublic,
    };
  }

  /// Tính số ngày chuyến đi
  int get totalDays => endDate.difference(startDate).inDays + 1;
}
