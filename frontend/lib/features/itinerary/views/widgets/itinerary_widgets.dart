import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../map/models/place_distance_model.dart';
import '../../../map/repositories/api_place_repository.dart';
import '../../../../shared/ui_kit.dart';
import '../../models/itinerary_model.dart';

class ItineraryLegIndicator extends StatefulWidget {
  const ItineraryLegIndicator({
    super.key,
    required this.origin,
    required this.destination,
  });

  final ItineraryItem origin;
  final ItineraryItem destination;

  @override
  State<ItineraryLegIndicator> createState() => _ItineraryLegIndicatorState();
}

class _ItineraryLegIndicatorState extends State<ItineraryLegIndicator> {
  final ApiPlaceRepository _placeRepository = ApiPlaceRepository();
  PlaceDistanceResult? _distance;
  bool _loading = false;
  int _requestId = 0;

  bool get _hasCoordinates =>
      widget.origin.latitude != null &&
      widget.origin.longitude != null &&
      widget.destination.latitude != null &&
      widget.destination.longitude != null;

  @override
  void initState() {
    super.initState();
    _loadDistance();
  }

  @override
  void didUpdateWidget(covariant ItineraryLegIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_coordinateKey(oldWidget) != _coordinateKey(widget)) {
      _loadDistance();
    }
  }

  String _coordinateKey(ItineraryLegIndicator value) =>
      '${value.origin.latitude}:${value.origin.longitude}:'
      '${value.destination.latitude}:${value.destination.longitude}';

  Future<void> _loadDistance() async {
    final requestId = ++_requestId;
    if (!_hasCoordinates) {
      if (mounted) {
        setState(() {
          _distance = null;
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _distance = null;
    });
    try {
      final result = await _placeRepository.calculateDistance(
        originLatitude: widget.origin.latitude!,
        originLongitude: widget.origin.longitude!,
        destinationLatitude: widget.destination.latitude!,
        destinationLongitude: widget.destination.longitude!,
        travelMode: 'driving',
      );
      if (!mounted || requestId != _requestId) return;
      setState(() => _distance = result);
    } catch (_) {
      // Không làm hỏng timeline nếu API khoảng cách tạm thời không khả dụng.
      if (!mounted || requestId != _requestId) return;
      setState(() => _distance = null);
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openDirections() async {
    final uri = _distance?.directionsUri;
    if (uri == null) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      AppFeedback.show(
        context,
        'Không thể mở Google Maps.',
        tone: AppStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCoordinates || (!_loading && _distance == null)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(46, 2, 0, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: _loading
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Đang tính chặng di chuyển...'),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${_distance!.distanceKm.toStringAsFixed(1)} km · '
                      '${_distance!.estimatedDurationMinutes} phút',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_distance!.directionsUri != null)
                      IconButton(
                        tooltip: 'Mở chỉ đường Google Maps',
                        visualDensity: VisualDensity.compact,
                        onPressed: _openDirections,
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class ItineraryItemCard extends StatelessWidget {
  const ItineraryItemCard({
    super.key,
    required this.item,
    required this.position,
    required this.canEdit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSmartSwap,
  });

  final ItineraryItem item;
  final int position;
  final bool canEdit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onSmartSwap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: item.isCompleted
                ? AppColors.success
                : AppColors.primary,
            foregroundColor: Colors.white,
            child: item.isCompleted
                ? const Icon(Icons.check_rounded, size: 18)
                : Text('${position + 1}'),
          ),
          Container(width: 2, height: 118, color: AppColors.primaryBorder),
        ],
      ),
      const SizedBox(width: 12),
      Expanded(
        child: AppCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          position == 0 ? 'Điểm bắt đầu' : 'Điểm tiếp theo',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.customName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration: item.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn điểm dừng',
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit();
                          case 'swap':
                            onSmartSwap?.call();
                          case 'delete':
                            onDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Chỉnh sửa'),
                        ),
                        if (onSmartSwap != null)
                          const PopupMenuItem(
                            value: 'swap',
                            child: Text('Đổi địa điểm thông minh'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa điểm dừng'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: Icons.schedule_rounded,
                    text: '${item.startTime} – ${item.endTime}',
                  ),
                  _Pill(
                    icon: Icons.category_outlined,
                    text: categoryLabel(item.category),
                  ),
                  if (item.estimatedCost > 0)
                    _Pill(
                      icon: Icons.payments_outlined,
                      text: AppUtils.formatCurrency(item.estimatedCost),
                    ),
                ],
              ),
              if (item.customAddress != null) ...[
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.customAddress!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.note != null) ...[
                const SizedBox(height: 8),
                Text(item.note!, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (canEdit) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onToggle,
                        icon: Icon(
                          item.isCompleted
                              ? Icons.undo_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                        label: Text(
                          item.isCompleted ? 'Chưa xong' : 'Hoàn thành',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đưa lên trước',
                      onPressed: onMoveUp,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Đưa xuống sau',
                      onPressed: onMoveDown,
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
