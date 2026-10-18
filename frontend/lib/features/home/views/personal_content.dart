import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/models/user_model.dart';
import '../../admin/views/plan_library_screen.dart';
import '../../companion/views/companion_my_posts_screen.dart';
import '../../companion/views/companion_requests_screen.dart';

class PersonalContent extends StatelessWidget {
  const PersonalContent({
    super.key,
    required this.user,
    required this.onLogout,
    this.loading = false,
    this.error,
  });
  final UserModel user;
  final VoidCallback onLogout;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : user.email.split('@').first;
    return ColoredBox(
      color: AppColors.inputSurface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                AppCard(
                  onTap: () {
                    KoharuScope.maybeOf(context)?.tapped('profile.open');
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                  child: Row(
                    children: [
                      AvatarPlaceholder(
                        name: name,
                        imageUrl: user.avatarUrl,
                        radius: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: text.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            AppStatusBadge(
                              label: user.hasVerifiedEkyc
                                  ? 'Đã xác minh eKYC'
                                  : user.verificationStatus == 'PENDING'
                                  ? 'Đang chờ xác minh'
                                  : 'Chưa xác minh eKYC',
                              tone: user.hasVerifiedEkyc
                                  ? AppStatusTone.success
                                  : AppStatusTone.warning,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Cài đặt',
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PersonalSettingsScreen(onLogout: onLogout),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).koharu('profile.open'),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      _shortcut(
                        context,
                        'Bài tuyển',
                        Icons.article_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CompanionMyPostsScreen(),
                          ),
                        ),
                      ),
                      _shortcut(
                        context,
                        'Yêu cầu',
                        Icons.send_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CompanionRequestsScreen(),
                          ),
                        ),
                      ),
                      _shortcut(
                        context,
                        'Lời mời',
                        Icons.mail_outline,
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.tripInvitations,
                        ),
                      ),
                      _shortcut(
                        context,
                        'Chuyến đi',
                        Icons.luggage_outlined,
                        () => Navigator.pushNamed(context, AppRoutes.tripList),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Khám phá & lên kế hoạch', style: text.titleSmall),
                const SizedBox(height: 10),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _entry(
                        context,
                        'Lịch trình mẫu',
                        'Gợi ý lịch trình cho chuyến đi tiếp theo',
                        Icons.route_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PlanLibraryScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 60, endIndent: 16),
                      _entry(
                        context,
                        'Lịch trình cộng đồng',
                        'Tham khảo các chuyến đi đã hoàn thành',
                        Icons.public_outlined,
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.publicItineraries,
                        ),
                      ),
                      const Divider(height: 1, indent: 60, endIndent: 16),
                      _entry(
                        context,
                        'Kho địa điểm du lịch',
                        'Tra cứu địa điểm và bản đồ',
                        Icons.explore_outlined,
                        () => Navigator.pushNamed(context, AppRoutes.places),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _entry(
                    context,
                    'Sổ quỹ & chia tiền',
                    'Chi phí và thanh toán trong chuyến đi',
                    Icons.account_balance_wallet_outlined,
                    () => Navigator.pushNamed(context, AppRoutes.expenses),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Tài khoản', style: text.titleSmall),
                const SizedBox(height: 10),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _entry(
                        context,
                        'Hồ sơ cá nhân',
                        'Thông tin, xác minh và tài khoản ngân hàng',
                        Icons.manage_accounts_outlined,
                        () => Navigator.pushNamed(context, AppRoutes.profile),
                      ),
                      const Divider(height: 1, indent: 60, endIndent: 16),
                      _entry(
                        context,
                        'Lời mời của tôi',
                        'Xem và phản hồi lời mời tham gia chuyến đi',
                        Icons.mail_outline,
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.tripInvitations,
                        ),
                      ),
                      if (user.isAdmin) ...[
                        const Divider(height: 1, indent: 60, endIndent: 16),
                        _entry(
                          context,
                          'Bảng điều khiển Admin',
                          'Tài khoản, kiểm duyệt và thư viện',
                          Icons.admin_panel_settings_outlined,
                          () => Navigator.pushNamed(context, AppRoutes.admin),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (error != null)
                  AppInlineNotice(message: error!, tone: AppStatusTone.error),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortcut(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );

  Widget _entry(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Text(
      subtitle,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      size: 20,
      color: AppColors.textSecondary,
    ),
    onTap: onTap,
  );
}

class PersonalSettingsScreen extends StatelessWidget {
  const PersonalSettingsScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Cài đặt',
    body: ListView(
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Hồ sơ cá nhân'),
                subtitle: const Text(
                  'Thông tin, xác minh và tài khoản ngân hàng',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Điều khoản sử dụng'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ),
      ],
    ),
  );
}
