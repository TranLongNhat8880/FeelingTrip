import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../../review/repositories/trip_reviews_repository.dart';
import '../../review/views/widgets/trip_reviews_section.dart';
import '../models/itinerary_model.dart';
import '../repositories/itinerary_repository.dart';
import '../viewmodels/itinerary_viewmodel.dart';
import 'itinerary_screen.dart';
import '../../admin/views/plan_library_screen.dart';

class PublicItinerariesScreen extends StatefulWidget {
  const PublicItinerariesScreen({
    super.key,
    this.repository,
    this.initialDestination,
    this.reviewsRepository,
  });

  final ItineraryRepository? repository;
  final String? initialDestination;
  final TripReviewsRepository? reviewsRepository;

  @override
  State<PublicItinerariesScreen> createState() =>
      _PublicItinerariesScreenState();
}

class _PublicItinerariesScreenState extends State<PublicItinerariesScreen> {
  late final PublicItineraryViewModel _viewModel;
  late final TextEditingController _destination;
  final _keyword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _destination = TextEditingController(text: widget.initialDestination);
    _viewModel = PublicItineraryViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..load(destination: widget.initialDestination);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    _destination.dispose();
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _search() =>
      _viewModel.load(destination: _destination.text, keyword: _keyword.text);

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Kho lịch trình',
    padding: EdgeInsets.zero,
    body: RefreshIndicator(
      onRefresh: _search,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
        children: [
          const AppInlineNotice(
            message:
                'Chỉ hiển thị chuyến đi công khai đã hoàn thành. Khi nhân bản, hệ thống tạo một chuyến đi riêng để bạn chỉnh sửa.',
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
          CustomTextField(
            label: 'Điểm đến',
            controller: _destination,
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 10),
          AppSearchField(
            controller: _keyword,
            hint: 'Tên lịch trình hoặc điểm dừng',
            onChanged: (_) {},
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Tìm lịch trình',
            icon: Icons.search_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: _viewModel.isLoading ? null : _search,
          ),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Lịch trình cộng đồng',
            subtitle: '${_viewModel.plans.length} kết quả phù hợp',
          ),
          const SizedBox(height: 12),
          if (_viewModel.isLoading && _viewModel.plans.isEmpty)
            const LoadingIndicator(message: 'Đang tìm lịch trình...')
          else if (_viewModel.errorMessage != null && _viewModel.plans.isEmpty)
            ErrorState(message: _viewModel.errorMessage!, onRetry: _search)
          else if (_viewModel.plans.isEmpty)
            const EmptyStateWidget(
              icon: Icons.auto_awesome_outlined,
              title: 'Chưa có lịch trình phù hợp',
              message: 'Thử thay đổi điểm đến hoặc từ khóa tìm kiếm.',
            )
          else
            for (final plan in _viewModel.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PublicPlanCard(
                  plan: plan,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicItineraryDetailScreen(
                        summary: plan,
                        repository: widget.repository,
                        reviewsRepository: widget.reviewsRepository,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

class _PublicPlanCard extends StatelessWidget {
  const _PublicPlanCard({required this.plan, required this.onTap});

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
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${plan.destination} · ${plan.durationDays} ngày',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (plan.description != null) ...[
          const SizedBox(height: 8),
          Text(plan.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          children: [
            Text(
              '★ ${plan.averageRating.toStringAsFixed(1)} (${plan.reviewCount})',
            ),
            Text('${plan.cloneCount} lượt sử dụng'),
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
    this.reviewsRepository,
  });

  final PublicItinerarySummary summary;
  final ItineraryRepository? repository;
  final TripReviewsRepository? reviewsRepository;

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
              onPressed: () => Navigator.pop(context, (
                name: name.text.trim(),
                startDate: startDate,
              )),
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
                const SizedBox(height: 8),
                TripReviewsSection(
                  key: ValueKey(widget.summary.sourceTripId),
                  sourceTripId: widget.summary.sourceTripId,
                  repository: widget.reviewsRepository,
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
