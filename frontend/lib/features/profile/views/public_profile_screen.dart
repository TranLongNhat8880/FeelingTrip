import 'package:flutter/material.dart';

import '../../../shared/ui_kit.dart';
import '../../companion/views/companion_my_posts_screen.dart';
import '../models/trust_score_model.dart';
import '../repositories/profile_repository.dart';
import '../viewmodels/public_profile_viewmodel.dart';

/// Other features pass the viewed user's ID, never the logged-in user's profile.
/// Only public fields from GET /users/trust-score/:id are displayed.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId, this.repository});

  final String userId;
  final ProfileRepository? repository;

  static Future<void> open(
    BuildContext context, {
    required String userId,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
    );
  }

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late PublicProfileViewModel _vm;

  @override
  void initState() {
    super.initState();
    _createViewModel();
  }

  void _createViewModel() {
    _vm = PublicProfileViewModel(repository: widget.repository);
    _vm.load(widget.userId);
  }

  @override
  void didUpdateWidget(covariant PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _vm.dispose();
      _createViewModel();
    } else if (oldWidget.userId != widget.userId) {
      _vm.load(widget.userId);
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  String _date(DateTime? date) {
    if (date == null) return 'Chưa có thông tin';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Widget _content(TrustScoreModel profile) {
    final text = Theme.of(context).textTheme;
    final name = profile.displayName.trim().isEmpty
        ? 'Người dùng'
        : profile.displayName;
    final hasReviews = profile.reviewCount > 0;
    final score = profile.trustScore.toStringAsFixed(
      profile.trustScore % 1 == 0 ? 0 : 1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarPlaceholder(
              name: name,
              imageUrl: profile.avatarUrl,
              radius: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 17,
                        color: profile.isVerified
                            ? const Color(0xFF008B57)
                            : const Color(0xFF5D6889),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          profile.isVerified
                              ? 'Đã xác minh'
                              : 'Chưa xác minh danh tính',
                          style: text.bodySmall?.copyWith(
                            color: profile.isVerified
                                ? const Color(0xFF008B57)
                                : const Color(0xFF5D6889),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (profile.memberSince != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tham gia ${_date(profile.memberSince)}',
                      style: text.bodySmall?.copyWith(
                        color: const Color(0xFF5D6889),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              hasReviews ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 20,
              color: hasReviews
                  ? const Color(0xFFE9A000)
                  : const Color(0xFF969DB3),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasReviews
                    ? '$score · ${profile.reviewCount} đánh giá'
                    : 'Chưa có đánh giá',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
        const Divider(height: 40),
        Text(
          'Giới thiệu',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          profile.bio?.trim().isNotEmpty == true
              ? profile.bio!
              : 'Chưa thêm giới thiệu.',
          style: text.bodyMedium?.copyWith(
            height: 1.5,
            color: const Color(0xFF5D6889),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        ListTile(
          minTileHeight: 52,
          hoverColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.article_outlined),
          title: const Text('Bài viết'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => CompanionMyPostsScreen(userId: profile.id),
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 24),
        Text(
          'Thông tin',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _infoRow('Họ và tên', profile.fullName),
        const Divider(height: 1),
        _infoRow('Biệt danh', profile.nickname),
        const Divider(height: 1),
        _infoRow('Độ tuổi', profile.age == null ? null : '${profile.age} tuổi'),
        const Divider(height: 1),
      ],
    );
  }

  Widget _infoRow(String label, String? value) {
    final available = value?.trim().isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label)),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              available ? value! : 'Chưa cập nhật',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: available ? null : const Color(0xFF969DB3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _vm,
    builder: (context, _) => Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(hoverColor: Colors.transparent),
              )
            : null,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RefreshIndicator(
              onRefresh: () async {
                if (widget.userId.trim().isNotEmpty) {
                  await _vm.load(widget.userId);
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (_vm.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: LoadingIndicator(
                        message: 'Đang tải hồ sơ người dùng...',
                      ),
                    )
                  else if (_vm.profile != null)
                    _content(_vm.profile!)
                  else
                    ErrorState(
                      title: _vm.notFound
                          ? 'Không tìm thấy người dùng'
                          : 'Chưa tải được hồ sơ',
                      message:
                          _vm.errorMessage ?? 'Không thể tải hồ sơ người dùng.',
                      onRetry: widget.userId.trim().isEmpty
                          ? null
                          : () => _vm.load(widget.userId),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
