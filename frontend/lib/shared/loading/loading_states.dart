import '../../core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'loading_indicator.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
  });
  final Widget child;
  final bool isLoading;
  final String? message;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      if (isLoading)
        Positioned.fill(
          child: Stack(
            children: [
              const ModalBarrier(
                dismissible: false,
                color: AppColors.loadingOverlay,
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                  child: LoadingIndicator(message: message),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Static skeleton avoids endless animations and honors reduced-motion by default.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 18,
    this.radius = AppSizes.cardRadius,
  });
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang tải nội dung',
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmer,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
