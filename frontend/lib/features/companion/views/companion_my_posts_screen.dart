import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/constants/api_endpoints.dart';
import '../repositories/companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import 'companion_detail_screen.dart';

class CompanionMyPostsScreen extends StatefulWidget {
  const CompanionMyPostsScreen({super.key});
  @override
  State<CompanionMyPostsScreen> createState() => _CompanionMyPostsScreenState();
}

class _CompanionMyPostsScreenState extends State<CompanionMyPostsScreen> {
  late final CompanionRepository repo = ApiEndpoints.useMockData
      ? MockCompanionRepository()
      : ApiCompanionRepository();
  List<Map<String, dynamic>> posts = [];
  bool loading = false, hasMore = false;
  int page = 1;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    final next = more ? page + 1 : 1;
    try {
      final rows = await repo.getMyPosts(page: next);
      if (mounted) {
        setState(() {
          posts = more ? [...posts, ...rows] : rows;
          page = next;
          hasMore = rows.length == 20;
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

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Bài tuyển của tôi',
    padding: EdgeInsets.zero,
    body: RefreshIndicator(
      onRefresh: () => load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null) ErrorState(message: error!, onRetry: () => load()),
          for (final post in posts)
            Card(
              child: ListTile(
                title: Text(post['title'] ?? 'Bài tuyển'),
                subtitle: Text(
                  '${post['trip_name'] ?? ''} · ${post['status'] == 'FULL' ? 'Đã đầy' : 'Đang mở'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompanionDetailScreen(postId: post['id']),
                    ),
                  );
                  if (mounted) await load();
                },
              ),
            ),
          if (loading)
            const LoadingIndicator()
          else if (posts.isEmpty && error == null)
            const EmptyStateWidget(
              title: 'Chưa có bài tuyển đang hoạt động',
              message:
                  'Bài tuyển của các chuyến đi bạn làm trưởng nhóm sẽ xuất hiện tại đây.',
              icon: Icons.article_outlined,
            ),
          if (!loading && hasMore)
            TextButton(
              onPressed: () => load(more: true),
              child: const Text('Tải thêm'),
            ),
        ],
      ),
    ),
  );
}
