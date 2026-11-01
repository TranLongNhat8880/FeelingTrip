import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui_kit.dart';
import '../../review/views/blocked_users_screen.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'bank_accounts_screen.dart';
import 'edit_profile_screen.dart';
import 'ekyc_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.repository});
  final ProfileRepository? repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = ProfileViewModel(repository: widget.repository);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.loadProfile();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openEditProfile(ProfileModel profile) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(viewModel: _viewModel, initialProfile: profile),
      ),
    );

    if (updated == true) {
      await _viewModel.loadProfile();
    }
  }

  Future<void> _openEkyc(ProfileModel profile) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EkycScreen(viewModel: _viewModel, initialProfile: profile),
      ),
    );
  }

  Future<void> _openBankAccounts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountsScreen(viewModel: _viewModel),
      ),
    );
  }

  Future<void> _openBlockedUsers() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
    );
  }

  AppStatusTone _verificationTone(ProfileModel profile) {
    if (profile.isEkycVerified) {
      return AppStatusTone.success;
    }

    if (profile.isEkycPending) {
      return AppStatusTone.warning;
    }

    if (profile.isEkycRejected) {
      return AppStatusTone.error;
    }

    return AppStatusTone.neutral;
  }

  String _displayValue(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return 'Chưa cập nhật';
    }

    return text;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Chưa cập nhật';
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day/$month/${local.year}';
  }

  Future<void> _copyUserId(String userId) async {
    final text = userId.trim();
    if (text.isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      AppFeedback.show(
        context,
        'Đã sao chép User ID.',
        tone: AppStatusTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        'Không thể sao chép User ID.',
        tone: AppStatusTone.error,
      );
    }
  }

  Widget _buildProfileHeader(ProfileModel profile) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      softShadow: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AvatarPlaceholder(
                  name: profile.displayName,
                  imageUrl: profile.avatarUrl,
                  radius: constraints.maxWidth < 360 ? 30 : 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: text.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Tooltip(
                        message: profile.email,
                        child: Text(
                          profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(fontSize: 13),
                        ),
                      ),
                      if (profile.id.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _copyUserId(profile.id),
                          borderRadius: BorderRadius.circular(4),
                          child: Tooltip(
                            message: 'Sao chép User ID (${profile.id})',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'ID: ${profile.id}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AppStatusBadge(
                            label: profile.verificationLabel,
                            tone: _verificationTone(profile),
                            icon: Icons.verified_user_outlined,
                            compact: true,
                          ),
                          if (profile.isEmailVerified)
                            const AppStatusBadge(
                              label: 'Email đã xác thực',
                              tone: AppStatusTone.success,
                              icon: Icons.mark_email_read_outlined,
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CustomButton(
            text: 'Chỉnh sửa hồ sơ',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => _openEditProfile(profile),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(ProfileModel profile) {
    final trustScore = _viewModel.trustScore;
    final memberSince = trustScore?.memberSince ?? profile.createdAt;
    final values = [
      trustScore == null
          ? '—'
          : '${trustScore.trustScore.toStringAsFixed(1)}/5',
      trustScore == null ? '—' : '${trustScore.reviewCount}',
      memberSince == null ? '—' : _formatDate(memberSince),
    ];
    final baseStyle = Theme.of(context).textTheme.titleLarge!.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Every tile uses the same font size. Fitting each value separately
        // makes dates smaller than the other statistics even with equal styles.
        final valueWidth = (constraints.maxWidth - 16) / 3 - 20 - 0.5;
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.localeOf(context),
          maxLines: 1,
        );
        bool fits(double size) {
          for (final value in values) {
            painter.text = TextSpan(
              text: value,
              style: baseStyle.copyWith(fontSize: size),
            );
            painter.layout();
            if (painter.width > valueWidth) return false;
          }
          return true;
        }

        var fontSize = 22.0;
        try {
          if (!fits(fontSize)) {
            var lower = 0.0;
            var upper = fontSize;
            for (var i = 0; i < 12; i++) {
              final middle = (lower + upper) / 2;
              if (fits(middle)) {
                lower = middle;
              } else {
                upper = middle;
              }
            }
            fontSize = lower;
          }
        } finally {
          painter.dispose();
        }
        final valueStyle = baseStyle.copyWith(fontSize: fontSize);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SummaryTile(
                  compact: true,
                  label: 'Điểm tín nhiệm',
                  value: values[0],
                  valueStyle: valueStyle,
                  icon: Icons.star_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryTile(
                  compact: true,
                  label: 'Lượt đánh giá',
                  value: values[1],
                  valueStyle: valueStyle,
                  icon: Icons.rate_review_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryTile(
                  compact: true,
                  label: 'Thành viên từ',
                  value: values[2],
                  valueStyle: valueStyle,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalInformation(ProfileModel profile) {
    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thông tin cá nhân',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          InfoRow(
            label: 'User ID',
            value: _displayValue(profile.id),
            icon: Icons.fingerprint_rounded,
            onTap: profile.id.trim().isNotEmpty
                ? () => _copyUserId(profile.id)
                : null,
            trailing: profile.id.trim().isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Sao chép User ID',
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () => _copyUserId(profile.id),
                  )
                : null,
          ),
          InfoRow(
            label: 'Họ và tên',
            value: _displayValue(profile.fullName),
            icon: Icons.person_outline_rounded,
          ),
          InfoRow(
            label: 'Biệt danh',
            value: _displayValue(profile.nickname),
            icon: Icons.badge_outlined,
          ),
          InfoRow(
            label: 'Số điện thoại',
            value: _displayValue(profile.phone),
            icon: Icons.phone_outlined,
          ),
          InfoRow(
            label: 'Ngày sinh',
            value: _formatDate(profile.dob),
            icon: Icons.cake_outlined,
          ),
          InfoRow(
            label: 'Giới tính',
            value: profile.genderLabel,
            icon: Icons.people_outline_rounded,
          ),
          InfoRow(
            label: 'Vai trò',
            value: profile.isAdmin ? 'Quản trị viên' : 'Người dùng',
            icon: Icons.shield_outlined,
          ),
          const Divider(height: 28),
          Text('Giới thiệu', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(_displayValue(profile.bio)),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return AppCard(
      outlined: true,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(radius: 24, child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ?? const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  Widget _buildFeatureActions(ProfileModel profile) {
    final bankName = profile.bankName?.trim();
    final hasReceivingAccount = profile.bankAccountNumber?.isNotEmpty ?? false;
    final bankSubtitle = !hasReceivingAccount
        ? 'Chưa lưu thông tin nhận tiền'
        : 'Thông tin nhận tiền: ${bankName == null || bankName.isEmpty ? 'đã lưu' : bankName}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Tài khoản và xác minh',
          subtitle: 'Quản lý danh tính và thông tin nhận thanh toán.',
        ),
        const SizedBox(height: 14),

        _buildFeatureTile(
          title: 'Xác minh danh tính eKYC',
          subtitle: profile.verificationLabel,
          icon: Icons.verified_user_outlined,
          onTap: () => _openEkyc(profile),
          trailing: AppStatusBadge(
            label: profile.isEkycVerified
                ? 'Đã duyệt'
                : profile.isEkycPending
                ? 'Đang chờ'
                : profile.isEkycRejected
                ? 'Nộp lại'
                : 'Thực hiện',
            tone: _verificationTone(profile),
          ),
        ).koharu('profile.ekyc'),
        const SizedBox(height: 12),

        _buildFeatureTile(
          title: 'Tài khoản ngân hàng',
          subtitle: bankSubtitle,
          icon: Icons.account_balance_outlined,
          onTap: _openBankAccounts,
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'An toàn và quyền riêng tư',
          subtitle: 'Quản lý những tài khoản không thể tương tác với bạn.',
        ),
        const SizedBox(height: 14),
        _buildFeatureTile(
          title: 'Người dùng đã chặn',
          subtitle: 'Xem và bỏ chặn tài khoản',
          icon: Icons.person_off_outlined,
          onTap: _openBlockedUsers,
        ),
      ],
    );
  }

  Widget _buildProfileContent(ProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileHeader(profile),
        const SizedBox(height: 16),
        _buildStatistics(profile),
        const SizedBox(height: 24),
        _buildFeatureActions(profile),
        const SizedBox(height: 24),
        _buildPersonalInformation(profile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final profile = _viewModel.profile;

        Widget content;

        if (_viewModel.isLoadingProfile && profile == null) {
          content = const Padding(
            padding: EdgeInsets.symmetric(vertical: 100),
            child: LoadingIndicator(message: 'Đang tải hồ sơ cá nhân...'),
          );
        } else if (profile == null) {
          content = ErrorState(
            message: _viewModel.errorMessage ?? 'Không thể tải hồ sơ cá nhân.',
            onRetry: _viewModel.loadProfile,
          );
        } else {
          content = _buildProfileContent(profile);
        }

        return AppScaffold(
          title: 'Hồ sơ cá nhân',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          scrollable: true,
          actions: [
            IconButton(
              tooltip: 'Tải lại hồ sơ',
              onPressed: _viewModel.isLoadingProfile
                  ? null
                  : _viewModel.loadProfile,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
