class AdminReport {
  AdminReport(Map<String, dynamic> data)
    : id = '${data['id']}',
      reporterName = data['reporterName'] ?? '',
      reporterId = data['reporterId'],
      targetName =
          data['reportedUserName'] ??
          data['reportedTripName'] ??
          'Đối tượng báo cáo',
      reason = data['reason'] ?? '',
      status = data['status'] ?? 'PENDING',
      notes = data['adminNotes'],
      image = data['evidenceImageUrl'],
      userId = data['reportedUserId'],
      userAvatarUrl = data['reportedUserAvatarUrl'],
      tripId = data['reportedTripId'],
      userStatus = data['reportedUserStatus'],
      userRole = data['reportedUserRole'],
      context = Map<String, dynamic>.from(data['context'] ?? {}),
      createdAt = DateTime.tryParse(data['createdAt'] ?? '')?.toLocal();
  final String id, reporterName, targetName, reason, status;
  final String? notes,
      image,
      userId,
      tripId,
      userStatus,
      userRole,
      reporterId,
      userAvatarUrl;
  final DateTime? createdAt;
  final Map<String, dynamic> context;
  bool get isTripReport => tripId != null && userId == null;
  bool get supportsTripProcessing => context['tripReportProcessing'] == true;
  String get statusLabel => status == 'PENDING'
      ? 'Chờ xử lý'
      : status == 'RESOLVED'
      ? 'Đã xử lý'
      : notes?.startsWith('[Chưa đủ bằng chứng]') == true
      ? 'Chưa đủ bằng chứng'
      : 'Bác bỏ';
}

class LibraryPlan {
  LibraryPlan(Map<String, dynamic> data)
    : id = '${data['id']}',
      name = data['name'] ?? '',
      destination = data['destination'] ?? '',
      durationDays = (data['durationDays'] as num?)?.toInt() ?? 1,
      budget = num.tryParse('${data['estimatedBudget']}')?.toInt() ?? 0,
      description = data['description'] ?? '',
      cover = data['coverImageUrl'],
      active = data['isActive'] != false,
      community = data['source'] == 'COMMUNITY',
      usage = (data['usageCount'] as num?)?.toInt() ?? 0,
      rating = num.tryParse('${data['averageRating']}')?.toDouble() ?? 0,
      reviews = (data['reviewCount'] as num?)?.toInt() ?? 0,
      version = data['version'] ?? '',
      sourceTripId = data['sourceTripId'],
      days = (data['days'] as List? ?? [])
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
  final String id, name, destination, description, version;
  final String? cover, sourceTripId;
  final int durationDays, budget, usage, reviews;
  final double rating;
  final bool active, community;
  final List<Map<String, dynamic>> days;
}
