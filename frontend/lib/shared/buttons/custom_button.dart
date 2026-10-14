import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

enum AppButtonVariant { primary, secondary, text, destructive }

/// The existing name is retained so team screens keep the same API.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutline = false,
    this.backgroundColor,
    this.width,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
  });
  final bool fullWidth;
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutline;
  final Color? backgroundColor;
  final double? width;
  final IconData? icon;
  final AppButtonVariant variant;
  @override
  Widget build(BuildContext context) {
    final kind = isOutline ? AppButtonVariant.secondary : variant;
    final enabled = onPressed != null && !isLoading;
    final foreground =
        kind == AppButtonVariant.primary || kind == AppButtonVariant.destructive
        ? (enabled || isLoading ? Colors.white : AppColors.textHint)
        : (enabled || isLoading ? AppColors.primary : AppColors.textHint);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: foreground,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
    final callback = enabled ? onPressed : null;
    final button = switch (kind) {
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.touchTarget, 52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: callback,
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.touchTarget, 48),
        ),
        child: content,
      ),
      _ => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: enabled || isLoading
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: backgroundColor != null
                      ? [backgroundColor!, backgroundColor!]
                      : kind == AppButtonVariant.destructive
                      ? [const Color(0xFFFF6669), AppColors.error]
                      : [AppColors.actionStart, AppColors.actionEnd],
                )
              : null,
          color: enabled || isLoading ? null : AppColors.divider,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color:
                        (kind == AppButtonVariant.destructive
                                ? AppColors.error
                                : AppColors.primary)
                            .withValues(alpha: .28),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: callback,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(AppSizes.touchTarget, 54),
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: foreground,
            disabledForegroundColor: foreground,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: content,
        ),
      ),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: isLoading,
      child: SizedBox(
        width: width ?? (fullWidth ? double.infinity : null),
        child: button,
      ),
    );
  }
}
