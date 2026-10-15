import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../models/admin_content_model.dart';
import '../repositories/admin_content_repository.dart';
import '../viewmodels/admin_content_viewmodel.dart';

class PlanLibraryScreen extends StatefulWidget {
  const PlanLibraryScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<PlanLibraryScreen> createState() => _PlanLibraryScreenState();
}

class _PlanLibraryScreenState extends State<PlanLibraryScreen> {
  final vm = AdminContentViewModel();
  final search = TextEditingController();
  String source = 'SYSTEM', sort = 'newest';
  @override
  void initState() {
    super.initState();
    if (widget.embedded) source = 'COMMUNITY';
    load();
  }

  Future<void> load() =>
      vm.loadPlans(source: source, search: search.text.trim(), sort: sort);
  @override
  void dispose() {
    search.dispose();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _content(context)
      : AppScaffold(
          title: 'Lịch trình mẫu hệ thống',
          padding: EdgeInsets.zero,
          body: _content(context),
        );

  Widget _content(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: 'Tên lịch trình hoặc điểm đến',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => load(),
                ),
              ),
              IconButton(
                tooltip: 'Tìm lịch trình',
                onPressed: load,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          DropdownButton<String>(
            value: sort,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
              DropdownMenuItem(
                value: 'usage',
                child: Text('Được sử dụng nhiều'),
              ),
              DropdownMenuItem(
                value: 'rating',
                child: Text('Đánh giá cao'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => sort = v);
                load();
              }
            },
          ),
          if (vm.loading)
            const LoadingIndicator()
          else if (vm.error != null)
            ErrorState(message: vm.error!, onRetry: load)
          else if (vm.plans.isEmpty)
            const EmptyStateWidget(
              title: 'Chưa có lịch trình phù hợp',
              message: 'Thử đổi từ khóa tìm kiếm.',
              icon: Icons.route_outlined,
            )
          else
            for (final row in vm.plans)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlanDetailScreen(plan: row),
                      ),
                    );
                    if (mounted) await load();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (row.cover != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              row.cover!,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          row.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${row.destination} · ${row.durationDays} ngày'),
                        Text(
                          '${row.community ? 'Cộng đồng' : 'Mẫu hệ thống'} · ${row.usage} lượt sử dụng',
                        ),
                        Text(
                          row.reviews == 0
                              ? 'Chưa có đánh giá'
                              : '★ ${row.rating.toStringAsFixed(1)} (${row.reviews} đánh giá)',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.plan, this.admin = false});
  final LibraryPlan plan;
  final bool admin;
  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  int selectedDay = 0;
  final repo = AdminContentRepository();
  LibraryPlan? plan;
  String? error;
  bool loading = true, busy = false;
  String? appliedTrip;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final row = await repo.plan(
        widget.plan.id,
        admin: widget.admin,
        community: widget.plan.community,
      );
      if (mounted) setState(() => plan = row);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> apply() async {
    if (busy || plan == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final trips = await repo.eligibleTrips(plan!.durationDays);
      if (!mounted) return;
      if (trips.isEmpty) {
        setState(
          () => error =
              'Chưa có chuyến đi do bạn làm trưởng nhóm với số ngày phù hợp. Hãy tạo chuyến đi trước.',
        );
        return;
      }
      final id = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Chọn chuyến đi chưa có lịch trình')),
              for (final trip in trips)
                ListTile(
                  title: Text('${trip['name']}'),
                  subtitle: Text('${trip['durationDays']} ngày'),
                  onTap: () => Navigator.pop(context, '${trip['id']}'),
                ),
            ],
          ),
        ),
      );
      if (id == null || !mounted) return;
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Sử dụng lịch trình này?',
        message:
            'Sao chép các ngày và hoạt động vào chuyến đi đã chọn. Bản sao được chỉnh sửa độc lập.',
        confirmLabel: 'Sử dụng',
      );
      if (!confirmed || !mounted) return;
      await repo.apply(plan!, id);
      if (mounted) setState(() => appliedTrip = id);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> import() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.importCommunity(plan!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Chi tiết lịch trình',
    padding: EdgeInsets.zero,
    bottomAction: widget.admin || plan == null
        ? null
        : CustomButton(
            text: appliedTrip == null
                ? 'Sử dụng mẫu'
                : 'Đã sử dụng cho chuyến đi',
            isLoading: busy,
            onPressed: busy || appliedTrip != null ? null : apply,
          ),
    body: loading
        ? const LoadingIndicator()
        : plan == null
        ? ErrorState(
            message: error ?? 'Không tìm thấy lịch trình',
            onRetry: load,
          )
        : Column(
            children: [
              if (plan!.days.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var index = 0; index < plan!.days.length; index++)
                          InkWell(
                            onTap: () => setState(() => selectedDay = index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 3,
                                    color: selectedDay == index
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Ngày ${plan!.days[index]['dayNumber']}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: selectedDay == index
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontWeight: selectedDay == index
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (plan!.cover != null)
                      Image.network(
                        plan!.cover!,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      plan!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${plan!.destination} · ${plan!.durationDays} ngày'),
                    Text(
                      plan!.community ? 'Lịch trình cộng đồng' : 'Mẫu hệ thống',
                    ),
                    Text(
                      '${NumberFormat('#,###', 'vi_VN').format(plan!.budget)} đ dự kiến',
                    ),
                    const SizedBox(height: 12),
                    if (plan!.description.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Giới thiệu & lưu ý'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(plan!.description),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    if (plan!.days.isNotEmpty) ...[
                      Text(
                        '${(plan!.days[selectedDay]['items'] as List).length} hoạt động · Ngày ${plan!.days[selectedDay]['dayNumber']}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      for (final item
                          in plan!.days[selectedDay]['items'] as List)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 52,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    '${item['startTime']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: AppColors.primary),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['customName']}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${item['startTime']} – ${item['endTime']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        if ('${item['customAddress'] ?? ''}'
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              '${item['customAddress']}',
                                            ),
                                          ),
                                        if ((num.tryParse(
                                                  '${item['estimatedCost']}',
                                                ) ??
                                                0) >
                                            0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              '${NumberFormat('#,###', 'vi_VN').format(num.parse('${item['estimatedCost']}'))} đ dự kiến',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ),
                                        if ('${item['note'] ?? ''}'.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              '${item['note']}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      AppInlineNotice(
                        message: error!,
                        tone: AppStatusTone.error,
                      ),
                    ],
                    if (appliedTrip != null)
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/itineraries',
                          arguments: {
                            'tripId': appliedTrip!,
                            'destination': plan!.destination,
                          },
                        ),
                        child: const Text('Xem lịch trình của chuyến đi'),
                      ),
                    if (plan!.community &&
                        AuthScope.of(context).user?.isAdmin == true)
                      CustomButton(
                        text: 'Tạo mẫu hệ thống từ lịch trình này',
                        isLoading: busy,
                        onPressed: busy ? null : import,
                      ),
                  ],
                ),
              ),
            ],
          ),
  );
}
