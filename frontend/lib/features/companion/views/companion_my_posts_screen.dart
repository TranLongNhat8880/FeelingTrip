import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../repositories/companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import 'companion_detail_screen.dart';

class CompanionMyPostsScreen extends StatefulWidget {
  const CompanionMyPostsScreen({super.key, this.repository, this.userId});
  final CompanionRepository? repository;
  final String? userId;
  @override
  State<CompanionMyPostsScreen> createState() => _CompanionMyPostsScreenState();
}

class _CompanionMyPostsScreenState extends State<CompanionMyPostsScreen> {
  late final CompanionRepository repo =
      widget.repository ??
      (ApiEndpoints.useMockData
          ? MockCompanionRepository()
          : ApiCompanionRepository());
  final _images = <String, Future<String?>>{};
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
      final rows = widget.userId == null
          ? await repo.getMyPosts(page: next)
          : await repo.getPublicPosts(userId: widget.userId!, page: next);
      if (mounted) {
        setState(() {
          if (!more) _images.clear();
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

  Future<String?> _image(Map<String, dynamic> post) {
    final supplied = post['trip_cover_image_url'] ?? post['coverImageUrl'];
    if (post.containsKey('trip_cover_image_url') || supplied is String) {
      return Future.value(supplied as String?);
    }
    final id = post['id']?.toString() ?? '';
    return _images.putIfAbsent(id, () async {
      if (id.isEmpty) return null;
      try {
        return (await repo.getPostDetail(id)).trip.coverImageUrl;
      } catch (_) {
        // A failed thumbnail lookup must never block the recruitment list.
        return null;
      }
    });
  }

  Widget _row(Map<String, dynamic> post) {
    final id = post['id']?.toString() ?? '';
    final title = (post['title']?.toString() ?? '')
        .trim()
        .replaceFirst(
          RegExp(r'^Tìm\s+bạn\s+đồng\s+hành\s*:\s*', caseSensitive: false),
          '',
        )
        .trim();
    final closed = post['status'] == 'CLOSED';
    final full = post['status'] == 'FULL';
    return Material(
      color: Colors.white,
      child: InkWell(
        hoverColor: Colors.transparent,
        onTap: id.isEmpty
            ? null
            : () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CompanionDetailScreen(postId: id, repository: repo),
                  ),
                );
                if (mounted) await load();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                FutureBuilder<String?>(
                  future: _image(post),
                  builder: (context, snapshot) {
                    final url = snapshot.data;
                    if (url == null || url.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Image.network(
                      url,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, synchronous) =>
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: child,
                            ),
                          ),
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    );
                  },
                ),
                Expanded(
                  child: Text(
                    title.isNotEmpty
                        ? title
                        : post['trip_name']?.toString() ?? 'Bài tuyển',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: closed
                        ? AppColors.inputSurface
                        : full
                        ? AppColors.warningSurface
                        : AppColors.successSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    closed
                        ? 'Đã đóng'
                        : full
                        ? 'Đã đủ'
                        : 'Đang mở',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: closed
                          ? AppColors.textSecondary
                          : full
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppTopBar(
      title: widget.userId == null ? 'Bài tuyển của tôi' : 'Bài viết',
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(.5),
        child: Divider(height: .5, thickness: .5),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: () => load(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index < posts.length) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(posts[index]),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: .5, thickness: .5),
                ),
              ],
            );
          }
          return Column(
            children: [
              if (error != null)
                ErrorState(message: error!, onRetry: () => load()),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingIndicator(),
                )
              else if (posts.isEmpty && error == null)
                EmptyStateWidget(
                  title: widget.userId == null
                      ? 'Chưa có bài tuyển đang hoạt động'
                      : 'Chưa có bài viết công khai',
                  message: widget.userId == null
                      ? 'Bài tuyển của các chuyến đi bạn làm trưởng nhóm sẽ xuất hiện tại đây.'
                      : 'Các bài tuyển công khai của người dùng sẽ xuất hiện tại đây.',
                  icon: Icons.article_outlined,
                ),
              if (!loading && hasMore)
                TextButton(
                  onPressed: () => load(more: true),
                  child: const Text('Tải thêm'),
                ),
            ],
          );
        },
      ),
    ),
  );
}
