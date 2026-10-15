import 'package:flutter/material.dart';

import '../../../shared/ui_kit.dart';
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

  Widget _metric(String value, String label, IconData icon) => Expanded(
    child: AppCard(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .35),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _content(TrustScoreModel profile) {
    final name = profile.displayName.trim().isEmpty
        ? 'Người dùng'
        : profile.displayName;
    final hasReviews = profile.reviewCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          softShadow: true,
          child: Column(
            children: [
              AvatarPlaceholder(
                name: name,
                imageUrl: profile.avatarUrl,
                radius: 44,
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              AppStatusBadge(
                label: profile.isVerified
                    ? 'Đã xác minh danh tính'
                    : 'Chưa xác minh danh tính',
                icon: profile.isVerified
                    ? Icons.verified_outlined
                    : Icons.person_outline,
                tone: profile.isVerified
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
              ),
              const SizedBox(height: 12),
              Text(
                'Tham gia FeelingTrip: ${_date(profile.memberSince)}',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Thông tin cá nhân'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              _infoRow(Icons.person_outline, 'Họ và tên', profile.fullName),
              const Divider(height: 24),
              _infoRow(Icons.badge_outlined, 'Biệt danh', profile.nickname),
              const Divider(height: 24),
              _infoRow(
                Icons.cake_outlined,
                'Độ tuổi',
                profile.age == null ? null : '${profile.age} tuổi',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Giới thiệu'),
        const SizedBox(height: 10),
        AppCard(
          child: Text(
            profile.bio?.trim().isNotEmpty == true
                ? profile.bio!
                : 'Người dùng chưa thêm giới thiệu.',
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Điểm tín nhiệm',
          subtitle: 'Tổng hợp từ đánh giá bạn đồng hành.',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metric(
              hasReviews ? '${profile.trustScore.toStringAsFixed(1)}/5' : '—',
              'Điểm trung bình',
              Icons.star_outline_rounded,
            ),
            const SizedBox(width: 12),
            _metric(
              '${profile.reviewCount}',
              'Lượt đánh giá',
              Icons.rate_review_outlined,
            ),
          ],
        ),
        if (!hasReviews) ...[
          const SizedBox(height: 12),
          const Text('Chưa có đánh giá'),
        ],
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value?.trim().isNotEmpty == true ? value! : 'Chưa cập nhật',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _vm,
    builder: (context, _) => AppScaffold(
      title: 'Hồ sơ người dùng',
      scrollable: true,
      actions: [
        IconButton(
          tooltip: 'Tải lại hồ sơ',
          onPressed: _vm.isLoading || widget.userId.trim().isEmpty
              ? null
              : () => _vm.load(widget.userId),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _vm.isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: LoadingIndicator(
                    message: 'Đang tải hồ sơ người dùng...',
                  ),
                )
              : _vm.profile != null
              ? _content(_vm.profile!)
              : ErrorState(
                  title: _vm.notFound
                      ? 'Không tìm thấy người dùng'
                      : 'Chưa tải được hồ sơ',
                  message:
                      _vm.errorMessage ?? 'Không thể tải hồ sơ người dùng.',
                  onRetry: widget.userId.trim().isEmpty
                      ? null
                      : () => _vm.load(widget.userId),
                ),
        ),
      ),
    ),
  );
}
