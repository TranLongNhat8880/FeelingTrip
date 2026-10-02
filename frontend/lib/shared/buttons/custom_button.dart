import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

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
  });
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
        : (enabled || isLoading ? AppColors.textPrimary : AppColors.textHint);
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
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
    final callback = enabled ? onPressed : null;
    final button = switch (kind) {
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        child: content,
      ),
      AppButtonVariant.text => TextButton(onPressed: callback, child: content),
      _ => ElevatedButton(
        onPressed: callback,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              backgroundColor ??
              (kind == AppButtonVariant.destructive
                  ? AppColors.error
                  : AppColors.action),
          disabledBackgroundColor: isLoading
              ? (backgroundColor ??
                    (kind == AppButtonVariant.destructive
                        ? AppColors.error
                        : AppColors.action))
              : null,
        ),
        child: content,
      ),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: isLoading,
      child: SizedBox(width: width ?? double.infinity, child: button),
    );
  }
}
