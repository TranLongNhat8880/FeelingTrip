import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../models/place_model.dart';
import '../viewmodels/place_viewmodel.dart';
import 'place_distance_screen.dart';

// ============================================================================
// VIEW: Chi tiết địa điểm
// ============================================================================

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final PlaceViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PlaceViewModel();
    _viewModel.loadPlaceDetail(widget.placeId);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openMap(PlaceModel place) async {
    final mapUri = place.mapUri;

    if (mapUri == null) {
      AppFeedback.show(
        context,
        'Địa điểm này chưa có tọa độ bản đồ.',
        tone: AppStatusTone.warning,
      );
      return;
    }

    try {
      final opened = await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        AppFeedback.show(
          context,
          'Không thể mở Google Maps.',
          tone: AppStatusTone.error,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Không thể mở Google Maps.',
          tone: AppStatusTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final place = _viewModel.selectedPlace;

        return AppScaffold(
          title: place?.name ?? 'Chi tiết địa điểm',
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth,
              ),
              child: _buildContent(place),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(PlaceModel? place) {
    if (_viewModel.isLoading && place == null) {
      return const LoadingIndicator(message: 'Đang tải thông tin địa điểm...');
    }

    if (_viewModel.errorMessage != null && place == null) {
      return ErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.loadPlaceDetail(widget.placeId);
        },
      );
    }

    if (place == null) {
      return const EmptyStateWidget(
        icon: Icons.place_outlined,
        title: 'Không tìm thấy địa điểm',
        message: 'Địa điểm có thể đã bị ẩn hoặc không còn tồn tại.',
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppImage(
            url: place.imageUrl,
            semanticLabel: 'Hình ảnh ${place.name}',
          ),
          const SizedBox(height: AppSizes.spaceL),
          Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSizes.spaceS),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSizes.spaceS),
              Expanded(
                child: Text(
                  place.displayLocation,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceL),
          Row(
            children: [
              Expanded(
                child: SummaryTile(
                  label: 'Đánh giá',
                  value: '${place.rating.toStringAsFixed(1)}/5',
                  icon: Icons.star_rounded,
                  color: AppColors.warningSurface,
                ),
              ),
              const SizedBox(width: AppSizes.spaceM),
              Expanded(
                child: SummaryTile(
                  label: 'Tham quan',
                  value: '${place.avgDurationMinutes} phút',
                  icon: Icons.schedule_outlined,
                  color: AppColors.primarySurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceL),
          AppCard(
            outlined: true,
            child: Column(
              children: [
                InfoRow(
                  label: 'Tỉnh/Thành phố',
                  value: place.destination,
                  icon: Icons.location_city_outlined,
                ),
                InfoRow(
                  label: 'Danh mục',
                  value: _categoryLabel(place.category),
                  icon: Icons.category_outlined,
                ),
                InfoRow(
                  label: 'Mức giá',
                  value: 'Mức ${place.priceLevel}/4',
                  icon: Icons.payments_outlined,
                ),
                if (place.hasCoordinates) ...[
                  InfoRow(
                    label: 'Vĩ độ',
                    value: place.latitude!.toStringAsFixed(6),
                    icon: Icons.my_location_outlined,
                  ),
                  InfoRow(
                    label: 'Kinh độ',
                    value: place.longitude!.toStringAsFixed(6),
                    icon: Icons.explore_outlined,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spaceL),
          CustomButton(
            text: 'Tính khoảng cách & chỉ đường',
            icon: Icons.route_outlined,
            onPressed: place.hasCoordinates
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PlaceDistanceScreen(destination: place),
                      ),
                    );
                  }
                : null,
          ),
          const SizedBox(height: AppSizes.spaceM),
          if (place.mapUri != null)
            CustomButton(
              text: 'Mở trên Google Maps',
              icon: Icons.map_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => _openMap(place),
            )
          else
            const AppInlineNotice(
              message: 'Địa điểm này chưa có tọa độ để mở bản đồ.',
              tone: AppStatusTone.warning,
            ),
          const SizedBox(height: AppSizes.spaceL),
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
