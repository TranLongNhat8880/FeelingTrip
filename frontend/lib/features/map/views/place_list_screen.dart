import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../viewmodels/place_viewmodel.dart';
import 'place_detail_screen.dart';

// ============================================================================
// VIEW: Danh sách và tìm kiếm địa điểm
// ============================================================================

class PlaceListScreen extends StatefulWidget {
  const PlaceListScreen({super.key});

  @override
  State<PlaceListScreen> createState() => _PlaceListScreenState();
}

class _PlaceListScreenState extends State<PlaceListScreen> {
  late final PlaceViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _viewModel = PlaceViewModel();
    _viewModel.loadPlaces();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _viewModel.search(
        keyword: value,
        category: _selectedCategory,
        sortBy: _viewModel.sortBy,
      );
    });
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });

    _viewModel.search(
      keyword: _searchController.text,
      category: category,
      sortBy: _viewModel.sortBy,
    );
  }

  Future<void> _clearFilters() async {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _selectedCategory = null;
    });

    await _viewModel.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return AppScaffold(
          title: 'Khám phá địa điểm',
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Tìm tên hoặc địa chỉ...',
                    isLoading: _viewModel.isLoading,
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: AppSizes.spaceM),
                  _buildCategoryList(),
                  const SizedBox(height: AppSizes.spaceM),
                  _buildResultHeader(),
                  const SizedBox(height: AppSizes.spaceS),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
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
          for (var index = 0; index < _categories.length; index++) ...[
            AppCategoryPill(
              label: _categories[index].label,
              icon: _categories[index].icon,
              selected: _selectedCategory == _categories[index].value,
              onTap: () => _selectCategory(_categories[index].value),
            ),
            if (index < _categories.length - 1)
              const SizedBox(width: AppSizes.spaceS),
          ],
        ],
      ),
    );
  }

  Widget _buildResultHeader() {
    final hasFilter =
        _searchController.text.trim().isNotEmpty || _selectedCategory != null;

    return Row(
      children: [
        Expanded(
          child: Text(
            _viewModel.totalItems > 0
                ? '${_viewModel.totalItems} địa điểm'
                : 'Địa điểm nổi bật',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (hasFilter)
          CustomButton(
            text: 'Xóa lọc',
            onPressed: _viewModel.isLoading ? null : _clearFilters,
            icon: Icons.filter_alt_off_outlined,
            variant: AppButtonVariant.text,
            fullWidth: false,
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && !_viewModel.hasPlaces) {
      return const LoadingIndicator(message: 'Đang tìm địa điểm...');
    }

    if (_viewModel.errorMessage != null && !_viewModel.hasPlaces) {
      return ErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadPlaces,
      );
    }

    if (!_viewModel.hasPlaces) {
      return EmptyStateWidget(
        icon: Icons.place_outlined,
        title: 'Chưa tìm thấy địa điểm',
        message: 'Hãy thử từ khóa hoặc danh mục khác.',
        buttonText: 'Xóa bộ lọc',
        onButtonPressed: _clearFilters,
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

          final place = _viewModel.places[index];

          return AppPlaceCard(
            title: place.name,
            location: place.displayLocation,
            imageUrl: place.imageUrl,
            rating: place.rating,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PlaceDetailScreen(placeId: place.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlaceCategoryOption {
  const _PlaceCategoryOption({
    required this.label,
    required this.icon,
    this.value,
  });

  final String label;
  final IconData icon;
  final String? value;
}

const List<_PlaceCategoryOption> _categories = [
  _PlaceCategoryOption(label: 'Tất cả', icon: Icons.apps_rounded),
  _PlaceCategoryOption(
    label: 'Tham quan',
    icon: Icons.attractions_outlined,
    value: 'ATTRACTION',
  ),
  _PlaceCategoryOption(
    label: 'Ăn uống',
    icon: Icons.restaurant_outlined,
    value: 'RESTAURANT',
  ),
  _PlaceCategoryOption(
    label: 'Cà phê',
    icon: Icons.local_cafe_outlined,
    value: 'CAFE',
  ),
  _PlaceCategoryOption(
    label: 'Khách sạn',
    icon: Icons.hotel_outlined,
    value: 'HOTEL',
  ),
  _PlaceCategoryOption(
    label: 'Giải trí',
    icon: Icons.celebration_outlined,
    value: 'ENTERTAINMENT',
  ),
  _PlaceCategoryOption(
    label: 'Thiên nhiên',
    icon: Icons.park_outlined,
    value: 'NATURE',
  ),
  _PlaceCategoryOption(
    label: 'Văn hóa',
    icon: Icons.account_balance_outlined,
    value: 'CULTURE',
  ),
  _PlaceCategoryOption(
    label: 'Mua sắm',
    icon: Icons.shopping_bag_outlined,
    value: 'SHOPPING',
  ),
  _PlaceCategoryOption(
    label: 'Khác',
    icon: Icons.more_horiz_rounded,
    value: 'OTHER',
  ),
];
