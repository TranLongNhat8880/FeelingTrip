class IdentitySession {
  const IdentitySession({
    required this.id,
    required this.actions,
    required this.expiresAt,
  });
  final String id;
  final List<String> actions;
  final DateTime expiresAt;
  factory IdentitySession.fromJson(Map<String, dynamic> json) {
    final actions = (json['actions'] as List).cast<String>();
    if (actions.length != 3 ||
        actions.toSet().length != 3 ||
        !actions.every(['blink', 'turnLeft', 'turnRight'].contains)) {
      throw const FormatException('Thao tác xác minh từ server không hợp lệ.');
    }
    final id = json['sessionId'] as String;
    final expires = DateTime.parse(json['expiresAt'] as String);
    if (id.isEmpty || !expires.isAfter(DateTime.now())) {
      throw const FormatException('Phiên xác minh đã hết hạn.');
    }
    return IdentitySession(
      id: id,
      actions: List.unmodifiable(actions),
      expiresAt: expires,
    );
  }
}
