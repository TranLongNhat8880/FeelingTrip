import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/constants/api_endpoints.dart';
import '../repositories/companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import 'companion_detail_screen.dart';

class CompanionSentRequestsContent extends StatefulWidget {
  const CompanionSentRequestsContent({super.key});
  @override
  State<CompanionSentRequestsContent> createState() =>
      _CompanionSentRequestsContentState();
}

class _CompanionSentRequestsContentState
    extends State<CompanionSentRequestsContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final CompanionRepository repo = ApiEndpoints.useMockData
      ? MockCompanionRepository()
      : ApiCompanionRepository();
  List<Map<String, dynamic>> rows = [];
  String status = '';
  String? error;
  int page = 1, request = 0;
  bool loading = false, busy = false, hasMore = false;
  final labels = {
    '': 'Tất cả',
    'PENDING': 'Chờ duyệt',
    'ACCEPTED': 'Đã duyệt',
    'REJECTED': 'Từ chối',
  };
  @override
  void initState() {
    super.initState();
    load();
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
      final items = await repo.getMySentRequests(status: status, page: next);
      if (!mounted || id != request) return;
      setState(() {
        rows = more ? [...rows, ...items] : items;
        page = next;
        hasMore = items.length == 20;
      });
    } catch (e) {
      if (mounted && id == request) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && id == request) setState(() => loading = false);
    }
  }

  Future<void> cancel(Map<String, dynamic> row) async {
    if (busy) return;
    final yes = await AppConfirmDialog.show(
      context,
      title: 'Huỷ yêu cầu tham gia?',
      message: 'Yêu cầu chưa được xử lý sẽ được huỷ.',
      confirmLabel: 'Huỷ yêu cầu',
    );
    if (!yes || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.deleteJoinRequest(row['id']);
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
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () => load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in labels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF09143B),
                  ),
                  selected: status == entry.key,
                  onSelected: busy
                      ? null
                      : (_) {
                          setState(() => status = entry.key);
                          load();
                        },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null) ErrorState(message: error!, onRetry: () => load()),
          if (!loading && error == null && rows.isEmpty)
            const EmptyStateWidget(
              title: 'Không có yêu cầu',
              message: 'Những yêu cầu bạn gửi sẽ xuất hiện tại đây.',
              icon: Icons.send_outlined,
            ),
          for (final row in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      row['title'] ??
                          row['tripName'] ??
                          'Bài tuyển bạn đồng hành',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(labels[row['status']] ?? row['status']),
                    if (row['introduction'] != null) Text(row['introduction']),
                    if (row['postStatus'] == 'CLOSED')
                      const Text('Bài đăng đã đóng'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: row['postStatus'] == 'CLOSED'
                                ? null
                                : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CompanionDetailScreen(
                                          postId: row['postId'],
                                        ),
                                      ),
                                    );
                                    if (mounted) await load();
                                  },
                            child: const Text('Xem bài đăng'),
                          ),
                        ),
                        if (row['status'] == 'PENDING')
                          Expanded(
                            child: TextButton(
                              onPressed: busy ? null : () => cancel(row),
                              child: const Text('Huỷ yêu cầu'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (loading || busy)
            const LoadingIndicator()
          else if (hasMore)
            TextButton(
              onPressed: () => load(more: true),
              child: const Text('Tải thêm'),
            ),
        ],
      ),
    );
  }
}
