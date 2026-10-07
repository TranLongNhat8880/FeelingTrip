import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../models/place_model.dart';
import '../viewmodels/admin_place_viewmodel.dart';
import 'admin_place_form_screen.dart';

// ============================================================================
// ADMIN CONTENT: Quản lý kho địa điểm
//
// Không chứa Scaffold/sidebar để có thể nhúng vào giao diện Admin của Tùng.
// ============================================================================

class AdminPlaceManagementContent extends StatefulWidget {
  const AdminPlaceManagementContent({
    super.key,
    this.onCreatePlace,
    this.onEditPlace,
  });

  final VoidCallback? onCreatePlace;
  final ValueChanged<PlaceModel>? onEditPlace;

  @override
  State<AdminPlaceManagementContent> createState() =>
      _AdminPlaceManagementContentState();
}

class _AdminPlaceManagementContentState
    extends State<AdminPlaceManagementContent> {
  late final AdminPlaceViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _viewModel = AdminPlaceViewModel();
    _viewModel.loadPlaces();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  bool? get _isActiveFilter {
    return switch (_statusFilter) {
      'active' => true,
      'hidden' => false,
      _ => null,
    };
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _viewModel.applyFilters(
        keyword: value,
        category: _viewModel.category,
        isActive: _isActiveFilter,
        sortBy: _viewModel.sortBy,
      );
    });
  }

  void _changeStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
    });

    _viewModel.applyFilters(
      keyword: _searchController.text,
      category: _viewModel.category,
      isActive: _isActiveFilter,
      sortBy: _viewModel.sortBy,
    );
  }

  Future<void> _openCreatePlace() async {
    if (widget.onCreatePlace != null) {
      widget.onCreatePlace!();
      return;
    }

    final createdPlace = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute<PlaceModel>(
        builder: (_) => const AdminPlaceFormScreen(),
      ),
    );

    if (!mounted || createdPlace == null) return;

    AppFeedback.show(
      context,
      'Đã thêm địa điểm ${createdPlace.name}.',
      tone: AppStatusTone.success,
    );

    await _viewModel.loadPlaces();
  }

  Future<void> _openEditPlace(PlaceModel place) async {
    if (widget.onEditPlace != null) {
      widget.onEditPlace!(place);
      return;
    }

    final updatedPlace = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute<PlaceModel>(
        builder: (_) => AdminPlaceFormScreen(initialPlace: place),
      ),
    );

    if (!mounted || updatedPlace == null) return;

    AppFeedback.show(
      context,
      'Đã cập nhật địa điểm ${updatedPlace.name}.',
      tone: AppStatusTone.success,
    );

    await _viewModel.loadPlaces();
  }

  Future<void> _toggleStatus(PlaceModel place) async {
    final nextStatus = !place.isActive;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: nextStatus ? 'Khôi phục địa điểm?' : 'Ẩn địa điểm?',
      message: nextStatus
          ? '${place.name} sẽ xuất hiện trở lại với người dùng.'
          : '${place.name} sẽ không còn xuất hiện trong tìm kiếm công khai.',
      confirmLabel: nextStatus ? 'Khôi phục' : 'Ẩn địa điểm',
      destructive: !nextStatus,
    );

    if (!mounted || !confirmed) return;

    final success = await _viewModel.togglePlaceStatus(place);

    if (!mounted) return;

    if (success) {
      AppFeedback.show(
        context,
        nextStatus ? 'Đã khôi phục địa điểm.' : 'Đã ẩn địa điểm.',
        tone: AppStatusTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Kho địa điểm',
              subtitle: '${_viewModel.totalItems} địa điểm trong hệ thống',
              action: CustomButton(
                text: 'Thêm địa điểm',
                icon: Icons.add_location_alt_outlined,
                width: 180,
                onPressed: _openCreatePlace,
              ),
            ),
            const SizedBox(height: AppSizes.spaceL),
            AppSearchField(
              controller: _searchController,
              hint: 'Tìm tên, địa chỉ hoặc thành phố...',
              isLoading: _viewModel.isLoading,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: AppSizes.spaceM),
            AppChoiceChips<String>(
              options: const {
                'all': 'Tất cả',
                'active': 'Đang hiển thị',
                'hidden': 'Đã ẩn',
              },
              selected: {_statusFilter},
              enabled: !_viewModel.isLoading,
              onChanged: _changeStatusFilter,
            ),
            if (_viewModel.errorMessage != null && _viewModel.hasPlaces) ...[
              const SizedBox(height: AppSizes.spaceM),
              AppInlineNotice(
                message: _viewModel.errorMessage!,
                tone: AppStatusTone.error,
              ),
            ],
            const SizedBox(height: AppSizes.spaceM),
            Expanded(child: _buildBody()),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && !_viewModel.hasPlaces) {
      return const LoadingIndicator(message: 'Đang tải kho địa điểm...');
    }

    if (_viewModel.errorMessage != null && !_viewModel.hasPlaces) {
      return ErrorState(
        message: _viewModel.errorMessage!,
        accessDenied: _viewModel.errorMessage!.toLowerCase().contains(
          'permission',
        ),
        onRetry: _viewModel.loadPlaces,
      );
    }

    if (!_viewModel.hasPlaces) {
      return const EmptyStateWidget(
        icon: Icons.location_off_outlined,
        title: 'Không có địa điểm phù hợp',
        message: 'Hãy thử từ khóa hoặc trạng thái khác.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _viewModel.loadPlaces,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _viewModel.places.length + 1,
        separatorBuilder: (_, index) => index < _viewModel.places.length - 1
            ? const SizedBox(height: AppSizes.spaceM)
            : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index == _viewModel.places.length) {
            return PaginationFooter(
              isLoading: _viewModel.isLoadingMore,
              hasMore: _viewModel.hasMore,
              errorMessage: _viewModel.errorMessage,
              onLoadMore: _viewModel.loadMore,
            );
          }

          return _buildPlaceCard(_viewModel.places[index]);
        },
      ),
    );
  }

  Widget _buildPlaceCard(PlaceModel place) {
    final isUpdating = _viewModel.isUpdating(place.id);

    return AppCard(
      outlined: true,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: AppImage(
                  url: place.imageUrl,
                  aspectRatio: 1,
                  semanticLabel: 'Ảnh ${place.name}',
                ),
              ),
              const SizedBox(width: AppSizes.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.spaceXS),
                    Text(
                      place.displayLocation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceS),
                    Wrap(
                      spacing: AppSizes.spaceS,
                      runSpacing: AppSizes.spaceS,
                      children: [
                        AppStatusBadge(
                          label: place.isActive ? 'Đang hiển thị' : 'Đã ẩn',
                          tone: place.isActive
                              ? AppStatusTone.success
                              : AppStatusTone.warning,
                          icon: place.isActive
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        AppStatusBadge(
                          label: _categoryLabel(place.category),
                          tone: AppStatusTone.info,
                          icon: Icons.category_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceM),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Sửa địa điểm',
                onPressed: isUpdating ? null : () => _openEditPlace(place),
              ),
              const SizedBox(width: AppSizes.spaceS),
              AppIconButton(
                icon: place.isActive
                    ? Icons.visibility_off_outlined
                    : Icons.restore_outlined,
                tooltip: place.isActive ? 'Ẩn địa điểm' : 'Khôi phục địa điểm',
                backgroundColor: place.isActive
                    ? AppColors.errorSurface
                    : AppColors.successSurface,
                foregroundColor: place.isActive
                    ? AppColors.error
                    : AppColors.success,
                onPressed: isUpdating ? null : () => _toggleStatus(place),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'ATTRACTION' => 'Tham quan',
      'RESTAURANT' => 'Ăn uống',
      'CAFE' => 'Cà phê',
      'HOTEL' => 'Khách sạn',
      'ENTERTAINMENT' => 'Giải trí',
      'NATURE' => 'Thiên nhiên',
      'CULTURE' => 'Văn hóa',
      'SHOPPING' => 'Mua sắm',
      _ => 'Khác',
    };
  }
}
