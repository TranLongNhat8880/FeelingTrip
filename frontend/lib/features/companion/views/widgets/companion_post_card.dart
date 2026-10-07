import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
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
        : '${DateFormat('dd/MM').format(trip.startDate!)}${endDate == null ? '' : ' – ${DateFormat('dd/MM').format(endDate)}'}';

    final statusColor = post.isClosed
        ? AppColors.error
        : post.isFull
        ? AppColors.warning
        : const Color(0xFF008B57);
    final statusBgColor = post.isClosed
        ? AppColors.errorSurface
        : post.isFull
        ? AppColors.warningSurface
        : const Color(0xFFEDF7ED);
    final statusText = post.isClosed
        ? 'Đã đóng'
        : post.isFull
        ? 'Đã đủ người'
        : 'Còn ${post.slotsLeft} chỗ';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header: Avatar, Tên & Thời gian đăng, Trạng thái chỗ
                Row(
                  children: [
                    AvatarPlaceholder(
                      name: post.creator.displayName,
                      imageUrl: post.creator.avatarUrl,
                      radius: 20,
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
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (post.creator.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('HH:mm · dd/MM').format(post.createdAt),
                            style: text.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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
                const SizedBox(height: 10),

                // 2. Tiêu đề bài đăng
                Text(
                  post.title ?? 'Tìm bạn đồng hành',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),

                // 3. Ảnh bìa chuyến đi (nếu có)
                if (trip.coverImageUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image.network(
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
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 4. Các thẻ thông tin: Điểm đến, Thời gian
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _pill(
                      icon: Icons.location_on_outlined,
                      label: trip.destination ?? 'Chưa có điểm đến',
                      bgColor: const Color(0xFFE0F2FE),
                      textColor: const Color(0xFF0369A1),
                      iconColor: const Color(0xFF0284C7),
                    ),
                    _pill(
                      icon: Icons.calendar_today_outlined,
                      label: dates,
                      bgColor: const Color(0xFFF1F5F9),
                      textColor: AppColors.textSecondary,
                      iconColor: AppColors.textSecondary,
                    ),
                    if (trip.estimatedBudget != null)
                      _pill(
                        icon: Icons.account_balance_wallet_outlined,
                        label:
                            '${NumberFormat.compact(locale: 'vi').format(trip.estimatedBudget)} đ dự kiến',
                        bgColor: const Color(0xFFDCFCE7),
                        textColor: const Color(0xFF15803D),
                        iconColor: const Color(0xFF16A34A),
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
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
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
