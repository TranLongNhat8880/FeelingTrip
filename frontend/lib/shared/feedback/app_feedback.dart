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
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final isHighContrastTone =
        tone == AppStatusTone.success || tone == AppStatusTone.info;
    final fg = isHighContrastTone ? Colors.white : tone.foreground;
    final bg = isHighContrastTone ? AppColors.primary : tone.background;

    // Tính toán thời gian hiển thị thông minh theo độ dài và mức độ ưu tiên:
    // Thông báo lỗi hoặc thông tin dài (> 60 ký tự) sẽ có thời gian đọc lâu hơn (4-6 giây)
    final displayDuration = duration ??
        switch (tone) {
          AppStatusTone.error => message.length > 60
              ? const Duration(seconds: 6)
              : const Duration(seconds: 4),
          AppStatusTone.warning => message.length > 60
              ? const Duration(seconds: 5)
              : const Duration(seconds: 4),
          _ => const Duration(seconds: 3),
        };

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        elevation: 4,
        duration: displayDuration,
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isHighContrastTone
                ? Colors.transparent
                : tone.foreground.withValues(alpha: 0.25),
          ),
        ),
        content: Row(
          children: [
            Icon(
              tone.icon,
              color: fg,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        showCloseIcon: true,
        closeIconColor: fg,
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
