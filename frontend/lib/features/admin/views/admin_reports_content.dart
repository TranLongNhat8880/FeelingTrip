import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/ui_kit.dart';
import '../models/admin_content_model.dart';
import '../models/admin_trip_report_resolution.dart';
import '../repositories/admin_content_repository.dart';
import '../viewmodels/admin_content_viewmodel.dart';
import 'admin_moderation_screen.dart';
import 'admin_trip_report_actions.dart';

class AdminReportsContent extends StatefulWidget {
  const AdminReportsContent({super.key});
  @override
  State<AdminReportsContent> createState() => _AdminReportsContentState();
}

class _AdminReportsContentState extends State<AdminReportsContent> {
  final vm = AdminContentViewModel();
  final search = TextEditingController();
  String status = 'PENDING';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() => vm.loadReports(status, search.text.trim());
  @override
  void dispose() {
    search.dispose();
    vm.dispose();
    super.dispose();
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
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: 'Lý do, người dùng hoặc chuyến đi',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => load(),
                ),
              ),
              IconButton(
                tooltip: 'Tìm báo cáo',
                onPressed: load,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                'PENDING': 'Chờ xử lý',
                'RESOLVED': 'Đã xử lý',
                'DISMISSED': 'Bác bỏ',
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
          const SizedBox(height: 16),
          if (vm.loading)
            const LoadingIndicator()
          else if (vm.error != null)
            ErrorState(message: vm.error!, onRetry: load)
          else if (vm.reports.isEmpty)
            const EmptyStateWidget(
              title: 'Không có báo cáo',
              message: 'Các báo cáo phù hợp sẽ xuất hiện tại đây.',
              icon: Icons.fact_check_outlined,
            )
          else
            for (final report in vm.reports)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(report.targetName),
                  subtitle: Text(
                    '${report.reason}\n${report.createdAt == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt!)}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminReportDetailScreen(id: report.id),
                      ),
                    );
                    if (mounted) await load();
                  },
                ),
              ),
        ],
      ),
    ),
  );
}

class AdminReportDetailScreen extends StatefulWidget {
  const AdminReportDetailScreen({super.key, required this.id, this.repository});
  final String id;
  final AdminContentRepository? repository;
  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  late final AdminContentRepository repo;
  final notes = TextEditingController();
  AdminReport? report;
  bool loading = true, busy = false;
  bool confirmingTripProcessing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? AdminContentRepository();
    load();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final row = await repo.report(widget.id);
      if (mounted) {
        setState(() {
          report = row;
          notes.text = row.notes ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resolve(String action) async {
    if (busy) return;
    if (notes.text.trim().length < 3 || notes.text.trim().length > 1000) {
      setState(() => error = 'Nhập ghi chú kết luận từ 3 đến 1000 ký tự.');
      return;
    }
    if (report?.isTripReport == true && action == 'RESOLVED') return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final row = action == 'WARN'
          ? await repo.warnReport(widget.id, notes.text.trim())
          : await repo.resolve(
              widget.id,
              action == 'INSUFFICIENT' ? 'DISMISSED' : action,
              action == 'INSUFFICIENT'
                  ? '[Chưa đủ bằng chứng] ${notes.text.trim()}'
                  : notes.text.trim(),
            );
      if (mounted) {
        setState(() {
          report = row;
          notes.text = row.notes ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> processTripReport(TripReportResolution resolution) async {
    if (busy ||
        confirmingTripProcessing ||
        report?.isTripReport != true ||
        report?.supportsTripProcessing != true) {
      return;
    }
    final internalNotes = notes.text.trim();
    if (internalNotes.length < 3 || internalNotes.length > 1000) {
      setState(
        () => error = 'Nhập ghi chú kết luận nội bộ từ 3 đến 1000 ký tự.',
      );
      return;
    }
    confirmingTripProcessing = true;
    try {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Xác nhận xử lý báo cáo chuyến đi?',
        message:
            '${resolution.actions.map((action) => '• ${action.label}').join('\n')}\n\n'
            'Các hành động sẽ được áp dụng và đơn sẽ chuyển sang Đã xử lý. '
            'Ghi chú nội bộ không được gửi cho người bị xử lý.',
        confirmLabel: 'Áp dụng và kết luận',
        destructive: resolution.actions.any(
          (action) => action.type == 'BAN_USER',
        ),
      );
      if (!confirmed || !mounted) return;
      setState(() {
        busy = true;
        error = null;
      });
      final row = await repo.processTripReport(
        widget.id,
        internalNotes,
        resolution,
      );
      if (mounted) {
        setState(() {
          report = row;
          notes.text = row.notes ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      confirmingTripProcessing = false;
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> warn() async {
    if (busy) return;
    var warningText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Gửi cảnh cáo'),
          content: TextField(
            maxLines: 4,
            maxLength: 980,
            decoration: const InputDecoration(
              labelText: 'Nội dung gửi cho người bị báo cáo',
            ),
            onChanged: (value) => setDialogState(() {
              warningText = value;
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Huỷ'),
            ),
            TextButton(
              onPressed: warningText.trim().length < 3
                  ? null
                  : () => Navigator.pop(dialogContext, warningText.trim()),
              child: const Text('Gửi và kết luận'),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.warnReport(widget.id, reason);
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ban() async {
    if (busy || report?.userId == null) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Khóa tài khoản bị báo cáo?',
      message: 'Đây là thao tác riêng, báo cáo vẫn cần được kết luận.',
      confirmLabel: 'Khóa tài khoản',
    );
    if (!confirmed || !mounted) return;
    if (notes.text.trim().length < 3) {
      setState(() => error = 'Nhập lý do khóa trong phần ghi chú.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.ban(report!.userId!, notes.text.trim());
      if (mounted) await load();
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
    title: 'Chi tiết báo cáo',
    actions: [
      IconButton(
        tooltip: 'Tải lại báo cáo',
        icon: const Icon(Icons.refresh),
        onPressed: busy || loading ? null : load,
      ),
    ],
    scrollable: true,
    body: loading
        ? const LoadingIndicator()
        : report == null
        ? ErrorState(message: error ?? 'Không tải được báo cáo', onRetry: load)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                report!.targetName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Người gửi: ${report!.reporterName}'),
              Text('Trạng thái: ${report!.statusLabel}'),
              if (report!.context['user'] is Map)
                ExpansionTile(
                  title: const Text('Thông tin tài khoản bị báo cáo'),
                  children: [
                    ListTile(
                      title: Text(
                        report!.context['user']['full_name'] ?? 'Người dùng',
                      ),
                      subtitle: Text(
                        'Trạng thái: ${report!.context['user']['status']}\nXác minh: ${report!.context['user']['verification_status']}',
                      ),
                    ),
                  ],
                ),
              if (report!.context['trip'] is Map)
                ExpansionTile(
                  title: const Text('Chuyến đi và bài tuyển liên quan'),
                  children: [
                    ListTile(
                      title: Text(
                        report!.context['trip']['name'] ?? 'Chuyến đi',
                      ),
                      subtitle: Text(
                        '${report!.context['trip']['destination'] ?? ''}\nTrạng thái: ${report!.context['trip']['status']}\nThời gian: ${report!.context['trip']['start_date']} – ${report!.context['trip']['end_date']}\nChi phí dự kiến: ${report!.context['trip']['estimated_budget'] ?? 0} đ',
                      ),
                    ),
                    for (final post in report!.context['posts'] as List? ?? [])
                      ListTile(
                        title: Text(post['title'] ?? 'Bài tuyển'),
                        subtitle: Text(post['status']),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminModerationDetailScreen(id: post['id']),
                            ),
                          );
                          if (mounted) await load();
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(report!.reason),
              if (report!.image != null) ...[
                const SizedBox(height: 16),
                const Text('Ảnh bằng chứng'),
                Image.network(
                  report!.image!,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Không tải được ảnh bằng chứng'),
                ),
              ],
              const SizedBox(height: 20),
              CustomTextField(
                controller: notes,
                label: 'Ghi chú kết luận (nội bộ)',
                maxLines: 4,
                enabled: report!.status == 'PENDING' && !busy,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                AppInlineNotice(message: error!, tone: AppStatusTone.error),
              ],
              const SizedBox(height: 16),
              if (report!.status == 'PENDING') ...[
                if (report!.isTripReport)
                  AdminTripReportActions(
                    report: report!,
                    busy: busy,
                    onSubmit: processTripReport,
                  )
                else
                  CustomButton(
                    text: 'Đánh dấu đã xử lý',
                    isLoading: busy,
                    onPressed: busy ? null : () => resolve('RESOLVED'),
                  ),
                const SizedBox(height: 10),
                CustomButton(
                  text: 'Bác bỏ báo cáo',
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : () => resolve('DISMISSED'),
                ),
                const SizedBox(height: 10),
                CustomButton(
                  text: 'Chưa đủ bằng chứng',
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : () => resolve('INSUFFICIENT'),
                ),
                if (report!.userId != null && report!.userRole != 'ADMIN') ...[
                  const SizedBox(height: 10),
                  CustomButton(
                    text: 'Gửi cảnh cáo và kết luận',
                    variant: AppButtonVariant.secondary,
                    onPressed: busy ? null : warn,
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    text: report!.userStatus == 'BANNED'
                        ? 'Tài khoản đã khóa'
                        : 'Khóa tài khoản',
                    variant: AppButtonVariant.destructive,
                    onPressed: busy || report!.userStatus == 'BANNED'
                        ? null
                        : ban,
                  ),
                ],
              ],
            ],
          ),
  );
}
