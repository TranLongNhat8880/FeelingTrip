import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../routes/app_routes.dart';
import '../buttons/custom_button.dart';
import '../layout/app_scaffold.dart';
import '../layout/travel_decoration.dart';
import 'app_card.dart';
import 'empty_state_widget.dart';

// ================================================================================
// WIDGET DÙNG CHUNG: Màn hình chờ tính năng đang hoàn thiện
// ================================================================================
// Dùng làm cầu nối điều hướng (Navigation Gateway) cho các tính năng của đồng đội
// đang trong quá trình phát triển (Companions, AI Planner, Expenses...).
// ================================================================================

class FeaturePlaceholderScreen extends StatelessWidget {
  const FeaturePlaceholderScreen({
    super.key,
    required this.title,
    required this.featureName,
    required this.description,
    this.owner,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String featureName;
  final String description;
  final String? owner;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      title: title,
      body: TravelBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
                vertical: AppSizes.paddingXL,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.documentMaxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppCard(
                      softShadow: true,
                      padding: const EdgeInsets.all(AppSizes.paddingXL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: AppColors.accent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'TÍNH NĂNG ĐANG HOÀN THIỆN',
                                  style: text.labelSmall?.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          EmptyStateWidget(
                            icon: icon,
                            title: featureName,
                            message: description,
                          ),
                          if (owner != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.cardRadius,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_pin_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Phụ trách: $owner (Backend đã sẵn sàng)',
                                    style: text.bodySmall?.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'Quay lại',
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomButton(
                                  text: 'Khám phá địa điểm',
                                  variant: AppButtonVariant.primary,
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.places,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
