import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import '../widgets/app_status_badge.dart';

class AppInlineNotice extends StatelessWidget {
  const AppInlineNotice({
    super.key,
    required this.message,
    this.tone = AppStatusTone.info,
  });
  final String message;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: tone.foreground.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, color: tone.foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: AppSizes.fontSmall,
                color: tone.foreground,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AppFeedback {
  AppFeedback._();
  static void show(
    BuildContext context,
    String message, {
    AppStatusTone tone = AppStatusTone.info,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor:
            tone == AppStatusTone.success || tone == AppStatusTone.info
            ? AppColors.primary
            : tone.background,
        content: Row(
          children: [
            Icon(
              tone.icon,
              color: tone == AppStatusTone.success || tone == AppStatusTone.info
                  ? Colors.white
                  : tone.foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color:
                      tone == AppStatusTone.success ||
                          tone == AppStatusTone.info
                      ? Colors.white
                      : tone.foreground,
                ),
              ),
            ),
          ],
        ),
        showCloseIcon: true,
        closeIconColor:
            tone == AppStatusTone.success || tone == AppStatusTone.info
            ? Colors.white
            : tone.foreground,
      ),
    );
  }
}

class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppStatusTone.error.background,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: AppStatusTone.error.foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: AppStatusTone.error.foreground),
              ),
            ),
          ],
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
