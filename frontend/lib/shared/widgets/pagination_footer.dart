import 'package:flutter/material.dart';
import '../buttons/custom_button.dart';
import '../loading/loading_indicator.dart';

class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.errorMessage,
    this.onLoadMore,
  });
  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback? onLoadMore;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: isLoading
        ? const LoadingIndicator(message: 'Đang tải thêm…')
        : errorMessage != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              CustomButton(
                text: 'Thử tải lại',
                variant: AppButtonVariant.text,
                onPressed: onLoadMore,
              ),
            ],
          )
        : hasMore
        ? CustomButton(
            text: 'Xem thêm',
            variant: AppButtonVariant.secondary,
            onPressed: onLoadMore,
          )
        : const Text('Bạn đã xem hết danh sách', textAlign: TextAlign.center),
  );
}
