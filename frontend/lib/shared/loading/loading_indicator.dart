import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ================================================================================
// WIDGET DÙNG CHUNG: Loading Indicator
// ================================================================================
// Hiển thị trạng thái đang tải. Dùng thay thế cho body screen khi đang load data.
//
// Cách dùng:
//   body: viewModel.isLoading ? const LoadingIndicator() : _buildContent()
//   LoadingIndicator.showDialog(context)   // Hiện dialog loading
//   LoadingIndicator.hideDialog(context)   // Ẩn dialog loading
// ================================================================================

class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hiện loading dialog (chặn user tương tác)
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(message ?? 'Đang xử lý...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ẩn loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}
