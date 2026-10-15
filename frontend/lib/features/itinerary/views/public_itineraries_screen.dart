import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../models/itinerary_model.dart';
import '../repositories/itinerary_repository.dart';
import '../viewmodels/itinerary_viewmodel.dart';
import '../../admin/views/plan_library_screen.dart';
import 'itinerary_screen.dart';
import 'public_itinerary_search_screen.dart';

class PublicItinerariesScreen extends StatefulWidget {
  const PublicItinerariesScreen({
    super.key,
    this.repository,
    this.initialDestination,
    this.embedded = false,
    this.onMenuTap,
    this.onProfileTap,
  });

  final ItineraryRepository? repository;
  final String? initialDestination;
  final bool embedded;
  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;

  @override
  State<PublicItinerariesScreen> createState() =>
      _PublicItinerariesScreenState();
}

class _PublicItinerariesScreenState extends State<PublicItinerariesScreen> {
  late final PublicItineraryViewModel _viewModel;
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialDestination;
    _viewModel = PublicItineraryViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..load(destination: _activeFilter);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _viewModel.load(
        destination: _activeFilter,
      );

  void _clearFilter() {
    setState(() => _activeFilter = null);
    _viewModel.load();
  }

  Future<void> _openSearch() async {
    final query = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => PublicItinerarySearchScreen(
          repository: widget.repository,
          destinations: _viewModel.plans
              .map((p) => p.destination)
              .where((d) => d.isNotEmpty)
              .toSet()
              .toList(),
          initialQuery: _activeFilter,
        ),
      ),
    );
    if (query != null && query.trim().isNotEmpty && mounted) {
      setState(() => _activeFilter = query.trim());
      _viewModel.load(keyword: query.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter =
        _activeFilter != null && _activeFilter!.trim().isNotEmpty;
    final content = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        children: [
          Semantics(
            button: true,
            label: 'Tìm kiếm lịch trình cộng đồng',
            child: Material(
              color: AppColors.inputSurface,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _openSearch,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasActiveFilter
                              ? _activeFilter!
                              : 'Tìm kiếm lịch trình, điểm đến...',
                          style: TextStyle(
                            color: hasActiveFilter
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                            fontSize: 14,
                            fontWeight: hasActiveFilter
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasActiveFilter)
                        GestureDetector(
                          onTap: _clearFilter,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.cancel_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Xem lịch trình mẫu hệ thống',
            icon: Icons.route_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlanLibraryScreen()),
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Lịch trình cộng đồng',
            subtitle: hasActiveFilter
                ? '${_viewModel.plans.length} kết quả cho “$_activeFilter”'
                : '${_viewModel.plans.length} kết quả phù hợp',
          ),
          const SizedBox(height: 12),
          if (_viewModel.isLoading && _viewModel.plans.isEmpty)
            const LoadingIndicator(message: 'Đang tải lịch trình...')
          else if (_viewModel.errorMessage != null && _viewModel.plans.isEmpty)
            ErrorState(message: _viewModel.errorMessage!, onRetry: _refresh)
          else if (_viewModel.plans.isEmpty)
            EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'Chưa có lịch trình phù hợp',
              message: hasActiveFilter
                  ? 'Không tìm thấy lịch trình cho “$_activeFilter”. Thử thay đổi từ khóa.'
                  : 'Hiện chưa có lịch trình công khai nào.',
            )
          else
            for (final plan in _viewModel.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PublicPlanCard(
                  plan: plan,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicItineraryDetailScreen(
                        summary: plan,
                        repository: widget.repository,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );

    if (widget.embedded) {
      return TravelBackdrop(
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        if (widget.onMenuTap != null)
                          IconButton(
                            tooltip: 'Mở menu',
                            onPressed: widget.onMenuTap,
                            icon: const Icon(
                              Icons.menu_rounded,
                              size: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TravelBrand(width: 160),
                          ),
                        ),
                        if (widget.onProfileTap != null)
                          IconButton(
                            tooltip: 'Mở trang cá nhân',
                            onPressed: widget.onProfileTap,
                            icon: const Icon(
                              Icons.person_outline_rounded,
                              size: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      'Kho lịch trình',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Kho lịch trình',
      padding: EdgeInsets.zero,
      body: content,
    );
  }
}

class PublicPlanCard extends StatelessWidget {
  const PublicPlanCard({super.key, required this.plan, required this.onTap});

  final PublicItinerarySummary plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    outlined: true,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                plan.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              plan.destination,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '·  ${plan.durationDays} ngày',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        if (plan.description != null && plan.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            plan.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    plan.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  if (plan.reviewCount > 0)
                    Text(
                      ' (${plan.reviewCount})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fork_right_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${plan.cloneCount} lượt dùng',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class PublicItineraryDetailScreen extends StatefulWidget {
  const PublicItineraryDetailScreen({
    super.key,
    required this.summary,
    this.repository,
  });

  final PublicItinerarySummary summary;
  final ItineraryRepository? repository;

  @override
  State<PublicItineraryDetailScreen> createState() =>
      _PublicItineraryDetailScreenState();
}

class _PublicItineraryDetailScreenState
    extends State<PublicItineraryDetailScreen> {
  late final PublicItineraryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PublicItineraryViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..loadDetail(widget.summary.sourceTripId);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _clone() async {
    final name = TextEditingController(
      text: '${widget.summary.name} (Bản sao)',
    );
    var startDate = DateTime.now().add(const Duration(days: 7));
    final data = await AppBottomSheet.show<({String name, DateTime startDate})>(
      context,
      title: 'Sử dụng lịch trình này',
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            CustomTextField(
              label: 'Tên chuyến đi mới',
              controller: name,
              prefixIcon: Icons.luggage_outlined,
              inputFormatters: [LengthLimitingTextInputFormatter(255)],
            ),
            const SizedBox(height: 14),
            AppSelectionField(
              label: 'Ngày bắt đầu',
              value: AppUtils.formatDate(startDate),
              icon: Icons.calendar_month_outlined,
              onTap: () async {
                final value = await AppPickers.date(
                  context,
                  initial: startDate,
                  first: DateTime.now(),
                  last: DateTime.now().add(const Duration(days: 730)),
                );
                if (value != null) setSheetState(() => startDate = value);
              },
            ),
            const SizedBox(height: 18),
            CustomButton(
              text: 'Tạo bản sao',
              onPressed: () {
                final trimmedName = name.text.trim();
                if (trimmedName.length < 2) {
                  AppFeedback.show(
                    context,
                    'Tên chuyến đi cần ít nhất 2 ký tự.',
                    tone: AppStatusTone.warning,
                  );
                  return;
                }
                Navigator.pop(context, (
                  name: trimmedName,
                  startDate: startDate,
                ));
              },
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (data == null || !mounted) return;
    final cloned = await _viewModel.clone(
      sourceTripId: widget.summary.sourceTripId,
      startDate: data.startDate,
      name: data.name,
    );
    if (!mounted) return;
    if (cloned == null) {
      AppFeedback.show(
        context,
        _viewModel.errorMessage ?? 'Không thể nhân bản lịch trình.',
        tone: AppStatusTone.error,
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryScreen(
          tripId: cloned.trip.id,
          destination: widget.summary.destination,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _viewModel.selectedPlan;
    return AppScaffold(
      title: widget.summary.name,
      scrollable: true,
      bottomAction: CustomButton(
        text: 'Sử dụng lịch trình này',
        icon: Icons.content_copy_rounded,
        isLoading: _viewModel.isSubmitting,
        onPressed: _viewModel.isSubmitting ? null : _clone,
      ),
      body: detail == null
          ? _viewModel.isLoading
                ? const LoadingIndicator(message: 'Đang tải lịch trình...')
                : ErrorState(
                    message:
                        _viewModel.errorMessage ?? 'Không tìm thấy lịch trình.',
                    onRetry: () =>
                        _viewModel.loadDetail(widget.summary.sourceTripId),
                  )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  color: AppColors.primarySurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.summary.destination,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${detail.summary.durationDays} ngày · ★ ${detail.summary.averageRating.toStringAsFixed(1)} · ${detail.summary.cloneCount} lượt sử dụng',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final day in detail.days) ...[
                  Text(
                    'Ngày ${day.dayNumber}: ${day.title}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    outlined: true,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < day.items.length;
                          index++
                        ) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 15,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(day.items[index].customName),
                            subtitle: Text(
                              '${day.items[index].startTime} – ${day.items[index].endTime}'
                              '${day.items[index].customAddress == null ? '' : ' · ${day.items[index].customAddress}'}',
                            ),
                          ),
                          if (index < day.items.length - 1) const Divider(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
