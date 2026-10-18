import 'package:flutter/material.dart';

import '../../../shared/ui_kit.dart';
import '../../review/views/blocked_users_screen.dart';
import '../models/profile_model.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'bank_accounts_screen.dart';
import 'edit_profile_screen.dart';
import 'ekyc_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = ProfileViewModel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadProfile();
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

  Widget _buildProfileHeader(ProfileModel profile) {
    return AppCard(
      softShadow: true,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarPlaceholder(
                name: profile.displayName,
                imageUrl: profile.avatarUrl,
                radius: 42,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(profile.email),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppStatusBadge(
                          label: profile.verificationLabel,
                          tone: _verificationTone(profile),
                          icon: Icons.verified_user_outlined,
                        ),
                        if (profile.isEmailVerified)
                          const AppStatusBadge(
                            label: 'Email đã xác thực',
                            tone: AppStatusTone.success,
                            icon: Icons.mark_email_read_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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

  Widget _buildStatistics() {
    final trustScore = _viewModel.trustScore;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final itemWidth = availableWidth >= 600
            ? (availableWidth - 24) / 3
            : (availableWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: SummaryTile(
                label: 'Điểm tín nhiệm',
                value: trustScore == null
                    ? '—'
                    : '${trustScore.trustScore.toStringAsFixed(1)}/5',
                icon: Icons.star_outline_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SummaryTile(
                label: 'Lượt đánh giá',
                value: trustScore == null ? '—' : '${trustScore.reviewCount}',
                icon: Icons.rate_review_outlined,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SummaryTile(
                label: 'Thành viên từ',
                value: _formatDate(trustScore?.memberSince),
                icon: Icons.calendar_month_outlined,
              ),
            ),
          ],
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
        _buildStatistics(),
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
