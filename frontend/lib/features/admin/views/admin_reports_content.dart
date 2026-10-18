import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/constants/app_colors.dart';
import '../../profile/views/public_profile_screen.dart';
import '../models/admin_content_model.dart';
import '../models/admin_trip_report_resolution.dart';
import '../repositories/admin_content_repository.dart';
import '../viewmodels/admin_content_viewmodel.dart';
import 'admin_moderation_screen.dart';
import 'admin_trip_report_actions.dart';
import 'admin_search_toolbar.dart';

class AdminReportsContent extends StatefulWidget {
  const AdminReportsContent({
    super.key,
    this.tripReports = false,
    this.repository,
    this.userAvatars = const {},
  });
  final bool tripReports;
  final Map<String, String?> userAvatars;
  final AdminContentRepository? repository;
  @override
  State<AdminReportsContent> createState() => _AdminReportsContentState();
}

class _AdminReportsContentState extends State<AdminReportsContent> {
  late final AdminContentViewModel vm;
  final search = TextEditingController();
  bool searching = false;
  String status = 'PENDING';
  static const statuses = {
    'PENDING': 'Chờ xử lý',
    'RESOLVED': 'Đã xử lý',
    'DISMISSED': 'Bác bỏ',
  };
  @override
  void initState() {
    super.initState();
    vm = AdminContentViewModel(repository: widget.repository);
    load();
  }

  Future<void> load() => vm.loadReports(status, search.text.trim());
  @override
  void dispose() {
    search.dispose();
    vm.dispose();
    super.dispose();
  }

  Widget reportTile(AdminReport report) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    hoverColor: Colors.transparent,
    leading: widget.tripReports
        ? Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.luggage_outlined, color: AppColors.primary),
          )
        : AvatarPlaceholder(
            name: report.targetName,
            imageUrl: report.userAvatarUrl ?? widget.userAvatars[report.userId],
            radius: 21,
          ),
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            report.targetName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 128),
          child: AppStatusBadge(
            label: report.statusLabel,
            tone: report.status == 'PENDING'
                ? AppStatusTone.warning
                : report.status == 'RESOLVED'
                ? AppStatusTone.success
                : AppStatusTone.neutral,
          ),
        ),
      ],
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (report.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy · HH:mm').format(report.createdAt!),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      size: 20,
      color: AppColors.textHint,
    ),
    onTap: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminReportDetailScreen(
            id: report.id,
            repository: widget.repository,
          ),
        ),
      );
      if (mounted) await load();
    },
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: vm,
    builder: (context, _) {
      final reports = vm.reports
          .where((r) => r.isTripReport == widget.tripReports)
          .toList();
      return Material(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AdminSearchToolbar(
                searching: searching,
                controller: search,
                hint: widget.tripReports
                    ? 'Tìm chuyến đi bị báo cáo'
                    : 'Tìm người bị báo cáo',
                filter: PopupMenuButton<String>(
                  tooltip: 'Lọc trạng thái',
                  initialValue: status,
                  onSelected: (value) {
                    setState(() => status = value);
                    load();
                  },
                  itemBuilder: (_) => [
                    for (final entry in statuses.entries)
                      CheckedPopupMenuItem(
                        value: entry.key,
                        checked: status == entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statuses[status]!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.expand_more, size: 20),
                      ],
                    ),
                  ),
                ),
                onOpen: () => setState(() => searching = true),
                onClose: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  search.clear();
                  setState(() => searching = false);
                  load();
                },
                onSubmit: load,
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (vm.loading)
                      const LoadingIndicator()
                    else if (vm.error != null)
                      ErrorState(message: vm.error!, onRetry: load)
                    else if (reports.isEmpty)
                      const EmptyStateWidget(
                        title: 'Không có báo cáo',
                        message: 'Chưa có báo cáo phù hợp.',
                        icon: Icons.fact_check_outlined,
                      )
                    else
                      for (final report in reports) ...[
                        reportTile(report),
                        const Divider(height: 1, color: AppColors.divider),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
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

  Future<void> load({bool preserveDraft = true}) async {
    final draft = notes.text;
    final keepDraft =
        preserveDraft &&
        report?.status == 'PENDING' &&
        draft != (report?.notes ?? '');
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final row = await repo.report(widget.id);
      if (mounted) {
        setState(() {
          report = row;
          notes.text = keepDraft && row.status == 'PENDING'
              ? draft
              : row.notes ?? '';
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
    final internalNotes = notes.text.trim();
    final savedNotes = action == 'INSUFFICIENT'
        ? '[Chưa đủ bằng chứng] $internalNotes'
        : internalNotes;
    if (internalNotes.length < 3 || savedNotes.length > 1000) {
      final limit = action == 'INSUFFICIENT'
          ? 1000 - '[Chưa đủ bằng chứng] '.length
          : 1000;
      setState(() => error = 'Nhập ghi chú kết luận từ 3 đến $limit ký tự.');
      return;
    }
    if (report?.isTripReport == true && action == 'RESOLVED') return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final row = await repo.resolve(
        widget.id,
        action == 'INSUFFICIENT' ? 'DISMISSED' : action,
        savedNotes,
      );
      if (mounted) {
        setState(() {
          row.context.addAll(report?.context ?? {});
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
          row.context.addAll(report?.context ?? {});
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
      if (mounted) await load(preserveDraft: false);
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
    final reason = notes.text.trim();
    if (reason.length < 3 || reason.length > 500) {
      setState(
        () => error = 'Nhập lý do khóa từ 3 đến 500 ký tự trong phần ghi chú.',
      );
      return;
    }
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Khóa tài khoản bị báo cáo?',
      message: 'Đây là thao tác riêng, báo cáo vẫn cần được kết luận.',
      confirmLabel: 'Khóa tài khoản',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.ban(report!.userId!, reason);
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget get separator => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(height: 1, color: AppColors.divider),
  );

  void openEvidence() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Ảnh bằng chứng'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                report!.image!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  'Không tải được ảnh bằng chứng',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget evidence() => Align(
    alignment: Alignment.centerLeft,
    child: Semantics(
      button: true,
      label: 'Xem ảnh bằng chứng',
      child: InkWell(
        onTap: openEvidence,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  report!.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.inputSurface,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
                const Positioned(
                  right: 4,
                  top: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.fullscreen,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget relatedTrip() => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    title: Text(
      'Chuyến đi và bài tuyển liên quan',
      style: Theme.of(context).textTheme.titleSmall,
    ),
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(report!.context['trip']['name'] ?? 'Chuyến đi'),
        subtitle: Text(
          '${report!.context['trip']['destination'] ?? ''}\n'
          'Trạng thái: ${tripStatus(report!.context['trip']['status'])}\n'
          'Thời gian: ${date(report!.context['trip']['start_date'])} – '
          '${date(report!.context['trip']['end_date'])}\n'
          'Chi phí dự kiến: ${NumberFormat.decimalPattern('vi').format(num.tryParse('${report!.context['trip']['estimated_budget']}') ?? 0)} đ',
        ),
      ),
      for (final post in report!.context['posts'] as List? ?? [])
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(post['title'] ?? 'Bài tuyển'),
          subtitle: Text(postStatus(post['status'])),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminModerationDetailScreen(id: post['id']),
              ),
            );
            if (mounted) await load();
          },
        ),
    ],
  );

  String date(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null
        ? 'Chưa cập nhật'
        : DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  String tripStatus(dynamic value) =>
      const {
        'PLANNING': 'Đang lên kế hoạch',
        'ONGOING': 'Đang diễn ra',
        'COMPLETED': 'Đã kết thúc',
        'CANCELLED': 'Đã hủy',
      }[value] ??
      value?.toString() ??
      'Chưa cập nhật';

  String postStatus(dynamic value) =>
      const {
        'OPEN': 'Đang mở',
        'FULL': 'Đã đủ người',
        'CLOSED': 'Đã đóng',
      }[value] ??
      value?.toString() ??
      'Chưa cập nhật';

  Widget reportBody() {
    final row = report!;
    final user = row.context['user'] is Map ? row.context['user'] as Map : null;
    final verified = user?['verification_status'] == 'VERIFIED';
    final banned = row.userStatus == 'BANNED' || user?['status'] == 'BANNED';
    final pending = row.status == 'PENDING';
    final statusColor = pending
        ? AppColors.warning
        : row.status == 'RESOLVED'
        ? AppColors.success
        : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              row.statusLabel,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          hoverColor: Colors.transparent,
          leading: AvatarPlaceholder(
            name: row.targetName,
            imageUrl: user?['avatar_url'] as String? ?? row.userAvatarUrl,
            radius: 26,
          ),
          title: Text(
            row.targetName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: row.userId == null
              ? const Text('Chuyến đi bị báo cáo')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (verified)
                      const Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 16,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Đã xác minh',
                            style: TextStyle(color: AppColors.success),
                          ),
                        ],
                      ),
                    Text(
                      banned ? 'Đã khóa' : 'Hoạt động',
                      style: TextStyle(
                        color: banned
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
          trailing: row.userId == null ? null : const Icon(Icons.chevron_right),
          onTap: row.userId == null
              ? null
              : () => PublicProfileScreen.open(context, userId: row.userId!),
        ),
        separator,
        Row(
          children: [
            const Text(
              'Người gửi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: row.reporterId == null
                    ? Text(row.reporterName, textAlign: TextAlign.right)
                    : TextButton(
                        onPressed: () => PublicProfileScreen.open(
                          context,
                          userId: row.reporterId!,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                row.reporterName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (row.createdAt != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Ngày gửi',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy · HH:mm').format(row.createdAt!),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
        separator,
        sectionTitle('Nội dung báo cáo'),
        Text(row.reason),
        if (row.image?.isNotEmpty == true) ...[
          const SizedBox(height: 20),
          sectionTitle('Bằng chứng'),
          evidence(),
        ],
        separator,
        if (row.context['trip'] is Map) ...[relatedTrip(), separator],
        sectionTitle('Kết luận'),
        CustomTextField(
          controller: notes,
          label: 'Ghi chú kết luận (nội bộ)',
          hint: 'Nhập kết luận xử lý…',
          maxLines: 3,
          enabled: pending && !busy,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          AppInlineNotice(message: error!, tone: AppStatusTone.error),
        ],
        if (pending) ...[
          const SizedBox(height: 16),
          if (row.isTripReport)
            AdminTripReportActions(
              report: row,
              busy: busy,
              onSubmit: processTripReport,
            )
          else
            CustomButton(
              text: 'Kết luận báo cáo',
              isLoading: busy,
              onPressed: busy ? null : () => resolve('RESOLVED'),
            ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttons = [
                CustomButton(
                  text: 'Bác bỏ báo cáo',
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : () => resolve('DISMISSED'),
                ),
                CustomButton(
                  text: 'Chưa đủ bằng chứng',
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : () => resolve('INSUFFICIENT'),
                ),
              ];
              if (constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [buttons[0], const SizedBox(height: 8), buttons[1]],
                );
              }
              return Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 8),
                  Expanded(child: buttons[1]),
                ],
              );
            },
          ),
          if (row.userId != null && row.userRole != 'ADMIN') ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : warn,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning,
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: const Text('Gửi cảnh cáo và kết luận'),
                ),
                TextButton.icon(
                  onPressed: busy || banned ? null : ban,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: Text(banned ? 'Tài khoản đã khóa' : 'Khóa tài khoản'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: report == null
        ? 'Chi tiết báo cáo'
        : report!.isTripReport
        ? 'Báo cáo chuyến đi'
        : 'Báo cáo người dùng',
    padding: EdgeInsets.zero,
    body: Material(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                const LoadingIndicator()
              else if (report == null)
                ErrorState(
                  message: error ?? 'Không tải được báo cáo',
                  onRetry: load,
                )
              else
                reportBody(),
            ],
          ),
        ),
      ),
    ),
  );
}
