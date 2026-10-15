import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../viewmodels/companion_feed_viewmodel.dart';
import 'companion_detail_screen.dart';
import 'companion_search_screen.dart';
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
    final filtered =
        _vm.sortBy != 'newest' ||
        _vm.status != 'OPEN' ||
        _vm.genderPreference.isNotEmpty;
    final body = ColoredBox(
      color: const Color(0xFFF5F6F7),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Row(
                    children: [
                      if (!widget.embedded && Navigator.canPop(context))
                        IconButton(
                          tooltip: 'Quay lại',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      if (!widget.embedded && Navigator.canPop(context))
                        const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Tìm điểm đến du lịch',
                          child: Material(
                            color: AppColors.inputSurface,
                            borderRadius: BorderRadius.circular(28),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CompanionSearchScreen(
                                    destinations: _vm.posts
                                        .map((p) => p.trip.destination ?? '')
                                        .where((d) => d.isNotEmpty)
                                        .toList(),
                                    sortBy: _vm.sortBy,
                                    status: _vm.status,
                                    genderPreference: _vm.genderPreference,
                                  ),
                                ),
                              ),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color: AppColors.textHint,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Tìm điểm đến du lịch...',
                                        style: TextStyle(
                                          color: AppColors.textHint,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: filtered
                              ? AppColors.primarySurface
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: filtered
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: IconButton(
                          tooltip: 'Bộ lọc',
                          onPressed: _openFilter,
                          icon: Badge(
                            isLabelVisible: filtered,
                            smallSize: 8,
                            child: const Icon(
                              Icons.tune_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: Color(0xFFE5E7EB),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.embedded
        ? body
        : AppScaffold(padding: EdgeInsets.zero, body: body);
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
        separatorBuilder: (_, _) =>
            const Divider(height: 1, thickness: 1, color: AppColors.border),
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
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CompanionDetailScreen(postId: post.id),
                ),
              );
              if (mounted) await _vm.load(refresh: true);
            },
          );
        },
      ),
    );
  }
}
