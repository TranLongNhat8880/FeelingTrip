import 'package:flutter/material.dart';
import 'empty_state_widget.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Chưa tải được dữ liệu',
    required this.message,
    this.onRetry,
    this.accessDenied = false,
  });
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool accessDenied;
  @override
  Widget build(BuildContext context) => EmptyStateWidget(
    icon: accessDenied ? Icons.lock_outline : Icons.wifi_off_rounded,
    title: title,
    message: message,
    buttonText: onRetry == null ? null : 'Thử lại',
    onButtonPressed: onRetry,
  );
}
