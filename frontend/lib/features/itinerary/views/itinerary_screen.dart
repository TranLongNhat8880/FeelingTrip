import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../../../routes/app_routes.dart';
import '../models/itinerary_model.dart';
import '../repositories/itinerary_repository.dart';
import '../viewmodels/itinerary_viewmodel.dart';
import 'itinerary_item_form_screen.dart';
import 'public_itineraries_screen.dart';
import 'widgets/itinerary_widgets.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({
    super.key,
    required this.tripId,
    required this.destination,
    this.repository,
  });

  final String tripId;
  final String destination;
  final ItineraryRepository? repository;

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  late final ItineraryViewModel _viewModel;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = ItineraryViewModel(repository: widget.repository);
    _viewModel.addListener(_onChanged);
    _viewModel.load(widget.tripId);
  }

  void _onChanged() {
    if (!mounted) return;
    final count = _viewModel.plan?.days.length ?? 0;
    if (count > 0 && _selectedDay >= count) _selectedDay = count - 1;
    setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openItemForm(ItineraryDay day, {ItineraryItem? item}) async {
    if (item != null && item.isCompleted) {
      AppFeedback.show(
        context,
        'Không thể chỉnh sửa điểm dừng đã hoàn thành. Vui lòng bỏ hoàn thành trước.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    if (item == null) KoharuScope.maybeOf(context)?.tapped('itinerary.add');
    final result = await Navigator.push<ItineraryItemDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryItemFormScreen(
          repository: _viewModel.repository,
          destination: widget.destination,
          position: item == null ? day.items.length : day.items.indexOf(item),
          item: item,
          previousItem: item == null && day.items.isNotEmpty
              ? day.items.last
              : null,
          suggestedStartTime: day.items.isEmpty ? null : day.items.last.endTime,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final success = item == null
        ? await _viewModel.addItem(day, result)
        : await _viewModel.updateItem(item, result);
    if (!mounted) return;
    if (success && item == null) KoharuScope.maybeOf(context)?.complete('itinerary.save');
    AppFeedback.show(
      context,
      success
          ? item == null
              ? 'Đã thêm điểm dừng vào lịch trình.'
              : 'Đã cập nhật điểm dừng.'
          : _viewModel.errorMessage ?? 'Không lưu được điểm dừng.',
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  Future<void> _editDayTitle(ItineraryDay day) async {
    final controller = TextEditingController(text: day.title);
    final title = await AppBottomSheet.show<String>(
      context,
      title: 'Tên ngày ${day.dayNumber}',
      child: Column(
        children: [
          CustomTextField(
            label: 'Tiêu đề ngày',
            hint: 'Ví dụ: Khám phá trung tâm, Check-in biển...',
            controller: controller,
            inputFormatters: [LengthLimitingTextInputFormatter(255)],
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Lưu tiêu đề',
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty && value.length <= 255) {
                Navigator.pop(context, value);
              }
            },
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) return;
    final success = await _viewModel.updateDayTitle(day, title);
    if (!mounted || success) return;
    AppFeedback.show(
      context,
      _viewModel.errorMessage ?? 'Không đổi được tiêu đề ngày.',
      tone: AppStatusTone.error,
    );
  }

  Future<void> _moveItem(ItineraryDay day, int oldIndex, int newIndex) async {
    if (_viewModel.isSubmitting || oldIndex == newIndex) return;
    final success = await _viewModel.moveItem(day, oldIndex, newIndex);
    if (!mounted) return;
    AppFeedback.show(
      context,
      success
          ? 'Đã hoán đổi vị trí và khung giờ hoạt động.'
          : _viewModel.errorMessage ?? 'Không sắp xếp lại được lịch trình.',
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  void _onReorder(ItineraryDay day, int oldIndex, int newIndex) {
    _moveItem(day, oldIndex, newIndex);
  }

  Widget _timelineItem(
    ItineraryDay day,
    int index, {
    required bool canEdit,
    required bool draggable,
  }) {
    final item = day.items[index];
    return Column(
      key: ValueKey('itinerary-item-${item.id}'),
      children: [
        ItineraryItemCard(
          item: item,
          position: index,
          canEdit: canEdit,
          onToggle: () => _viewModel.toggleCompletion(item),
          onEdit: () => _openItemForm(day, item: item),
          onDelete: () => _deleteItem(item),
          onMoveUp: index == 0 ||
                  _viewModel.isSubmitting ||
                  item.isCompleted ||
                  (index > 0 && day.items[index - 1].isCompleted)
              ? null
              : () => _moveItem(day, index, index - 1),
          onMoveDown: index == day.items.length - 1 ||
                  _viewModel.isSubmitting ||
                  item.isCompleted ||
                  (index < day.items.length - 1 &&
                      day.items[index + 1].isCompleted)
              ? null
              : () => _moveItem(day, index, index + 1),
          onSmartSwap:
              item.supportsSmartSwap && !item.isCompleted ? () => _smartSwap(item) : null,
          onRecordExpense: () async {
            await Navigator.pushNamed(
              context,
              AppRoutes.expenses,
              arguments: {'tripId': widget.tripId, 'itineraryItemId': item.id},
            );
            if (mounted) await _viewModel.load(widget.tripId);
          },
          reorderHandle: draggable && !item.isCompleted
              ? ReorderableDragStartListener(
                  index: index,
                  enabled: !_viewModel.isSubmitting,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                )
              : null,
        ),
        if (index < day.items.length - 1)
          ItineraryLegIndicator(
            origin: item,
            destination: day.items[index + 1],
          ),
      ],
    );
  }

  Widget _timeline(ItineraryDay day, {required bool canEdit}) {
    final draggable = canEdit && day.items.length > 1;
    if (!draggable) {
      return Column(
        children: [
          for (var index = 0; index < day.items.length; index++)
            _timelineItem(day, index, canEdit: canEdit, draggable: false),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kéo biểu tượng :: để sắp xếp lại lộ trình hoặc dùng mũi tên.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: day.items.length,
          onReorderItem: _viewModel.isSubmitting
              ? (_, _) {}
              : (oldIndex, newIndex) => _onReorder(day, oldIndex, newIndex),
          itemBuilder: (_, index) =>
              _timelineItem(day, index, canEdit: canEdit, draggable: true),
        ),
      ],
    );
  }

  Future<void> _deleteItem(ItineraryItem item) async {
    if (item.isCompleted) {
      AppFeedback.show(
        context,
        'Không thể xóa điểm dừng đã hoàn thành. Vui lòng bỏ hoàn thành trước.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Xóa ${item.customName}?',
      message: 'Điểm dừng sẽ bị xóa khỏi ngày này.',
      confirmLabel: 'Xóa điểm dừng',
      destructive: true,
    );
    if (!confirmed) return;
    final success = await _viewModel.deleteItem(item);
    if (!mounted) return;
    AppFeedback.show(
      context,
      success ? 'Đã xóa điểm dừng.' : _viewModel.errorMessage!,
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  Future<void> _smartSwap(ItineraryItem item) async {
    if (item.isCompleted) {
      AppFeedback.show(
        context,
        'Không thể đổi điểm dừng đã hoàn thành. Vui lòng bỏ hoàn thành trước.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    final candidates = await _viewModel.getSwapCandidates(item);
    if (!mounted) return;
    if (candidates == null) {
      AppFeedback.show(
        context,
        _viewModel.errorMessage ?? 'Không lấy được địa điểm thay thế.',
        tone: AppStatusTone.error,
      );
      return;
    }
    if (candidates.isEmpty) {
      AppFeedback.show(
        context,
        'Chưa có địa điểm thay thế phù hợp trong bán kính 3 km.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    final selected = await AppBottomSheet.show<SwapCandidate>(
      context,
      title: 'Đổi ${item.customName}',
      child: Column(
        children: [
          const AppInlineNotice(
            message:
                'Các gợi ý cùng loại được xếp theo mức phù hợp với tuyến hiện tại.',
          ),
          const SizedBox(height: 14),
          for (final candidate in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                outlined: true,
                onTap: () => Navigator.pop(context, candidate),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (candidate.address != null) ...[
                      const SizedBox(height: 4),
                      Text(candidate.address!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '★ ${candidate.rating.toStringAsFixed(1)} · cách điểm cũ ${candidate.distanceFromOriginalKm.toStringAsFixed(1)} km · lệch tuyến ${candidate.routeDeltaKm.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final success = await _viewModel.applySmartSwap(item, selected);
    if (!mounted) return;
    AppFeedback.show(
      context,
      success ? 'Đã đổi sang ${selected.name}.' : _viewModel.errorMessage!,
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _viewModel.plan;
    return AppScaffold(
      title: 'Lịch trình chuyến đi',
      actions: [
        if (plan != null && plan.trip.canEdit && plan.days.isNotEmpty)
          IconButton(
            tooltip: 'Thêm điểm dừng',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _viewModel.isSubmitting ? null : () => _openItemForm(plan.days[_selectedDay]),
          ).koharu('itinerary.add', enabled: !_viewModel.isSubmitting),
        IconButton(
          tooltip: 'Kho lịch trình mẫu',
          icon: const Icon(Icons.auto_awesome_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicItinerariesScreen(
                repository: _viewModel.repository,
                initialDestination: widget.destination,
              ),
            ),
          ),
        ),
      ],
      padding: EdgeInsets.zero,
      body: _body(plan),
    );
  }

  Widget _body(ItineraryPlan? plan) {
    if (_viewModel.isLoading && plan == null) {
      return const LoadingIndicator(message: 'Đang tải lịch trình...');
    }
    if (plan == null) {
      return ErrorState(
        message: _viewModel.errorMessage ?? 'Không tìm thấy lịch trình.',
        onRetry: () => _viewModel.load(widget.tripId),
      );
    }
    if (plan.days.isEmpty) {
      return ErrorState(
        message: 'Chuyến đi chưa có dữ liệu ngày hợp lệ.',
        onRetry: () => _viewModel.load(widget.tripId),
      );
    }

    final day = plan.days[_selectedDay];
    final completedCount = day.items.where((i) => i.isCompleted).length;
    final progressRatio =
        day.items.isEmpty ? 0.0 : (completedCount / day.items.length);

    return RefreshIndicator(
      onRefresh: () => _viewModel.load(widget.tripId),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ─── HERO TRIP HEADER ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0077E6), Color(0xFF0055C4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            widget.destination.isNotEmpty
                                ? widget.destination
                                : 'Điểm đến',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        plan.trip.status == 'ONGOING'
                            ? 'Đang diễn ra'
                            : 'Sắp diễn ra',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan.trip.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppUtils.formatDate(plan.trip.startDate)} – ${AppUtils.formatDate(plan.trip.endDate)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                // Trip metrics row
                Row(
                  children: [
                    _heroStat(
                      icon: Icons.calendar_month_rounded,
                      label: 'Lộ trình',
                      value: '${plan.days.length} ngày',
                    ),
                    const SizedBox(width: 10),
                    _heroStat(
                      icon: Icons.tour_rounded,
                      label: 'Hôm nay',
                      value: '${day.items.length} điểm',
                    ),
                    const SizedBox(width: 10),
                    _heroStat(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Dự toán',
                      value: AppUtils.formatCurrency(day.estimatedCost),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── DAY SELECTOR CAROUSEL ────────────────────────────────────────
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2),
              itemCount: plan.days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final d = plan.days[index];
                return DaySelectorCard(
                  dayNumber: d.dayNumber,
                  date: d.tripDate,
                  itemCount: d.items.length,
                  isSelected: _selectedDay == index,
                  onTap: () => setState(() => _selectedDay = index),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ─── DAY HEADER & PROGRESS ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                day.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (plan.trip.canEdit) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _viewModel.isSubmitting
                                      ? null
                                      : () => _editDayTitle(day),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppUtils.formatDate(day.tripDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (day.items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: progressRatio >= 1.0
                              ? AppColors.successSurface
                              : AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          progressRatio >= 1.0
                              ? 'Hoàn thành'
                              : '$completedCount/${day.items.length} đã xong',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: progressRatio >= 1.0
                                ? AppColors.success
                                : AppColors.primaryDark,
                          ),
                        ),
                      )
                    else if (plan.trip.canEdit)
                      InkWell(
                        onTap: () => _openItemForm(day),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 15, color: AppColors.primaryDark),
                              SizedBox(width: 4),
                              Text(
                                'Thêm điểm',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (day.items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progressRatio >= 1.0
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── TIMELINE LIST OR EMPTY STATE ─────────────────────────────────
          if (day.items.isEmpty)
            EmptyStateWidget(
              icon: Icons.alt_route_rounded,
              title: 'Chưa có điểm dừng nào',
              message:
                  'Bắt đầu ngày bằng việc thêm điểm xuất phát đầu tiên, sau đó nối dài lộ trình.',
              buttonText: plan.trip.canEdit ? 'Thêm điểm bắt đầu' : null,
              onButtonPressed:
                  plan.trip.canEdit ? () => _openItemForm(day) : null,
            )
          else ...[
            _timeline(day, canEdit: plan.trip.canEdit),
            if (plan.trip.canEdit) ...[
              const SizedBox(height: 10),
              CustomButton(
                text: 'Thêm điểm tiếp theo',
                icon: Icons.add_location_alt_rounded,
                isLoading: _viewModel.isSubmitting,
                onPressed: _viewModel.isSubmitting
                    ? null
                    : () => _openItemForm(day),
              ),
            ],
          ],

          if (day.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tổng chi phí dự toán trong ngày: ${AppUtils.formatCurrency(day.estimatedCost)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
