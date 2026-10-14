import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
import '../repositories/admin_content_repository.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  final repo = AdminContentRepository();
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  bool loading = false, hasMore = false;
  int page = 1, request = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (more && (loading || !hasMore)) return;
    final id = ++request;
    final next = more ? page + 1 : 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final items = await repo.moderationPosts(
        search: search.text.trim(),
        page: next,
      );
      if (mounted && id == request) {
        setState(() {
          rows = more ? [...rows, ...items] : items;
          page = next;
          hasMore = items.length == 20;
        });
      }
    } catch (e) {
      if (mounted && id == request) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && id == request) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _content(context)
      : AppScaffold(
          title: 'Kiểm duyệt bài tuyển',
          padding: EdgeInsets.zero,
          body: _content(context),
        );

  Widget _content(BuildContext context) => RefreshIndicator(
    onRefresh: () => load(),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: search,
          decoration: InputDecoration(
            hintText: 'Tên bài, chuyến đi hoặc điểm đến',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => load(),
            ),
          ),
          onSubmitted: (_) => load(),
        ),
        const SizedBox(height: 12),
        const Text('Bài có báo cáo đang chờ xử lý được ưu tiên hiển thị.'),
        if (error != null) ErrorState(message: error!, onRetry: () => load()),
        const SizedBox(height: 12),
        for (final row in rows)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(row['title'] ?? 'Bài tuyển'),
              subtitle: Text(
                '${row['creator_name']} · ${row['destination'] ?? ''}\n${row['report_count'] ?? 0} báo cáo chờ xử lý',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminModerationDetailScreen(id: row['id']),
                  ),
                );
                if (mounted) await load();
              },
            ),
          ),
        if (loading)
          const LoadingIndicator()
        else if (rows.isEmpty && error == null)
          const EmptyStateWidget(
            title: 'Không có bài tuyển',
            message: 'Các bài đang tuyển thành viên sẽ xuất hiện tại đây.',
            icon: Icons.policy_outlined,
          ),
        if (!loading && hasMore)
          TextButton(
            onPressed: () => load(more: true),
            child: const Text('Tải thêm'),
          ),
      ],
    ),
  );
}

class AdminModerationDetailScreen extends StatefulWidget {
  const AdminModerationDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<AdminModerationDetailScreen> createState() =>
      _AdminModerationDetailScreenState();
}

class _AdminModerationDetailScreenState
    extends State<AdminModerationDetailScreen> {
  final repo = AdminContentRepository();
  final reason = TextEditingController();
  Map<String, dynamic>? post;
  bool loading = true, busy = false;
  String? error;
  String? actionDone;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final row = await repo.moderationPost(widget.id);
      if (mounted) setState(() => post = row);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> act(String action) async {
    if (busy) return;
    if (reason.text.trim().length < 3 || reason.text.trim().length > 1000) {
      setState(() => error = 'Nhập lý do từ 3 đến 1000 ký tự.');
      return;
    }
    final yes = await AppConfirmDialog.show(
      context,
      title: action == 'HIDE' ? 'Ẩn bài tuyển này?' : 'Gửi cảnh cáo?',
      message: action == 'HIDE'
          ? 'Bài sẽ bị đóng và rời bảng tin. Chuyến đi và thành viên không bị xoá.'
          : 'Trưởng nhóm sẽ nhận thông báo kèm lý do. Bài vẫn hiển thị.',
      confirmLabel: action == 'HIDE' ? 'Ẩn bài' : 'Gửi cảnh cáo',
    );
    if (!yes || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final row = await repo.moderatePost(
        widget.id,
        action,
        reason.text.trim(),
      );
      if (mounted) {
        setState(() {
          post = row;
          actionDone = action;
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

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Kiểm duyệt bài tuyển',
    scrollable: true,
    body: loading
        ? const LoadingIndicator()
        : post == null
        ? ErrorState(message: error ?? 'Không tải được bài', onRetry: load)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                post!['title'] ?? 'Bài tuyển',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Người đăng: ${post!['creator_name']}'),
              Text('${post!['trip_name']} · ${post!['destination'] ?? ''}'),
              const SizedBox(height: 16),
              Text(post!['content'] ?? 'Không có mô tả'),
              const SizedBox(height: 16),
              Text(
                'Thành viên: ${post!['current_members_count']}/${post!['target_members_count']}',
              ),
              if (post!['status'] == 'CLOSED')
                const AppInlineNotice(
                  message: 'Bài đăng đã đóng hoặc đã bị ẩn.',
                  tone: AppStatusTone.warning,
                ),
              if (actionDone == 'WARN')
                const AppInlineNotice(
                  message: 'Đã gửi cảnh cáo cho trưởng nhóm.',
                  tone: AppStatusTone.info,
                ),
              if (error != null)
                AppInlineNotice(message: error!, tone: AppStatusTone.error),
              if (post!['status'] != 'CLOSED') ...[
                const SizedBox(height: 16),
                CustomTextField(
                  controller: reason,
                  label: 'Lý do xử lý',
                  maxLines: 4,
                  enabled: !busy,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: actionDone == 'WARN'
                      ? 'Đã gửi cảnh cáo'
                      : 'Gửi cảnh cáo',
                  variant: AppButtonVariant.secondary,
                  onPressed: busy || actionDone == 'WARN'
                      ? null
                      : () => act('WARN'),
                ),
                const SizedBox(height: 10),
                CustomButton(
                  text: 'Ẩn bài tuyển',
                  variant: AppButtonVariant.destructive,
                  isLoading: busy,
                  onPressed: busy ? null : () => act('HIDE'),
                ),
              ],
            ],
          ),
  );
}
