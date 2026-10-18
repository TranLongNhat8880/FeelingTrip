import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../../admin/models/admin_content_model.dart';
import '../../admin/repositories/admin_content_repository.dart';
import '../../admin/views/plan_library_screen.dart';
import '../../review/repositories/trip_reviews_repository.dart';
import '../../review/views/widgets/trip_reviews_section.dart';
import '../models/itinerary_model.dart';
import '../repositories/itinerary_repository.dart';
import '../viewmodels/itinerary_viewmodel.dart';
import 'itinerary_screen.dart';
import 'public_itinerary_search_screen.dart';

class PublicItinerariesScreen extends StatefulWidget {
  const PublicItinerariesScreen({
    super.key,
    this.repository,
    this.initialDestination,
    this.reviewsRepository,
    this.embedded = false,
    this.onMenuTap,
    this.onProfileTap,
  });

  final ItineraryRepository? repository;
  final String? initialDestination;
  final TripReviewsRepository? reviewsRepository;
  final bool embedded;
  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;

  @override
  State<PublicItinerariesScreen> createState() =>
      _PublicItinerariesScreenState();
}

class _PublicItinerariesScreenState extends State<PublicItinerariesScreen> {
  final _adminRepo = AdminContentRepository();
  final _searchController = TextEditingController();
  String _source = 'COMMUNITY'; // 'SYSTEM' hoặc 'COMMUNITY'
  String _sort = 'newest';
  List<LibraryPlan> _plans = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialDestination != null &&
        widget.initialDestination!.isNotEmpty) {
      _searchController.text = widget.initialDestination!;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final search = _searchController.text.trim();
      if (widget.repository != null && _source == 'COMMUNITY') {
        final res = await widget.repository!.getPublicPlans(
          keyword: search.isEmpty ? null : search,
        );
        var items = res.items
            .map((p) => LibraryPlan({
                  'id': p.sourceTripId,
                  'name': p.name,
                  'destination': p.destination,
                  'durationDays': p.durationDays,
                  'coverImageUrl': p.coverImageUrl,
                  'description': p.description,
                  'source': 'COMMUNITY',
                  'usageCount': p.cloneCount,
                  'averageRating': p.averageRating,
                  'reviewCount': p.reviewCount,
                  'isActive': true,
                }))
            .toList();
        if (_sort == 'usage') {
          items.sort((a, b) => b.usage.compareTo(a.usage));
        } else if (_sort == 'rating') {
          items.sort((a, b) => b.rating.compareTo(a.rating));
        }
        if (mounted) setState(() => _plans = items);
      } else {
        final list = await _adminRepo.plans(
          source: _source,
          search: search,
          sort: _sort,
        );
        if (mounted) setState(() => _plans = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(LibraryPlan row) async {
    if (row.community) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicItineraryDetailScreen(
            summary: PublicItinerarySummary(
              sourceTripId: row.id,
              name: row.name,
              destination: row.destination,
              durationDays: row.durationDays,
              coverImageUrl: row.cover,
              description: row.description,
              averageRating: row.rating,
              reviewCount: row.reviews,
              cloneCount: row.usage,
            ),
            repository: widget.repository,
            reviewsRepository: widget.reviewsRepository,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlanDetailScreen(plan: row),
        ),
      );
    }
    if (mounted) await _load();
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => PublicItinerarySearchScreen(
          source: _source,
          repository: widget.repository,
          reviewsRepository: widget.reviewsRepository,
          initialQuery: _searchController.text.trim().isNotEmpty
              ? _searchController.text.trim()
              : null,
        ),
      ),
    );
    if (result != null && mounted) {
      if (result is String) {
        setState(() {
          _searchController.text = result;
        });
      } else if (result is ({String query, String source})) {
        setState(() {
          _searchController.text = result.query;
          _source = result.source;
        });
      }
      await _load();
    }
  }

  Widget _dropdownSelectedRow(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0284C7)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<String> _buildSortMenuItem(
    String val,
    String title,
    IconData icon,
  ) {
    final isSelected = _sort == val;
    return DropdownMenuItem<String>(
      value: val,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE0F2FE)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: isSelected
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: Color(0xFF0284C7),
              )
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ─── TAB FILTER PILLS: [ Mẫu hệ thống ] [ ✓ Cộng đồng ] ───
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Mẫu hệ thống'),
                selected: _source == 'SYSTEM',
                onSelected: (_) {
                  setState(() => _source = 'SYSTEM');
                  _load();
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFE0F2FE),
                labelStyle: TextStyle(
                  color: _source == 'SYSTEM'
                      ? const Color(0xFF0369A1)
                      : const Color(0xFF334155),
                  fontWeight:
                      _source == 'SYSTEM' ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _source == 'SYSTEM'
                        ? const Color(0xFFBAE6FD)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                showCheckmark: true,
              ),
              ChoiceChip(
                label: const Text('Cộng đồng'),
                selected: _source == 'COMMUNITY',
                onSelected: (_) {
                  setState(() => _source = 'COMMUNITY');
                  _load();
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFE0F2FE),
                labelStyle: TextStyle(
                  color: _source == 'COMMUNITY'
                      ? const Color(0xFF0369A1)
                      : const Color(0xFF334155),
                  fontWeight:
                      _source == 'COMMUNITY' ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _source == 'COMMUNITY'
                        ? const Color(0xFFBAE6FD)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                showCheckmark: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── SEARCH BAR ───
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    readOnly: true,
                    onTap: _openSearch,
                    decoration: InputDecoration(
                      hintText: 'Tên lịch trình hoặc điểm đến',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF94A3B8),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              tooltip: 'Xóa bộ lọc tìm kiếm',
                              onPressed: () {
                                setState(() => _searchController.clear());
                                _load();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tìm lịch trình',
                onPressed: _openSearch,
                icon: const Icon(
                  Icons.search,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (_searchController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        size: 14,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đang lọc: ${_searchController.text.trim()}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() => _searchController.clear());
                          _load();
                        },
                        child: const Icon(
                          Icons.cancel,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),

          // ─── SORT DROPDOWN ───
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sort,
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: Colors.white,
                    elevation: 6,
                    icon: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    isDense: true,
                    selectedItemBuilder: (context) {
                      return [
                        _dropdownSelectedRow('Mới nhất', Icons.schedule_rounded),
                        _dropdownSelectedRow('Được sử dụng nhiều', Icons.trending_up_rounded),
                        _dropdownSelectedRow('Đánh giá cao', Icons.star_rounded),
                      ];
                    },
                    items: [
                      _buildSortMenuItem('newest', 'Mới nhất', Icons.schedule_rounded),
                      _buildSortMenuItem('usage', 'Được sử dụng nhiều', Icons.trending_up_rounded),
                      _buildSortMenuItem('rating', 'Đánh giá cao', Icons.star_rounded),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _sort = v);
                        _load();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ─── CARD LIST ───
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: LoadingIndicator(message: 'Đang tải lịch trình...'),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ErrorState(message: _error!, onRetry: _load),
            )
          else if (_plans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: EmptyStateWidget(
                title: 'Chưa có lịch trình phù hợp',
                message: 'Thử đổi từ khóa tìm kiếm hoặc chuyển tab.',
                icon: Icons.route_outlined,
              ),
            )
          else
            for (final row in _plans)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFF1F5F9)),
                ),
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openDetail(row),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (row.cover != null && row.cover!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                row.cover!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Text(
                          row.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${row.destination} · ${row.durationDays} ngày',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${row.community ? 'Cộng đồng' : 'Mẫu hệ thống'} · ${row.usage} lượt sử dụng',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.reviews == 0
                              ? 'Chưa có đánh giá'
                              : '★ ${row.rating.toStringAsFixed(1)} (${row.reviews} đánh giá)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Material(
        type: MaterialType.transparency,
        child: TravelBackdrop(
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
                  Expanded(child: _content(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

    return AppScaffold(
      title: 'Lịch trình du lịch',
      padding: EdgeInsets.zero,
      body: _content(context),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
              text: 'Sao chép chuyến đi',
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
