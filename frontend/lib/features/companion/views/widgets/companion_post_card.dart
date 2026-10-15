import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/ui_kit.dart';
import '../../../profile/views/public_profile_screen.dart';
import '../../models/companion_post_model.dart';

class CompanionPostCard extends StatelessWidget {
  const CompanionPostCard({super.key, required this.post, this.onTap});

  final CompanionPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trip = post.trip;
    final score = post.creator.trustScore.toStringAsFixed(
      post.creator.trustScore % 1 == 0 ? 0 : 1,
    );
    final endDate =
        trip.endDate ??
        (trip.startDate != null && (trip.durationDays ?? 0) > 0
            ? trip.startDate!.add(Duration(days: trip.durationDays! - 1))
            : null);
    final dates = trip.startDate == null
        ? 'Chưa có lịch'
        : '${DateFormat('dd/MM/yyyy').format(trip.startDate!)}${endDate == null ? '' : ' – ${DateFormat('dd/MM/yyyy').format(endDate)}'}';

    final statusColor = post.isClosed
        ? AppColors.error
        : post.isFull
        ? AppColors.warning
        : AppColors.success;
    final statusBgColor = post.isClosed
        ? AppColors.errorSurface
        : post.isFull
        ? AppColors.warningSurface
        : AppColors.successSurface;
    final statusText = post.isClosed
        ? 'Đã đóng'
        : post.isFull
        ? 'Đã đủ người'
        : 'Còn ${post.slotsLeft} chỗ';

    return Container(
      color: Colors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header: Avatar, Tên & Thời gian đăng, Trạng thái chỗ
                Row(
                  children: [
                    Tooltip(
                      message: 'Xem hồ sơ ${post.creator.displayName}',
                      child: InkWell(
                        hoverColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        onTap: post.creator.id.trim().isEmpty
                            ? null
                            : () => PublicProfileScreen.open(
                                context,
                                userId: post.creator.id,
                              ),
                        child: AvatarPlaceholder(
                          name: post.creator.displayName,
                          imageUrl: post.creator.avatarUrl,
                          radius: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            hoverColor: Colors.transparent,
                            onTap: post.creator.id.trim().isEmpty
                                ? null
                                : () => PublicProfileScreen.open(
                                    context,
                                    userId: post.creator.id,
                                  ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.creator.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (post.creator.reviewCount > 0) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      '$score · ${post.creator.reviewCount} đánh giá',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.labelSmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat(
                                    'HH:mm · dd/MM/yyyy',
                                  ).format(post.createdAt),
                                  style: text.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBgColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Tiêu đề bài đăng
                Text(
                  post.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),

                if (post.content?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.content!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],

                // Ảnh tự lấy tỷ lệ gốc; chỉ giới hạn ảnh quá dài khi lướt feed.
                if (trip.coverImageUrl?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .65,
                        ),
                        child: Image.network(
                          trip.coverImageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : Container(
                                  height: 160,
                                  width: double.infinity,
                                  color: AppColors.inputSurface,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                          errorBuilder: (_, _, _) => Container(
                            height: 120,
                            width: double.infinity,
                            color: AppColors.inputSurface,
                            child: const Icon(
                              Icons.landscape_outlined,
                              color: AppColors.textHint,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // 4. Các thẻ thông tin: Điểm đến, Thời gian
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _pill(
                      icon: Icons.location_on_outlined,
                      label: trip.destination ?? 'Chưa có điểm đến',
                      bgColor: AppColors.inputSurface,
                      textColor: AppColors.textSecondary,
                      iconColor: const Color(0xFF0284C7),
                    ),
                    _pill(
                      icon: Icons.calendar_today_outlined,
                      label: dates,
                      bgColor: AppColors.inputSurface,
                      textColor: AppColors.textSecondary,
                      iconColor: AppColors.textSecondary,
                    ),
                    if (trip.estimatedBudget != null)
                      _pill(
                        icon: Icons.account_balance_wallet_outlined,
                        label:
                            '${NumberFormat.compact(locale: 'vi').format(trip.estimatedBudget)} đ dự kiến',
                        bgColor: AppColors.inputSurface,
                        textColor: AppColors.textSecondary,
                        iconColor: AppColors.textSecondary,
                      ),
                  ],
                ),

                // 5. Hashtags
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    post.tags.take(3).map((tag) => '#$tag').join('  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
