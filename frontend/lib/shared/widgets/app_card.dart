import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.cardPadding),
    this.onTap,
    this.color = AppColors.surface,
    this.outlined = true,
    this.softShadow = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final bool outlined;
  final bool softShadow;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      boxShadow: softShadow
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    child: Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: outlined
            ? const BorderSide(color: AppColors.border)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      ?action,
    ],
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });
  final String label;
  final String value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    ),
  );
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.surface,
    this.compact = false,
    this.valueStyle,
  });
  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final bool compact;
  final TextStyle? valueStyle;
  @override
  Widget build(BuildContext context) => AppCard(
    color: color,
    padding: EdgeInsets.all(compact ? 10 : AppSizes.cardPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          if (compact)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            )
          else
            Icon(icon, color: AppColors.primary),
          SizedBox(height: compact ? 10 : 12),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact
                ? MediaQuery.textScalerOf(context).scale(11.5) * 2.8
                : 0,
          ),
          child: Text(
            label,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: compact ? 11.5 : null,
              height: compact ? 1.4 : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (compact)
          Tooltip(
            message: value,
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: valueStyle ?? Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          )
        else
          Text(
            value,
            style: valueStyle ?? Theme.of(context).textTheme.titleLarge,
          ),
      ],
    ),
  );
}

/// Thẻ địa điểm du lịch cao cấp chuẩn phong cách Travel Guide:
/// Ảnh nền tràn viền bo góc theo AppSizes.cardRadius, huy hiệu khoảng cách lơ lửng, nút tim và thanh thông tin frosted glass.
class AppPlaceCard extends StatelessWidget {
  const AppPlaceCard({
    super.key,
    required this.title,
    required this.location,
    this.imageUrl,
    this.distance,
    this.rating = 4.5,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.onTap,
    this.height = 220,
    this.showFavoriteButton = true,
  });

  final String title;
  final String location;
  final String? imageUrl;
  final String? distance;
  final double rating;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onTap;
  final double height;
  final bool showFavoriteButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ảnh nền (hoặc gradient thiên nhiên dự phòng)
            imageUrl != null && imageUrl!.startsWith('http')
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildFallbackImage(),
                  )
                : _buildFallbackImage(),

            // Nút bấm toàn thẻ
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ),

            // Huy hiệu khoảng cách (Góc trên bên trái)
            if (distance != null)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glassDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    distance!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Nút yêu thích / Tim (Góc trên bên phải)
            if (showFavoriteButton)
              Positioned(
                top: 14,
                right: 14,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onFavoriteTap,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite ? AppColors.error : AppColors.action,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

            // Lớp phủ thông tin dưới đáy (Frosted Glass Gradient Banner)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: AppSizes.fontControl,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.star,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppSizes.fontSmall,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: AppSizes.fontCaption,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E3A2F), Color(0xFF2D5A47), Color(0xFF132B21)],
      ),
    ),
    child: const Center(
      child: Icon(Icons.landscape_rounded, size: 54, color: Colors.white24),
    ),
  );
}

/// Chip phân loại theo phong cách Du lịch (Parks, Shops, Cafes):
/// Màu nhấn khi được chọn, nền trắng khi chưa chọn.
class AppCategoryPill extends StatelessWidget {
  const AppCategoryPill({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.border),
      ),
      elevation: selected ? 1 : 0,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontSize: AppSizes.fontBody,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
