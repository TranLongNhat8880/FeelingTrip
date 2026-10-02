import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum AppStatusTone { neutral, success, warning, error, info }

extension AppStatusToneColors on AppStatusTone {
  Color get foreground => switch (this) {
    AppStatusTone.success => AppColors.success,
    AppStatusTone.warning => AppColors.warning,
    AppStatusTone.error => AppColors.error,
    AppStatusTone.info => AppColors.info,
    _ => AppColors.textSecondary,
  };
  Color get background => switch (this) {
    AppStatusTone.success => AppColors.successSurface,
    AppStatusTone.warning => AppColors.warningSurface,
    AppStatusTone.error => AppColors.errorSurface,
    AppStatusTone.info => AppColors.infoSurface,
    _ => AppColors.background,
  };
  IconData get icon => switch (this) {
    AppStatusTone.success => Icons.check_circle_outline,
    AppStatusTone.warning => Icons.schedule_rounded,
    AppStatusTone.error => Icons.error_outline,
    _ => Icons.info_outline,
  };
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
  });
  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? tone.icon, color: tone.foreground, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: tone.foreground),
          ),
        ),
      ],
    ),
  );
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, required this.child});
  final int count;
  final Widget child;
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    backgroundColor: AppColors.error,
    child: child,
  );
}
