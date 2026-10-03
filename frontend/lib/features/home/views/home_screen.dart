import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  static const _titles = ['Trang chủ', 'Chuyến đi', 'Thông báo', 'Cá nhân'];
  final _scaffold = GlobalKey<ScaffoldState>();
  void _select(int index) => setState(() => _tab = index);
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user!;
    final name = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : user.email.split('@').first;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: _scaffold,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('FeelingTrip', style: text.titleLarge),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _tab,
        onSelected: _select,
        items: const [
          AppNavigationItem(label: 'Trang chủ', icon: Icons.home_outlined),
          AppNavigationItem(label: 'Chuyến đi', icon: Icons.luggage_outlined),
          AppNavigationItem(
            label: 'Thông báo',
            icon: Icons.notifications_none_rounded,
          ),
          AppNavigationItem(label: 'Cá nhân', icon: Icons.person_outline),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Mở menu',
                        onPressed: () => _scaffold.currentState!.openDrawer(),
                        icon: const Icon(Icons.menu_rounded, size: 22),
                      ),
                      Expanded(
                        child: Text('FeelingTrip', style: text.titleMedium),
                      ),
                      IconButton(
                        tooltip: 'Mở trang cá nhân',
                        onPressed: () => _select(3),
                        icon: AvatarPlaceholder(
                          name: name,
                          imageUrl: user.avatarUrl,
                          radius: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                    Text('Cảm hứng cho hành trình', style: text.titleSmall),
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
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: _TravelImage(
                              url:
                                  'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1200&q=85',
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
                            padding: const EdgeInsets.fromLTRB(18, 112, 18, 18),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    CustomButton(
                      text: 'Đăng xuất',
                      isLoading: auth.isLoading,
                      variant: AppButtonVariant.secondary,
                      onPressed: auth.logout,
                    ),
                  ] else ...[
                    const SizedBox(height: 40),
                    EmptyStateWidget(
                      icon: _tab == 1
                          ? Icons.luggage_outlined
                          : Icons.notifications_none_rounded,
                      title: _tab == 1
                          ? 'Sẵn sàng cho hành trình mới'
                          : 'Thông báo của bạn',
                      message: _tab == 1
                          ? 'Tính năng quản lý chuyến đi đang được phát triển và sẽ xuất hiện tại đây.'
                          : 'Tính năng thông báo đang được phát triển.',
                    ),
                  ],
                ],
              ),
            ),
          ),
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
