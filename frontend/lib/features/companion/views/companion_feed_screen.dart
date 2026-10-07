import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/companion_feed_viewmodel.dart';
import 'companion_detail_screen.dart';
import 'widgets/companion_post_card.dart';
import 'widgets/companion_filter_sheet.dart';

class CompanionFeedScreen extends StatefulWidget {
  const CompanionFeedScreen({
    super.key,
    this.embedded = false,
    this.onProfileTap,
    this.active = true,
  });
  final bool embedded;
  final bool active;
  final VoidCallback? onProfileTap;
  @override
  State<CompanionFeedScreen> createState() => _CompanionFeedScreenState();
}

class _CompanionFeedScreenState extends State<CompanionFeedScreen> {
  final _vm = CompanionFeedViewModel();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    _vm.load();
  }

  @override
  void didUpdateWidget(covariant CompanionFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _vm.load(refresh: true);
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _vm.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _vm.loadMore();
    }
  }

  void _openFilter() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          child: CompanionFilterSheet(
            currentSortBy: _vm.sortBy,
            currentStatus: _vm.status,
            currentGender: _vm.genderPreference,
            onApply: ({sortBy, status, genderPreference}) => _vm.applyFilter(
              sortBy: sortBy,
              status: status,
              genderPreference: genderPreference,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    final filtered =
        _vm.sortBy != 'newest' ||
        _vm.status != 'OPEN' ||
        _vm.genderPreference.isNotEmpty;
    final body = ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      if (!widget.embedded && Navigator.canPop(context))
                        IconButton(
                          tooltip: 'Quay lại',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        IconButton(
                          tooltip: 'Mở trang cá nhân',
                          onPressed: widget.onProfileTap,
                          icon: AvatarPlaceholder(
                            name: user?.fullName ?? 'Bạn',
                            imageUrl: user?.avatarUrl,
                            radius: 16,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Tìm điểm đến...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            suffixIcon: _vm.destination.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Xóa tìm kiếm',
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _vm.applyFilter(destination: '');
                                    },
                                  ),
                          ),
                          onSubmitted: (value) =>
                              _vm.applyFilter(destination: value.trim()),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Bộ lọc',
                        onPressed: _openFilter,
                        icon: Badge(
                          isLabelVisible: filtered,
                          smallSize: 6,
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(backgroundColor: AppColors.surface, body: body);
  }

  Widget _buildBody() {
    if (_vm.isLoading) return const Center(child: LoadingIndicator());
    if (_vm.errorMessage != null) {
      return ErrorState(
        message: _vm.errorMessage!,
        onRetry: () => _vm.load(refresh: true),
      );
    }
    if (_vm.posts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.group_outlined,
        title: 'Chưa có bài đăng nào',
        message: 'Thử thay đổi điểm đến hoặc bộ lọc.',
        buttonText: 'Xóa bộ lọc',
        onButtonPressed: () {
          _searchController.clear();
          _vm.applyFilter(
            sortBy: 'newest',
            status: 'OPEN',
            genderPreference: '',
            destination: '',
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () => _vm.load(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _vm.posts.length + (_vm.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          if (index == _vm.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: LoadingIndicator()),
            );
          }
          final post = _vm.posts[index];
          return CompanionPostCard(
            post: post,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => CompanionDetailScreen(postId: post.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
