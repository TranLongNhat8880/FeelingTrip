class TripMember {
  const TripMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.membershipStatus,
    this.avatarUrl,
    this.joinedAt,
    this.leftAt,
    this.removedAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final String membershipStatus;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final DateTime? removedAt;

  bool get isLeader => role == 'LEADER';

  factory TripMember.fromJson(Map<String, dynamic> json) => TripMember(
    userId: '${json['userId'] ?? ''}',
    displayName: '${json['displayName'] ?? 'Thành viên'}',
    avatarUrl: _string(json['avatarUrl']),
    role: '${json['role'] ?? 'MEMBER'}'.toUpperCase(),
    membershipStatus: '${json['membershipStatus'] ?? 'ACTIVE'}'.toUpperCase(),
    joinedAt: _date(json['joinedAt']),
    leftAt: _date(json['leftAt']),
    removedAt: _date(json['removedAt']),
  );
}

class TripModel {
  const TripModel({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.estimatedBudget,
    required this.privacyType,
    required this.status,
    this.durationDays,
    this.coverImageUrl,
    this.description,
    this.memberRole = 'MEMBER',
    this.membershipStatus = 'ACTIVE',
    this.memberCount = 1,
    this.isClone = false,
    this.originalTripId,
    this.cloneCount = 0,
    this.createdAt,
    this.updatedAt,
    this.members = const [],
    this.inviteCode,
    this.inviteCodeStatus,
    this.destinationProvider,
    this.destinationExternalId,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  final String id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int? durationDays;
  final int estimatedBudget;
  final String? coverImageUrl;
  final String? description;
  final String privacyType;
  final String status;
  final String memberRole;
  final String membershipStatus;
  final int memberCount;
  final bool isClone;
  final String? originalTripId;
  final int cloneCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<TripMember> members;
  final String? inviteCode;
  final String? inviteCodeStatus;
  final String? destinationProvider;
  final String? destinationExternalId;
  final double? destinationLatitude;
  final double? destinationLongitude;

  bool get isLeader => memberRole == 'LEADER';
  bool get isEditable => isLeader && ['UPCOMING', 'ONGOING'].contains(status);
  bool get isPublic => privacyType == 'PUBLIC';
  int get totalDays => durationDays ?? endDate.difference(startDate).inDays + 1;

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final members = _mapList(json['members']).map(TripMember.fromJson).toList();
    return TripModel(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Chuyến đi'}',
      destination: '${json['destination'] ?? ''}',
      startDate: _date(json['startDate']) ?? DateTime.now(),
      endDate: _date(json['endDate']) ?? DateTime.now(),
      durationDays: json['durationDays'] == null
          ? null
          : _integer(json['durationDays']),
      estimatedBudget: _integer(json['estimatedBudget']),
      coverImageUrl: _string(json['coverImageUrl']),
      description: _string(json['description']),
      privacyType: '${json['privacyType'] ?? 'PRIVATE'}'.toUpperCase(),
      status: '${json['status'] ?? 'UPCOMING'}'.toUpperCase(),
      memberRole: '${json['memberRole'] ?? 'MEMBER'}'.toUpperCase(),
      membershipStatus: '${json['membershipStatus'] ?? 'ACTIVE'}'.toUpperCase(),
      memberCount: json['memberCount'] == null
          ? members.length
          : _integer(json['memberCount']),
      isClone: json['isClone'] == true,
      originalTripId: _string(json['originalTripId']),
      cloneCount: _integer(json['cloneCount']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      members: members,
      inviteCode: _string(json['inviteCode']),
      inviteCodeStatus: _string(json['inviteCodeStatus']),
      destinationProvider: _string(json['destinationProvider']),
      destinationExternalId: _string(json['destinationExternalId']),
      destinationLatitude: json['destinationLatitude'] == null
          ? null
          : _double(json['destinationLatitude']),
      destinationLongitude: json['destinationLongitude'] == null
          ? null
          : _double(json['destinationLongitude']),
    );
  }
}

class TripFormData {
  const TripFormData({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.estimatedBudget,
    required this.privacyType,
    this.name,
    this.description,
    this.coverImageUrl,
    this.coverImageBytes,
    this.coverImageFileName,
    this.destinationProvider,
    this.destinationExternalId,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  final String? name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int estimatedBudget;
  final String privacyType;
  final String? description;
  final String? coverImageUrl;
  final List<int>? coverImageBytes;
  final String? coverImageFileName;
  final String? destinationProvider;
  final String? destinationExternalId;
  final double? destinationLatitude;
  final double? destinationLongitude;

  Map<String, dynamic> toJson() => {
    if (name?.trim().isNotEmpty == true) 'name': name!.trim(),
    'destination': destination.trim(),
    'startDate': _apiDate(startDate),
    'endDate': _apiDate(endDate),
    'estimatedBudget': estimatedBudget,
    'privacyType': privacyType,
    'description': description?.trim(),
    'coverImageUrl': coverImageUrl?.trim(),
    'destinationProvider': ?destinationProvider,
    'destinationExternalId': ?destinationExternalId,
    'destinationLatitude': ?destinationLatitude,
    'destinationLongitude': ?destinationLongitude,
  };

  Map<String, String> toMultipartFields({String? expectedUpdatedAt}) => {
    if (name?.trim().isNotEmpty == true) 'name': name!.trim(),
    'destination': destination.trim(),
    'startDate': _apiDate(startDate),
    'endDate': _apiDate(endDate),
    'estimatedBudget': '$estimatedBudget',
    'privacyType': privacyType,
    if (description != null) 'description': description!.trim(),
    if (coverImageUrl != null) 'coverImageUrl': coverImageUrl!.trim(),
    'destinationProvider': ?destinationProvider,
    'destinationExternalId': ?destinationExternalId,
    if (destinationLatitude != null)
      'destinationLatitude': '$destinationLatitude',
    if (destinationLongitude != null)
      'destinationLongitude': '$destinationLongitude',
    'expectedUpdatedAt': ?expectedUpdatedAt,
  };
}

class TripPage {
  const TripPage({required this.items, required this.total});
  final List<TripModel> items;
  final int total;

  factory TripPage.fromJson(Map<String, dynamic> json) {
    final items = _mapList(json['items']).map(TripModel.fromJson).toList();
    final pagination = json['pagination'];
    return TripPage(
      items: items,
      total: pagination is Map ? _integer(pagination['total']) : items.length,
    );
  }
}

class TripInvitation {
  const TripInvitation({
    required this.id,
    required this.tripId,
    required this.tripName,
    required this.destination,
    required this.inviterName,
    required this.status,
    this.inviterAvatarUrl,
    this.inviteeUserId,
    this.inviteeName,
    this.inviteeAvatarUrl,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String tripId;
  final String tripName;
  final String destination;
  final String inviterName;
  final String? inviterAvatarUrl;
  final String? inviteeUserId;
  final String? inviteeName;
  final String? inviteeAvatarUrl;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory TripInvitation.fromJson(Map<String, dynamic> json) {
    final trip = _map(json['trip']);
    final inviter = _map(json['inviter']);
    final invitee = _map(json['invitee']);
    return TripInvitation(
      id: '${json['id'] ?? ''}',
      tripId: '${trip['id'] ?? ''}',
      tripName: '${trip['name'] ?? 'Chuyến đi'}',
      destination: '${trip['destination'] ?? ''}',
      inviterName: '${inviter['displayName'] ?? 'Thành viên'}',
      inviterAvatarUrl: _string(inviter['avatarUrl']),
      inviteeUserId: _string(invitee['userId']),
      inviteeName: _string(invitee['displayName']),
      inviteeAvatarUrl: _string(invitee['avatarUrl']),
      status: '${json['status'] ?? 'PENDING'}'.toUpperCase(),
      expiresAt: _date(json['expiresAt']),
      createdAt: _date(json['createdAt']),
    );
  }
}

String _apiDate(DateTime value) => value.toIso8601String().split('T').first;

String? _string(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return null;
  return '$value';
}

DateTime? _date(dynamic value) {
  if (value == null || '$value'.isEmpty) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

int _integer(dynamic value) {
  if (value is num) return value.round();
  return num.tryParse('$value')?.round() ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];
