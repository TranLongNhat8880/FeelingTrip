import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/ui_kit.dart';
import '../../../profile/views/public_profile_screen.dart';
import '../../models/trip_reviews_model.dart';
import '../../repositories/trip_reviews_repository.dart';
import '../../viewmodels/trip_reviews_viewmodel.dart';

/// Embedded in a scrolling itinerary page, so it has no nested scroll view.
class TripReviewsSection extends StatefulWidget {
  const TripReviewsSection({
    super.key,
    required this.sourceTripId,
    this.repository,
  });
  final String sourceTripId;
  final TripReviewsRepository? repository;

  @override
  State<TripReviewsSection> createState() => _TripReviewsSectionState();
}

class _TripReviewsSectionState extends State<TripReviewsSection> {
  late TripReviewsViewModel _vm;

  void _create() {
    _vm = TripReviewsViewModel(
      tripId: widget.sourceTripId,
      repository: widget.repository,
    );
    _vm.load();
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(covariant TripReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceTripId != widget.sourceTripId ||
        oldWidget.repository != widget.repository) {
      _vm.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Widget _review(TripReviewItem item) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: 'Xem hồ sơ ${item.reviewer.displayName}',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.reviewer.id.trim().isEmpty
                ? null
                : () => PublicProfileScreen.open(
                    context,
                    userId: item.reviewer.id,
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AvatarPlaceholder(
                    name: item.reviewer.displayName,
                    imageUrl: item.reviewer.avatarUrl,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.reviewer.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(item.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: '${item.rating} trên 5 sao',
          child: ExcludeSemantics(
            child: Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  Icon(
                    star <= item.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  '${item.rating}/5',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (item.comment?.trim().isNotEmpty == true)
          SelectableText(item.comment!)
        else
          Text(
            'Người dùng chỉ chấm sao, không viết nhận xét.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _vm,
    builder: (context, _) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Đánh giá chuyến đi',
              subtitle:
                  'Nhận xét về chuyến đi gốc, không gồm đánh giá bạn đồng hành.',
              action: IconButton(
                tooltip: 'Tải lại đánh giá',
                onPressed: _vm.loading ? null : () => _vm.load(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (_vm.summary != null && _vm.summary!.reviewCount > 0) ...[
              AppCard(
                color: AppColors.primarySurface,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.warning,
                      size: 28,
                    ),
                    Text(
                      '${_vm.summary!.averageRating.toStringAsFixed(1)}/5',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${_vm.summary!.reviewCount} lượt đánh giá'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_vm.error != null) ...[
              AppInlineNotice(message: _vm.error!, tone: AppStatusTone.warning),
              const SizedBox(height: 8),
              CustomButton(
                text: 'Thử tải lại đánh giá',
                variant: AppButtonVariant.secondary,
                onPressed: _vm.loading ? null : _vm.retry,
              ),
              const SizedBox(height: 12),
            ],
            if (_vm.summary?.reviewCount == 0 &&
                _vm.error == null &&
                !_vm.loading)
              const AppCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text('Chưa có đánh giá'),
                    SizedBox(height: 4),
                    Text(
                      'Chưa có người gửi đánh giá chuyến đi này.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final item in _vm.items) ...[
              _review(item),
              const SizedBox(height: 12),
            ],
            if (_vm.loading)
              LoadingIndicator(
                message: _vm.loadingMore
                    ? 'Đang tải thêm đánh giá...'
                    : 'Đang tải đánh giá...',
              ),
            if (_vm.items.isNotEmpty) ...[
              Text(
                'Đang hiển thị ${_vm.items.length}/${_vm.summary!.reviewCount} đánh giá',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
            ],
            if (_vm.hasMore && !_vm.loading && _vm.error == null)
              CustomButton(
                text: 'Xem thêm đánh giá',
                variant: AppButtonVariant.secondary,
                onPressed: () => _vm.load(more: true),
              ),
          ],
        ),
      ),
    ),
  );
}
