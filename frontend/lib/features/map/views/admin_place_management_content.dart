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
  const AdminPlaceManagementContent({super.key});

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
  String? _selectedCategory;

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
        category: _selectedCategory,
        isActive: _isActiveFilter,
        sortBy: _viewModel.sortBy,
      );
    });
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });

    _viewModel.applyFilters(
      keyword: _searchController.text,
      category: category,
      isActive: _isActiveFilter,
      sortBy: _viewModel.sortBy,
    );
  }

  void _changeStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
    });

    _viewModel.applyFilters(
      keyword: _searchController.text,
      category: _selectedCategory,
      isActive: _isActiveFilter,
      sortBy: _viewModel.sortBy,
    );
  }

  Future<void> _openCreatePlace() async {
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
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _viewModel.loadPlaces,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Kho địa điểm',
                      subtitle:
                          '${_viewModel.totalItems} địa điểm trong hệ thống',
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
                    _buildCategoryList(),
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
                    if (_viewModel.errorMessage != null &&
                        _viewModel.hasPlaces) ...[
                      const SizedBox(height: AppSizes.spaceM),
                      AppInlineNotice(
                        message: _viewModel.errorMessage!,
                        tone: AppStatusTone.error,
                      ),
                    ],
                    const SizedBox(height: AppSizes.spaceM),
                  ],
                ),
              ),
              ..._buildBodySlivers(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _adminCategories.length; index++) ...[
            AppCategoryPill(
              label: _adminCategories[index].label,
              icon: _adminCategories[index].icon,
              selected: _selectedCategory == _adminCategories[index].value,
              onTap: () => _selectCategory(_adminCategories[index].value),
            ),
            if (index < _adminCategories.length - 1)
              const SizedBox(width: AppSizes.spaceS),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildBodySlivers() {
    if (_viewModel.isLoading && !_viewModel.hasPlaces) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingIndicator(message: 'Đang tải kho địa điểm...'),
        ),
      ];
    }

    if (_viewModel.errorMessage != null && !_viewModel.hasPlaces) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: _viewModel.errorMessage!,
            accessDenied: _viewModel.errorMessage!.toLowerCase().contains(
              'permission',
            ),
            onRetry: _viewModel.loadPlaces,
          ),
        ),
      ];
    }

    if (!_viewModel.hasPlaces) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateWidget(
            icon: Icons.location_off_outlined,
            title: 'Không có địa điểm phù hợp',
            message: 'Hãy thử từ khóa hoặc trạng thái khác.',
          ),
        ),
      ];
    }

    return [
      SliverList.separated(
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
      const SliverToBoxAdapter(
        child: SizedBox(height: AppSizes.spaceXL),
      ),
    ];
  }

  Widget _buildPlaceCard(PlaceModel place) {
    final isUpdating = _viewModel.isUpdating(place.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: place.isActive ? 1 : .65,
          child: AppPlaceCard(
            title: place.name,
            location: place.displayLocation,
            imageUrl: place.imageUrl,
            rating: place.rating,
            distance: _categoryLabel(place.category),
            showFavoriteButton: false,
            onTap: isUpdating ? null : () => _openEditPlace(place),
          ),
        ),
        const SizedBox(height: AppSizes.spaceS),
        Row(
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
            const Spacer(),
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

class _AdminPlaceCategoryOption {
  const _AdminPlaceCategoryOption({
    required this.label,
    required this.icon,
    this.value,
  });

  final String label;
  final IconData icon;
  final String? value;
}

const List<_AdminPlaceCategoryOption> _adminCategories = [
  _AdminPlaceCategoryOption(label: 'Tất cả', icon: Icons.apps_rounded),
  _AdminPlaceCategoryOption(
    label: 'Tham quan',
    icon: Icons.attractions_outlined,
    value: 'ATTRACTION',
  ),
  _AdminPlaceCategoryOption(
    label: 'Ăn uống',
    icon: Icons.restaurant_outlined,
    value: 'RESTAURANT',
  ),
  _AdminPlaceCategoryOption(
    label: 'Cà phê',
    icon: Icons.local_cafe_outlined,
    value: 'CAFE',
  ),
  _AdminPlaceCategoryOption(
    label: 'Khách sạn',
    icon: Icons.hotel_outlined,
    value: 'HOTEL',
  ),
  _AdminPlaceCategoryOption(
    label: 'Giải trí',
    icon: Icons.celebration_outlined,
    value: 'ENTERTAINMENT',
  ),
  _AdminPlaceCategoryOption(
    label: 'Thiên nhiên',
    icon: Icons.park_outlined,
    value: 'NATURE',
  ),
  _AdminPlaceCategoryOption(
    label: 'Văn hóa',
    icon: Icons.account_balance_outlined,
    value: 'CULTURE',
  ),
  _AdminPlaceCategoryOption(
    label: 'Mua sắm',
    icon: Icons.shopping_bag_outlined,
    value: 'SHOPPING',
  ),
  _AdminPlaceCategoryOption(
    label: 'Khác',
    icon: Icons.more_horiz_rounded,
    value: 'OTHER',
  ),
];
