import 'package:flutter/material.dart';
import '../widgets/app_status_badge.dart';

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
        backgroundColor: tone.background,
        content: Row(
          children: [
            Icon(tone.icon, color: tone.foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: tone.foreground)),
            ),
          ],
        ),
        showCloseIcon: true,
        closeIconColor: tone.foreground,
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
      borderRadius: BorderRadius.circular(18),
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
