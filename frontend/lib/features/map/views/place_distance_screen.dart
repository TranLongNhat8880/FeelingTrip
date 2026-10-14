import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../models/place_distance_model.dart';
import '../models/place_model.dart';
import '../viewmodels/place_viewmodel.dart';

// ============================================================================
// VIEW: Tính khoảng cách và mở chỉ đường giữa hai địa điểm
// ============================================================================

class PlaceDistanceScreen extends StatefulWidget {
  const PlaceDistanceScreen({super.key, required this.destination});

  final PlaceModel destination;

  @override
  State<PlaceDistanceScreen> createState() => _PlaceDistanceScreenState();
}

class _PlaceDistanceScreenState extends State<PlaceDistanceScreen> {
  late final PlaceViewModel _viewModel;

  PlaceModel? _origin;
  String _travelMode = 'driving';

  @override
  void initState() {
    super.initState();
    _viewModel = PlaceViewModel();
    _viewModel.loadPlaces();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  List<PlaceModel> get _availableOrigins {
    return _viewModel.places
        .where(
          (place) => place.id != widget.destination.id && place.hasCoordinates,
        )
        .toList(growable: false);
  }

  Future<void> _chooseOrigin() async {
    if (_viewModel.isLoading && !_viewModel.hasPlaces) {
      return;
    }

    final selected = await AppBottomSheet.show<PlaceModel>(
      context,
      title: 'Chọn điểm xuất phát',
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (sheetContext, _) {
          final places = _availableOrigins;

          if (_viewModel.isLoading && !_viewModel.hasPlaces) {
            return const SizedBox(
              height: 240,
              child: LoadingIndicator(message: 'Đang tải địa điểm...'),
            );
          }

          if (_viewModel.errorMessage != null && !_viewModel.hasPlaces) {
            return ErrorState(
              message: _viewModel.errorMessage!,
              onRetry: _viewModel.loadPlaces,
            );
          }

          if (places.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.route_outlined,
              title: 'Chưa có điểm xuất phát',
              message: 'Cần ít nhất một địa điểm khác có tọa độ.',
            );
          }

          return Column(
            children: [
              for (final place in places) ...[
                AppCard(
                  outlined: true,
                  onTap: () {
                    Navigator.pop(sheetContext, place);
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSizes.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSizes.spaceXS),
                            Text(
                              place.displayLocation,
                              style: Theme.of(sheetContext).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spaceS),
              ],
              PaginationFooter(
                isLoading: _viewModel.isLoadingMore,
                hasMore: _viewModel.hasMore,
                errorMessage: _viewModel.errorMessage,
                onLoadMore: _viewModel.loadMore,
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _origin = selected;
    });

    _viewModel.clearDistanceResult();
  }

  Future<void> _calculateDistance() async {
    final origin = _origin;

    if (origin == null) {
      AppFeedback.show(
        context,
        'Vui lòng chọn điểm xuất phát.',
        tone: AppStatusTone.warning,
      );
      return;
    }

    await _viewModel.calculateDistance(
      origin: origin,
      destination: widget.destination,
      travelMode: _travelMode,
    );
  }

  Future<void> _openDirections(PlaceDistanceResult result) async {
    final uri = result.directionsUri;

    if (uri == null) {
      AppFeedback.show(
        context,
        'Chưa có liên kết chỉ đường.',
        tone: AppStatusTone.warning,
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

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

  void _changeTravelMode(String travelMode) {
    setState(() {
      _travelMode = travelMode;
    });

    _viewModel.clearDistanceResult();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return AppScaffold(
          title: 'Khoảng cách & chỉ đường',
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDestinationCard(),
                    const SizedBox(height: AppSizes.spaceL),
                    AppSelectionField(
                      label: 'Điểm xuất phát',
                      value: _origin?.name ?? '',
                      icon: Icons.trip_origin_rounded,
                      enabled: !_viewModel.isLoading,
                      onTap: _chooseOrigin,
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    Text(
                      'Phương tiện',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSizes.spaceS),
                    AppChoiceChips<String>(
                      options: const {
                        'driving': 'Ô tô',
                        'walking': 'Đi bộ',
                        'bicycling': 'Xe đạp',
                        'transit': 'Công cộng',
                      },
                      selected: {_travelMode},
                      enabled: !_viewModel.isCalculatingDistance,
                      onChanged: _changeTravelMode,
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    CustomButton(
                      text: 'Tính khoảng cách',
                      icon: Icons.route_outlined,
                      isLoading: _viewModel.isCalculatingDistance,
                      onPressed: widget.destination.hasCoordinates
                          ? _calculateDistance
                          : null,
                    ),
                    if (_viewModel.distanceErrorMessage != null) ...[
                      const SizedBox(height: AppSizes.spaceM),
                      InlineError(
                        message: _viewModel.distanceErrorMessage!,
                        onRetry: _origin == null ? null : _calculateDistance,
                      ),
                    ],
                    if (_viewModel.distanceResult != null) ...[
                      const SizedBox(height: AppSizes.spaceL),
                      _buildResult(_viewModel.distanceResult!),
                    ],
                    const SizedBox(height: AppSizes.spaceL),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDestinationCard() {
    return AppCard(
      outlined: true,
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.primary, size: 28),
          const SizedBox(width: AppSizes.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Điểm đến',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spaceXS),
                Text(
                  widget.destination.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSizes.spaceXS),
                Text(
                  widget.destination.displayLocation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(PlaceDistanceResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kết quả ước lượng',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSizes.spaceM),
        Row(
          children: [
            Expanded(
              child: SummaryTile(
                label: 'Khoảng cách',
                value: '${result.distanceKm.toStringAsFixed(2)} km',
                icon: Icons.straighten_rounded,
                color: AppColors.primarySurface,
              ),
            ),
            const SizedBox(width: AppSizes.spaceM),
            Expanded(
              child: SummaryTile(
                label: 'Thời gian',
                value: '${result.estimatedDurationMinutes} phút',
                icon: Icons.schedule_outlined,
                color: AppColors.warningSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceM),
        const AppInlineNotice(
          message:
              'Khoảng cách và thời gian chỉ là ước lượng, '
              'không sử dụng dữ liệu giao thông thời gian thực.',
        ),
        const SizedBox(height: AppSizes.spaceM),
        CustomButton(
          text: 'Mở chỉ đường',
          icon: Icons.directions_outlined,
          onPressed: result.directionsUri == null
              ? null
              : () => _openDirections(result),
        ),
      ],
    );
  }
}
