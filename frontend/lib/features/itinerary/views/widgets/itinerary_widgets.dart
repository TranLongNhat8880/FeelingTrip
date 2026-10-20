import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../map/models/place_distance_model.dart';
import '../../../map/repositories/api_place_repository.dart';
import '../../../../shared/ui_kit.dart';
import '../../models/itinerary_model.dart';

// ============================================================================
// HELPER: Category Visuals
// ============================================================================

IconData getCategoryIcon(String category) {
  switch (category.toUpperCase()) {
    case 'ATTRACTION':
      return Icons.attractions_rounded;
    case 'RESTAURANT':
      return Icons.restaurant_rounded;
    case 'CAFE':
      return Icons.local_cafe_rounded;
    case 'HOTEL':
      return Icons.hotel_rounded;
    case 'ENTERTAINMENT':
      return Icons.celebration_rounded;
    case 'NATURE':
      return Icons.park_rounded;
    case 'CULTURE':
      return Icons.museum_rounded;
    case 'SHOPPING':
      return Icons.shopping_bag_rounded;
    default:
      return Icons.place_rounded;
  }
}

Color getCategoryColor(String category) {
  switch (category.toUpperCase()) {
    case 'ATTRACTION':
      return const Color(0xFF0077E6);
    case 'RESTAURANT':
      return const Color(0xFFFF6B35);
    case 'CAFE':
      return const Color(0xFF8B5E3C);
    case 'HOTEL':
      return const Color(0xFF7209B7);
    case 'ENTERTAINMENT':
      return const Color(0xFFE63946);
    case 'NATURE':
      return const Color(0xFF2A9D8F);
    case 'CULTURE':
      return const Color(0xFFD4A373);
    case 'SHOPPING':
      return const Color(0xFFF77F00);
    default:
      return const Color(0xFF457B9D);
  }
}

// ============================================================================
// COMPONENT: Day Selector Mini Card
// ============================================================================

class DaySelectorCard extends StatelessWidget {
  const DaySelectorCard({
    super.key,
    required this.dayNumber,
    required this.date,
    required this.itemCount,
    required this.isSelected,
    required this.onTap,
  });

  final int dayNumber;
  final DateTime date;
  final int itemCount;
  final bool isSelected;
  final VoidCallback onTap;

  static const _weekdayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdayNames[(date.weekday - 1) % 7];
    final dayMonth = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF0077E6), Color(0xFF0055C4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.transparent : AppColors.border,
          width: 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NGÀY $dayNumber',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isSelected ? Colors.white70 : AppColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        weekday,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  dayMonth,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 11,
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$itemCount điểm',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Itinerary Leg Indicator (Chặng di chuyển)
// ============================================================================

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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector (dashed or styled vertical line)
          SizedBox(
            width: 36,
            child: Center(
              child: Container(
                width: 2,
                color: AppColors.primaryBorder.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Leg pill
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: _loading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Đang tính chặng...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        )
                      : _distance != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_car_rounded,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_distance!.distanceKm.toStringAsFixed(1)} km · '
                                  '${_distance!.estimatedDurationMinutes} phút di chuyển',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (_distance!.directionsUri != null) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: _openDirections,
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.map_rounded,
                                            size: 13,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            'Chỉ đường',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: AppColors.textHint,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Điểm tiếp theo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Itinerary Item Card (Điểm dừng trong ngày)
// ============================================================================

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
    this.reorderHandle,
    this.onRecordExpense,
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
  final Widget? reorderHandle;
  final VoidCallback? onRecordExpense;

  String _formatDuration(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMins = (int.tryParse(startParts[0]) ?? 0) * 60 +
        (startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0);
    final endMins = (int.tryParse(endParts[0]) ?? 0) * 60 +
        (endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0);
    final diff = endMins - startMins;
    if (diff <= 0) return '';
    final h = diff ~/ 60;
    final m = diff % 60;
    if (h > 0 && m > 0) return '$h giờ $m phút';
    if (h > 0) return '$h giờ';
    return '$m phút';
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = getCategoryColor(item.category);
    final categoryIcon = getCategoryIcon(item.category);
    final durationText = _formatDuration(item.startTime, item.endTime);

    return Stack(
      children: [
        // Connector vertical line stretching to bottom of card
        Positioned(
          left: 17,
          top: 34,
          bottom: 0,
          child: Container(
            width: 2,
            color: AppColors.primaryBorder.withValues(alpha: 0.8),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Column
            SizedBox(
              width: 36,
              child: Center(
                child: InkWell(
                  onTap: canEdit ? onToggle : null,
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.isCompleted
                          ? AppColors.success
                          : categoryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: (item.isCompleted ? AppColors.success : categoryColor)
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: item.isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : Text(
                              '${position + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                outlined: true,
                padding: const EdgeInsets.all(14),
                color: item.isCompleted
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.white,
                softShadow: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: badge + title + actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order & status tag
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: position == 0
                                          ? AppColors.primarySurface
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          position == 0
                                              ? Icons.flag_rounded
                                              : Icons.place_rounded,
                                          size: 12,
                                          color: position == 0
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          position == 0
                                              ? 'Điểm xuất phát'
                                              : 'Điểm #${position + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: position == 0
                                                ? AppColors.primaryDark
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item.isCompleted) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.successSurface,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_rounded, size: 10, color: AppColors.success),
                                          SizedBox(width: 3),
                                          Text(
                                            'Đã hoàn thành',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (item.locationSource == 'GEOAPIFY') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.map_rounded,
                                              size: 11,
                                              color: Color(0xFF2563EB)),
                                          SizedBox(width: 3),
                                          Text(
                                            'Bản đồ',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (item.locationSource == 'MANUAL') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_note_rounded,
                                              size: 11,
                                              color: AppColors.textSecondary),
                                          SizedBox(width: 3),
                                          Text(
                                            'Tự nhập',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              // Custom name
                              Text(
                                item.customName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: item.isCompleted
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                      decoration: item.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (reorderHandle != null) ...[
                          reorderHandle!,
                          const SizedBox(width: 2),
                        ],
                        if (canEdit)
                          PopupMenuButton<String>(
                            tooltip: 'Tùy chọn',
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'toggle':
                                  onToggle();
                                case 'edit':
                                  onEdit();
                                case 'swap':
                                  onSmartSwap?.call();
                                case 'delete':
                                  onDelete();
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      item.isCompleted
                                          ? Icons.undo_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: item.isCompleted
                                          ? AppColors.warning
                                          : AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(item.isCompleted
                                        ? 'Bỏ hoàn thành (để chỉnh sửa)'
                                        : 'Đánh dấu đã đến'),
                                  ],
                                ),
                              ),
                              if (!item.isCompleted) ...[
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          size: 18, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text('Chỉnh sửa thông tin'),
                                    ],
                                  ),
                                ),
                                if (onSmartSwap != null)
                                  const PopupMenuItem(
                                    value: 'swap',
                                    child: Row(
                                      children: [
                                        Icon(Icons.auto_awesome_rounded,
                                            size: 18,
                                            color: Color(0xFFF77F00)),
                                        SizedBox(width: 8),
                                        Text('Đổi điểm AI thông minh'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded,
                                          size: 18, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text('Xóa điểm dừng',
                                          style:
                                              TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Detail pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Time & duration pill
                        _DetailPill(
                          icon: Icons.schedule_rounded,
                          text: durationText.isNotEmpty
                              ? '${item.startTime} – ${item.endTime} ($durationText)'
                              : '${item.startTime} – ${item.endTime}',
                          color: AppColors.primaryDark,
                          backgroundColor: AppColors.primarySurface,
                        ),
                        // Category pill with unique icon & color
                        _DetailPill(
                          icon: categoryIcon,
                          text: categoryLabel(item.category),
                          color: categoryColor,
                          backgroundColor:
                              categoryColor.withValues(alpha: 0.12),
                        ),
                        // Cost pill (if any)
                        if (item.estimatedCost > 0)
                          _DetailPill(
                            icon: Icons.payments_rounded,
                            text: 'Dự kiến ${AppUtils.formatCurrency(item.estimatedCost)}',
                            color: const Color(0xFF008B57),
                            backgroundColor: const Color(0xFFE8F5E9),
                          ),
                      ],
                    ),
                    if (onRecordExpense != null) ...[
                      const SizedBox(height: 8),
                      if (item.expenseId != null)
                        AppStatusBadge(
                          label:
                              'Đã ghi khoản chi ${AppUtils.formatCurrency(item.actualAmount ?? 0)}',
                          tone: AppStatusTone.success,
                        ),
                      CustomButton(
                        text: item.expenseId == null
                            ? 'Ghi nhận khoản chi'
                            : 'Xem khoản đã chi',
                        variant: AppButtonVariant.text,
                        fullWidth: false,
                        onPressed: onRecordExpense,
                      ),
                    ],
                    // Address row (if any)
                    if (item.customAddress != null &&
                        item.customAddress!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.customAddress!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Note box (if any)
                    if (item.note != null &&
                        item.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFFECC4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 14,
                              color: Color(0xFF946000),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.note!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78350F),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Bottom Quick Action Bar
                    if (canEdit) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Fast Toggle Checkbox Button
                          InkWell(
                            onTap: onToggle,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: item.isCompleted
                                    ? AppColors.successSurface
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: item.isCompleted
                                      ? AppColors.success
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 15,
                                    color: item.isCompleted
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    item.isCompleted
                                        ? 'Đã xong'
                                        : 'Chưa xong',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: item.isCompleted
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Smart swap button
                          if (item.supportsSmartSwap && onSmartSwap != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: onSmartSwap,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFFFEDD5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 13,
                                      color: Color(0xFFEA580C),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Đổi điểm AI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFEA580C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Reorder arrows
                          if (onMoveUp != null)
                            IconButton(
                              tooltip: 'Lên trước',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                              onPressed: onMoveUp,
                              icon: const Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (onMoveDown != null)
                            IconButton(
                              tooltip: 'Xuống sau',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                              onPressed: onMoveDown,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  }
}

// ============================================================================
// COMPONENT: Detail Pill
// ============================================================================

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
}
