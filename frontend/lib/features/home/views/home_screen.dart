import '../../../core/constants/api_endpoints.dart';
import '../../companion/repositories/companion_trip_repository.dart';
import '../../../core/constants/app_assets.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../companion/views/companion_feed_screen.dart';
import '../../companion/views/companion_requests_screen.dart';
import '../../notification/views/notification_screen.dart';
import '../../notification/viewmodels/notification_viewmodel.dart';

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
    if (index == 1) {
      Navigator.pushNamed(context, AppRoutes.tripList);
      return;
    }
    setState(() => _tab = index);
    if (index == 2) _notifications.load();
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
      _myTrips = List.of(_mockTrips);
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
    final legacyTabs = Scaffold(
      key: _scaffold,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: const TravelBrand(width: 210),
              ),
              for (var i = 0; i < _titles.length; i++)
                ListTile(
                  title: Text(_titles[i]),
                  selected: i == _tab,
                  selectedColor: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _select(i);
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.group_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Tìm bạn đồng hành'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.companionFeed);
                },
              ),
            ],
          ),
        ),
      ),
      body: TravelBackdrop(
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
                          onPressed: () => _scaffold.currentState!.openDrawer(),
                          icon: const Icon(
                            Icons.menu_rounded,
                            size: 24,
                            color: Color(0xFF09143B),
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
                          Text(
                            _tab == 0 ? 'Cùng nhau khám phá' : _titles[_tab],
                            style: text.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          if (_tab == 0) ...[
                            Text(
                              'Xin chào, $name!',
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Text(
                              'Cảm hứng cho hành trình',
                              style: text.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            const SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _Category(
                                    label: 'Thiên nhiên',
                                    url:
                                        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=240&q=80',
                                  ),
                                  SizedBox(width: 14),
                                  _Category(
                                    label: 'Biển đảo',
                                    url:
                                        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=240&q=80',
                                  ),
                                  SizedBox(width: 14),
                                  _Category(
                                    label: 'Núi rừng',
                                    url:
                                        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=240&q=80',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppSizes.cardRadius,
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.asset(
                                      AppAssets.coastalBackground,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: .65),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      112,
                                      18,
                                      18,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        'Mỗi chuyến đi,\nmột câu chuyện mới.',
                                        style: text.titleLarge?.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppCard(
                              softShadow: true,
                              onTap: () => _select(1),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primarySurface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.luggage_outlined,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Chuyến đi của tôi',
                                          style: text.titleSmall,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Lịch trình và những người đồng hành',
                                          style: text.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppCard(
                              softShadow: true,
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.companionFeed,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primarySurface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.group_outlined,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Tìm bạn đồng hành',
                                              style: text.titleSmall,
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'MỚI',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Kết nối nhóm, cùng chia sẻ chuyến đi & chi phí',
                                          style: text.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Lên kế hoạch cùng FeelingTrip',
                              style: text.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            AppCard(
                              outlined: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sẵn sàng cho hành trình tiếp theo?',
                                    style: text.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lưu lịch trình, kết nối bạn đồng hành và quản lý chi tiêu trong chuyến đi.',
                                    style: text.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  CustomButton(
                                    text: 'Xem chuyến đi',
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () => _select(1),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_tab == 3) ...[
                            const SizedBox(height: 20),
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
                            const SizedBox(height: 24),
                            if (auth.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  auth.errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            CustomButton(
                              text: 'Đăng xuất',
                              isLoading: auth.isLoading,
                              variant: AppButtonVariant.secondary,
                              onPressed: _confirmLogout,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              icon: const Icon(Icons.inbox_outlined),
                              label: const Text('Yêu cầu tham gia chuyến đi'),
                              onPressed: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CompanionRequestsScreen(),
                                ),
                              ),
                            ),
                          ] else if (_tab == 1) ...[
                            // ── Tab Chuyến đi của tôi ──
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kế hoạch của tôi',
                                  style: text.titleMedium,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_myTrips.length} chuyến đi',
                                      style: text.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.tripList,
                                      ),
                                      child: const Text('Quản lý'),
                                    ),
                                  ],
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
                              const Text(
                                'Chưa có chuyến đi đang hoạt động do bạn làm trưởng nhóm.',
                              ),
                            ..._myTrips.map(
                              (trip) => _buildTripCard(context, trip, text),
                            ),
                          ] else ...[
                            const SizedBox(height: 40),
                            const EmptyStateWidget(
                              icon: Icons.notifications_none_rounded,
                              title: 'Thông báo của bạn',
                              message:
                                  'Tính năng thông báo đang được phát triển.',
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
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _tab,
        onSelected: _select,
        items: [
          AppNavigationItem(label: 'Trang chủ', icon: Icons.home_outlined),
          AppNavigationItem(label: 'Chuyến đi', icon: Icons.luggage_outlined),
          AppNavigationItem(
            label: 'Thông báo',
            icon: Icons.notifications_none_rounded,
            unreadCount: _notifications.unreadCount,
          ),
          AppNavigationItem(label: 'Cá nhân', icon: Icons.person_outline),
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.group_add_outlined, size: 16),
                  label: const Text('Tìm bạn đồng hành'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () async {
                    if (AuthScope.of(context).user?.hasVerifiedEkyc != true) {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cần xác minh hồ sơ'),
                          content: const Text(
                            'Bạn cần hoàn thành eKYC trước khi đăng bài tìm bạn đồng hành.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Đã hiểu'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    if (!context.mounted) return;
                    Navigator.pushNamed(
                      context,
                      AppRoutes.createCompanionPost,
                      arguments: {
                        'tripId': trip['id'],
                        'tripName': trip['name'],
                        'tripDestination': trip['destination'],
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Category extends StatelessWidget {
  const _Category({required this.label, required this.url});
  final String label;
  final String url;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 90,
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: SizedBox(height: 78, width: 90, child: _TravelImage(url: url)),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _TravelImage extends StatelessWidget {
  const _TravelImage({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    frameBuilder: (context, child, frame, synchronous) =>
        frame != null || synchronous
        ? child
        : const ColoredBox(
            color: AppColors.primarySurface,
            child: Center(
              child: Icon(Icons.landscape_outlined, color: AppColors.primary),
            ),
          ),
    errorBuilder: (_, _, _) => const ColoredBox(
      color: AppColors.primarySurface,
      child: Center(
        child: Icon(Icons.landscape_outlined, color: AppColors.primary),
      ),
    ),
  );
}
