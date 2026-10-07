import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/ui_kit.dart';
import '../../models/companion_post_model.dart';

class CompanionPostCard extends StatelessWidget {
  const CompanionPostCard({super.key, required this.post, this.onTap});
  final CompanionPost post;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trip = post.trip;
    final endDate =
        trip.endDate ??
        (trip.startDate != null && (trip.durationDays ?? 0) > 0
            ? trip.startDate!.add(Duration(days: trip.durationDays! - 1))
            : null);
    final dates = trip.startDate == null
        ? 'Chưa có lịch'
        : '${DateFormat('dd/MM').format(trip.startDate!)}${endDate == null ? '' : '–${DateFormat('dd/MM').format(endDate)}'}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AvatarPlaceholder(
                  name: post.creator.displayName,
                  imageUrl: post.creator.avatarUrl,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.creator.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                          ),
                          if (post.creator.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat('HH:mm · dd/MM').format(post.createdAt),
                        style: text.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title ?? 'Tìm bạn đồng hành',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
            if (trip.coverImageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  trip.coverImageUrl!,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 170,
                    color: AppColors.inputSurface,
                    child: const Icon(
                      Icons.landscape_outlined,
                      color: AppColors.textHint,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                _info(
                  context,
                  Icons.location_on_outlined,
                  trip.destination ?? 'Chưa có điểm đến',
                ),
                _info(context, Icons.calendar_today_outlined, dates),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                if (trip.estimatedBudget != null)
                  _info(
                    context,
                    Icons.account_balance_wallet_outlined,
                    '${NumberFormat.compact(locale: 'vi').format(trip.estimatedBudget)} đ dự kiến',
                  ),
                Text(
                  post.isClosed
                      ? 'Đã đóng'
                      : post.isFull
                      ? 'Đã đủ người'
                      : 'Còn ${post.slotsLeft} chỗ',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.tags.take(3).map((tag) => '#$tag').join('  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.textSecondary),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}
