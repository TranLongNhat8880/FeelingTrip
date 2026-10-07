import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
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
    _viewModel = ItineraryViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..load(widget.tripId);
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
    final result = await Navigator.push<ItineraryItemDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryItemFormScreen(
          repository: _viewModel.repository,
          destination: widget.destination,
          position: item == null ? day.items.length : day.items.indexOf(item),
          item: item,
          suggestedStartTime: day.items.isEmpty ? null : day.items.last.endTime,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final success = item == null
        ? await _viewModel.addItem(day, result)
        : await _viewModel.updateItem(item, result);
    if (!mounted) return;
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
            label: 'Tiêu đề',
            hint: 'Ví dụ: Khám phá trung tâm',
            controller: controller,
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Lưu tiêu đề',
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
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

  Future<void> _deleteItem(ItineraryItem item) async {
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
      title: 'Lịch trình',
      actions: [
        IconButton(
          tooltip: 'Kho lịch trình cộng đồng',
          icon: const Icon(Icons.auto_awesome_outlined),
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
    final day = plan.days[_selectedDay];
    return RefreshIndicator(
      onRefresh: () => _viewModel.load(widget.tripId),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          AppCard(
            color: AppColors.primarySurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.trip.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '$widget.destination · ${AppUtils.formatDate(plan.trip.startDate)} – ${AppUtils.formatDate(plan.trip.endDate)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: plan.days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ChoiceChip(
                selected: _selectedDay == index,
                label: Text('Ngày ${plan.days[index].dayNumber}'),
                onSelected: (_) => setState(() => _selectedDay = index),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppUtils.formatDate(day.tripDate),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.trip.canEdit)
                IconButton(
                  tooltip: 'Đổi tên ngày',
                  onPressed: _viewModel.isSubmitting
                      ? null
                      : () => _editDayTitle(day),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (day.items.isEmpty)
            EmptyStateWidget(
              icon: Icons.route_outlined,
              title: 'Chưa có điểm dừng',
              message:
                  'Thêm điểm bắt đầu, sau đó thêm các điểm tiếp theo cùng giờ cụ thể.',
              buttonText: plan.trip.canEdit ? 'Thêm điểm bắt đầu' : null,
              onButtonPressed: plan.trip.canEdit
                  ? () => _openItemForm(day)
                  : null,
            )
          else ...[
            for (var index = 0; index < day.items.length; index++)
              ItineraryItemCard(
                item: day.items[index],
                position: index,
                canEdit: plan.trip.canEdit,
                onToggle: () => _viewModel.toggleCompletion(day.items[index]),
                onEdit: () => _openItemForm(day, item: day.items[index]),
                onDelete: () => _deleteItem(day.items[index]),
                onMoveUp: index == 0 || _viewModel.isSubmitting
                    ? null
                    : () => _viewModel.moveItem(day, index, index - 1),
                onMoveDown:
                    index == day.items.length - 1 || _viewModel.isSubmitting
                    ? null
                    : () => _viewModel.moveItem(day, index, index + 1),
                onSmartSwap: day.items[index].supportsSmartSwap
                    ? () => _smartSwap(day.items[index])
                    : null,
              ),
            if (plan.trip.canEdit) ...[
              const SizedBox(height: 4),
              CustomButton(
                text: 'Thêm điểm tiếp theo',
                icon: Icons.add_location_alt_outlined,
                isLoading: _viewModel.isSubmitting,
                onPressed: _viewModel.isSubmitting
                    ? null
                    : () => _openItemForm(day),
              ),
            ],
          ],
          if (day.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            AppInlineNotice(
              message:
                  'Tổng dự kiến trong ngày: ${AppUtils.formatCurrency(day.estimatedCost)}. Các khung giờ không được chồng lấn.',
            ),
          ],
        ],
      ),
    );
  }
}
