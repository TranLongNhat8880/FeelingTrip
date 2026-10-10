import 'package:flutter/material.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/models/user_model.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../companion/repositories/companion_trip_repository.dart';
import '../../companion/views/companion_feed_screen.dart';
import '../../companion/views/companion_requests_screen.dart';
import '../../companion/views/create_companion_post_screen.dart';
import '../../companion/models/companion_post_model.dart';
import '../../companion/repositories/mock_companion_repository.dart';
import '../../notification/viewmodels/notification_viewmodel.dart';
import '../../notification/views/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _notifications = NotificationViewModel();

  @override
  void initState() {
    super.initState();
    _notifications.addListener(_onNotificationsChanged);
    _notifications.load();
    _loadTrips();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifications.removeListener(_onNotificationsChanged);
    _notifications.dispose();
    super.dispose();
  }

  static const _titles = ['Trang chủ', 'Chuyến đi', 'Thông báo', 'Cá nhân'];
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _logoutPromptOpen = false;

  void _select(int index) {
    setState(() => _tab = index);
    if (index == 2) _notifications.load();
    if (index == 1) _loadTrips();
  }

  bool _loadingTrips = false;
  String? _tripError;
  List<Map<String, String>> _myTrips = [];
  static const _mockTrips = [
    {
      'id': 'trip-1',
      'name': 'Hành trình di sản Hội An – Đà Nẵng 4N3Đ',
      'destination': 'Hội An, Quảng Nam',
      'dates': '27/10 – 30/10/2026',
      'status': 'Sắp diễn ra',
      'image':
          'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=500&q=80',
    },
    {
      'id': 'trip-2',
      'name': 'Fansipan – Nóc nhà Đông Dương',
      'destination': 'Sapa, Lào Cai',
      'dates': '15/10 – 17/10/2026',
      'status': 'Sắp diễn ra',
      'image':
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=500&q=80',
    },
    {
      'id': 'trip-5',
      'name': 'Săn mây Đà Lạt 3 ngày cuối tuần',
      'destination': 'Đà Lạt, Lâm Đồng',
      'dates': '05/11 – 08/11/2026',
      'status': 'Lên kế hoạch',
      'image':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
    },
  ];

  Future<void> _loadTrips() async {
    if (ApiEndpoints.useMockData) {
      final trips = <Map<String, String>>[];
      for (final trip in _mockTrips) {
        trips.add({
          ...trip,
          'hasCompanionPost':
              '${await MockCompanionRepository().hasPostForTrip(trip['id']!)}',
        });
      }
      if (mounted) setState(() => _myTrips = trips);
      return;
    }
    setState(() {
      _loadingTrips = true;
      _tripError = null;
    });
    try {
      final trips = await CompanionTripRepository().getMyTrips();
      if (mounted) setState(() => _myTrips = trips);
    } catch (_) {
      if (mounted) setState(() => _tripError = 'Không tải được chuyến đi.');
    } finally {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  Future<void> _confirmLogout() async {
    final auth = AuthScope.of(context);
    if (_logoutPromptOpen || auth.isLoading) return;
    _logoutPromptOpen = true;
    try {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Bạn có muốn đăng xuất?',
        message:
            'Bạn có thể đăng nhập lại để tiếp tục hành trình cùng FeelingTrip.',
        confirmLabel: 'Đăng xuất',
      );
      if (!mounted || !confirmed) return;
      await auth.logout();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } finally {
      _logoutPromptOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final name = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : user.email.split('@').first;
    final text = Theme.of(context).textTheme;

    final legacyTabs = TravelBackdrop(
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Mở menu',
                        onPressed: () => _scaffold.currentState?.openDrawer(),
                        icon: const Icon(
                          Icons.menu_rounded,
                          size: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TravelBrand(width: 160),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mở trang cá nhân',
                        onPressed: () => _select(3),
                        icon: AvatarPlaceholder(
                          name: name,
                          imageUrl: user.avatarUrl,
                          radius: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_titles[_tab], style: text.headlineMedium),
                        const SizedBox(height: 8),
                        if (_tab == 1) ...[
                          // ── TAB 1: KẾ HOẠCH & CHUYẾN ĐI CỦA TÔI ──
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Kế hoạch của tôi',
                                  style: text.titleMedium,
                                ),
                              ),
                              Text(
                                '${_myTrips.length} chuyến đi',
                                style: text.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              CustomButton(
                                text: 'Quản lý',
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.tripList,
                                ),
                                variant: AppButtonVariant.text,
                                fullWidth: false,
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                tooltip: 'Khám phá địa điểm du lịch',
                                icon: const Icon(
                                  Icons.explore_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.places,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_loadingTrips) const LoadingIndicator(),
                          if (_tripError != null)
                            ErrorState(
                              message: _tripError!,
                              onRetry: _loadTrips,
                            ),
                          if (!_loadingTrips &&
                              _tripError == null &&
                              _myTrips.isEmpty)
                            AppCard(
                              outlined: true,
                              child: Column(
                                children: [
                                  const Text(
                                    'Chưa có chuyến đi đang hoạt động do bạn làm trưởng nhóm.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  CustomButton(
                                    text: 'Quản lý & Tạo chuyến đi',
                                    variant: AppButtonVariant.primary,
                                    icon: Icons.luggage_outlined,
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.tripList,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CustomButton(
                                    text: 'Khám phá kho địa điểm',
                                    variant: AppButtonVariant.secondary,
                                    icon: Icons.explore_rounded,
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.places,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ..._myTrips.map(
                            (trip) => _buildTripCard(context, trip, text),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Tiện ích cho chuyến đi',
                            style: text.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          AppCard(
                            outlined: true,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.places),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.explore_outlined,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Khám phá kho địa điểm du lịch',
                                        style: text.titleSmall,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Tra cứu danh lam, di tích và tính khoảng cách',
                                        style: text.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppCard(
                            outlined: true,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.expenses,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: Color(0xFF16A34A),
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sổ quỹ & Chia tiền nhóm (Split Bill)',
                                        style: text.titleSmall,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Tự động tính nợ và thanh toán mã VietQR ngân hàng',
                                        style: text.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ] else if (_tab == 3) ...[
                          // ── TAB 3: TRANG CÁ NHÂN & TRUY CẬP NHANH ──
                          const SizedBox(height: 16),
                          AppCard(
                            softShadow: true,
                            child: Column(
                              children: [
                                AvatarPlaceholder(
                                  name: name,
                                  imageUrl: user.avatarUrl,
                                  radius: 36,
                                ),
                                const SizedBox(height: 16),
                                Text(name, style: text.titleLarge),
                                const SizedBox(height: 8),
                                Text(
                                  user.email,
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Truy cập nhanh', style: text.titleSmall),
                          const SizedBox(height: 12),
                          AppCard(
                            outlined: true,
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.manage_accounts_outlined,
                                    color: AppColors.primary,
                                  ),
                                  title: const Text('Hồ sơ cá nhân'),
                                  subtitle: const Text(
                                    'Thông tin cá nhân, eKYC và tài khoản ngân hàng',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.profile,
                                  ),
                                ),
                                const Divider(height: 1, indent: 56),
                                ListTile(
                                  leading: const Icon(
                                    Icons.luggage_outlined,
                                    color: AppColors.primary,
                                  ),
                                  title: const Text('Chuyến đi của tôi'),
                                  subtitle: const Text(
                                    'Quản lý chuyến đi & lịch trình chi tiết',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.tripList,
                                  ),
                                ),
                                const Divider(height: 1, indent: 56),
                                ListTile(
                                  leading: const Icon(
                                    Icons.explore_outlined,
                                    color: AppColors.primary,
                                  ),
                                  title: const Text('Kho địa điểm du lịch'),
                                  subtitle: const Text(
                                    'Khám phá danh lam thắng cảnh',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.places,
                                  ),
                                ),
                                const Divider(height: 1, indent: 56),
                                ListTile(
                                  leading: const Icon(
                                    Icons.inbox_outlined,
                                    color: AppColors.warning,
                                  ),
                                  title: const Text(
                                    'Yêu cầu tham gia chuyến đi',
                                  ),
                                  subtitle: const Text(
                                    'Duyệt đơn ghép đoàn bạn đồng hành',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onTap: () => Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CompanionRequestsScreen(),
                                    ),
                                  ),
                                ),
                                if (user.isAdmin) ...[
                                  const Divider(height: 1, indent: 56),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.admin_panel_settings_outlined,
                                      color: Color(0xFF0284C7),
                                    ),
                                    title: const Text('Bảng điều khiển Admin'),
                                    subtitle: const Text(
                                      'Quản trị người dùng & địa điểm',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.admin,
                                    ),
                                  ),
                                  const Divider(height: 1, indent: 56),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.palette_outlined,
                                      color: Color(0xFF9333EA),
                                    ),
                                    title: const Text(
                                      'Thư viện UI Kit (Debug)',
                                    ),
                                    subtitle: const Text(
                                      'Xem toàn bộ component mẫu',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.uiKit,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (auth.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          CustomButton(
                            text: 'Đăng xuất',
                            isLoading: auth.isLoading,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.logout_rounded,
                            onPressed: _confirmLogout,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return AppScaffold(
      scaffoldKey: _scaffold,
      padding: EdgeInsets.zero,
      drawer: _buildDrawer(context, user, name, text),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _tab,
        onSelected: _select,
        items: [
          const AppNavigationItem(
            label: 'Trang chủ',
            icon: Icons.home_outlined,
          ),
          const AppNavigationItem(
            label: 'Chuyến đi',
            icon: Icons.luggage_outlined,
          ),
          AppNavigationItem(
            label: 'Thông báo',
            icon: Icons.notifications_none_rounded,
            unreadCount: _notifications.unreadCount,
          ),
          const AppNavigationItem(label: 'Cá nhân', icon: Icons.person_outline),
        ],
      ),
      body: IndexedStack(
        index: _tab == 0
            ? 0
            : _tab == 2
            ? 1
            : 2,
        children: [
          CompanionFeedScreen(
            embedded: true,
            active: _tab == 0,
            onProfileTap: () => _select(3),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth,
              ),
              child: NotificationScreen(viewModel: _notifications),
            ),
          ),
          if (_tab == 1 || _tab == 3) legacyTabs else const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    UserModel user,
    String name,
    TextTheme text,
  ) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TravelBrand(width: 190),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      AvatarPlaceholder(
                        name: name,
                        imageUrl: user.avatarUrl,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.email,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'KHÁM PHÁ & DU LỊCH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Bảng tin ghép đoàn'),
              selected: _tab == 0,
              selectedColor: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _select(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.luggage_outlined),
              title: const Text('Chuyến đi của tôi'),
              selected: _tab == 1,
              selectedColor: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.tripList);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.alt_route_rounded,
                color: Color(0xFF0D9488),
              ),
              title: const Text('Lịch trình cộng đồng'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.publicItineraries);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.explore_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Kho địa điểm du lịch'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.places);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.inbox_outlined,
                color: AppColors.warning,
              ),
              title: const Text('Yêu cầu ghép đoàn'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CompanionRequestsScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 20),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'CÔNG CỤ THÔNG MINH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF9333EA),
              ),
              title: const Text('Lên lịch trình AI'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.aiPlanner);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF16A34A),
              ),
              title: const Text('Sổ quỹ & Chia tiền'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.expenses);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded),
              title: const Text('Thông báo'),
              selected: _tab == 2,
              selectedColor: AppColors.primary,
              trailing: _notifications.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_notifications.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _select(2);
              },
            ),
            if (user.isAdmin) ...[
              const Divider(height: 20),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'HỆ THỐNG & QUẢN TRỊ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF0284C7),
                ),
                title: const Text('Bảng điều khiển Admin'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.admin);
                },
              ),
            ],
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    Map<String, String> trip,
    TextTheme text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        softShadow: true,
        onTap: () {
          final tripId = trip['id'];
          if (tripId != null && tripId.isNotEmpty) {
            Navigator.pushNamed(
              context,
              AppRoutes.tripDetail,
              arguments: tripId,
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    trip['image']!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 72,
                      height: 72,
                      color: AppColors.primarySurface,
                      child: const Icon(
                        Icons.luggage,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['name']!,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trip['destination']!,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trip['dates']!,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trip['status']!,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trip['hasCompanionPost'] != 'true')
                  CustomButton(
                    text: 'Tìm bạn đồng hành',
                    onPressed: () async {
                      if (AuthScope.of(context).user?.isVerified != true) {
                        await AppMessageDialog.show(
                          context,
                          title: 'Cần xác minh hồ sơ',
                          message:
                              'Bạn cần hoàn thành eKYC trước khi đăng bài tìm bạn đồng hành.',
                          tone: AppStatusTone.warning,
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      final post = await Navigator.push<CompanionPost>(
                        context,
                        MaterialPageRoute(
                          settings: RouteSettings(
                            name: AppRoutes.createCompanionPost,
                            arguments: {
                              'tripId': trip['id'],
                              'tripName': trip['name'],
                              'tripDestination': trip['destination'],
                            },
                          ),
                          builder: (_) => CreateCompanionPostScreen(
                            tripId: trip['id'],
                            tripName: trip['name'],
                            tripDestination: trip['destination'],
                          ),
                        ),
                      );
                      if (post != null && mounted) await _loadTrips();
                    },
                    icon: Icons.group_add_outlined,
                    variant: AppButtonVariant.secondary,
                    fullWidth: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
