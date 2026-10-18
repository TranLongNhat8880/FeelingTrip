class TripReportAction {
  const TripReportAction({
    required this.type,
    required this.targetId,
    required this.label,
  });
  final String type, targetId, label;
  Map<String, String> toJson() => {'type': type, 'targetId': targetId};
}

class TripReportResolution {
  TripReportResolution({
    required this.reason,
    required List<TripReportAction> actions,
  }) : actions = List.unmodifiable(actions);
  final String reason;
  final List<TripReportAction> actions;
}
