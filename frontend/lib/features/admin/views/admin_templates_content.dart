import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import '../models/admin_content_model.dart';
import '../viewmodels/admin_content_viewmodel.dart';
import 'template_form_screen.dart';
import 'plan_library_screen.dart';

class AdminTemplatesContent extends StatefulWidget {
  const AdminTemplatesContent({super.key});
  @override
  State<AdminTemplatesContent> createState() => _AdminTemplatesContentState();
}

class _AdminTemplatesContentState extends State<AdminTemplatesContent> {
  final vm = AdminContentViewModel();
  final search = TextEditingController();
  String status = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() =>
      vm.loadPlans(admin: true, search: search.text.trim(), status: status);
  @override
  void dispose() {
    search.dispose();
    vm.dispose();
    super.dispose();
  }

  Future<void> edit([LibraryPlan? row]) async {
    LibraryPlan? detail = row;
    if (row != null &&
        !await vm.update(() async {
          detail = await vm.repository.plan(row.id, admin: true);
        })) {
      return;
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TemplateFormScreen(plan: detail)),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> toggle(LibraryPlan row) async {
    if (await vm.update(() => vm.repository.toggle(row))) await load();
  }

  Future<void> remove(LibraryPlan row) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: 'Xóa lịch trình mẫu?',
      message: row.name,
      confirmLabel: 'Xóa',
    );
    if (ok && mounted && await vm.update(() => vm.repository.delete(row))) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mẫu hệ thống',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${vm.plans.length} mẫu trong danh sách',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: vm.updating ? null : () => edit(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm mẫu'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: search,
            decoration: const InputDecoration(
              hintText: 'Tên mẫu hoặc điểm đến',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => load(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                '': 'Tất cả',
                'ACTIVE': 'Đang hiển thị',
                'HIDDEN': 'Đã ẩn',
              }.entries)
                ChoiceChip(
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF09143B),
                  ),
                  label: Text(entry.value),
                  selected: status == entry.key,
                  onSelected: (_) {
                    setState(() => status = entry.key);
                    load();
                  },
                ),
            ],
          ),
          if (vm.error != null)
            AppInlineNotice(message: vm.error!, tone: AppStatusTone.error),
          const SizedBox(height: 16),
          if (vm.loading)
            const LoadingIndicator()
          else if (vm.plans.isEmpty)
            const EmptyStateWidget(
              title: 'Chưa có lịch trình mẫu',
              message: 'Tạo mẫu đầu tiên để người dùng tham khảo.',
              icon: Icons.route_outlined,
            )
          else
            for (final row in vm.plans)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 76,
                              height: 84,
                              child: row.cover == null
                                  ? const ColoredBox(
                                      color: AppColors.primarySurface,
                                      child: Icon(
                                        Icons.route_outlined,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Image.network(
                                      row.cover!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                            color: AppColors.primarySurface,
                                            child: Icon(Icons.route_outlined),
                                          ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${row.destination} · ${row.durationDays} ngày',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${NumberFormat('#,###', 'vi_VN').format(row.budget)} đ dự kiến',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          AppStatusBadge(
                            label: row.active ? 'Đang hiển thị' : 'Đã ẩn',
                            tone: row.active
                                ? AppStatusTone.success
                                : AppStatusTone.neutral,
                          ),
                          const Spacer(),
                          Text(
                            '${row.usage} lượt sử dụng',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (row.sourceTripId != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Từ lịch trình cộng đồng'),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: vm.updating
                                ? null
                                : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PlanDetailScreen(
                                          plan: row,
                                          admin: true,
                                        ),
                                      ),
                                    );
                                    if (mounted) await load();
                                  },
                            child: const Text('Xem'),
                          ),
                          TextButton(
                            onPressed: vm.updating ? null : () => edit(row),
                            child: const Text('Sửa'),
                          ),
                          TextButton(
                            onPressed: vm.updating ? null : () => toggle(row),
                            child: Text(row.active ? 'Ẩn' : 'Hiện'),
                          ),
                          TextButton(
                            onPressed: vm.updating || row.usage > 0
                                ? null
                                : () => remove(row),
                            child: const Text('Xóa'),
                          ),
                        ],
                      ),
                      if (row.usage > 0)
                        const Text(
                          'Mẫu đã được sử dụng: có thể ẩn, không thể xóa.',
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
