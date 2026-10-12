import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
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
          CustomButton(
            text: 'Thêm mẫu',
            icon: Icons.add,
            onPressed: vm.updating ? null : () => edit(),
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
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        row.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${row.destination} · ${row.durationDays} ngày · ${row.usage} lượt sử dụng',
                      ),
                      Text(row.active ? 'Đang hiển thị' : 'Đã ẩn'),
                      if (row.sourceTripId != null)
                        const Text('Được tạo từ lịch trình cộng đồng'),
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
