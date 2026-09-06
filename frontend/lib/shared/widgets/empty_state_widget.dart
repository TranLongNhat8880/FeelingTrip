import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../buttons/custom_button.dart';

// ================================================================================
// WIDGET DÙNG CHUNG: Empty State (Trạng thái rỗng)
// ================================================================================
// Sử dụng khi màn hình chưa có dữ liệu (chưa có chuyến đi, chưa có thông báo...)
// Giúp app trông không bị "chết" hay lỗi khi trống trơn.
//
// Cách dùng:
//   EmptyStateWidget(
//     icon: Icons.flight_takeoff,
//     title: 'Chưa có chuyến đi nào',
//     message: 'Hãy bắt đầu lên kế hoạch cho chuyến đi đầu tiên của bạn!',
//     buttonText: 'Tạo chuyến đi',
//     onButtonPressed: () => print('Tạo'),
//   )
// ================================================================================

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon to, màu nhạt
            Icon(
              icon,
              size: 80,
              color: AppColors.primaryLight.withOpacity(0.5),
            ),
            const SizedBox(height: AppSizes.spaceM),
            
            // Tiêu đề chính
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spaceS),
            
            // Lời giải thích/hướng dẫn
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Nút bấm Call-to-action (nếu có)
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: AppSizes.spaceL),
              CustomButton(
                text: buttonText!,
                onPressed: onButtonPressed,
                width: 200, // Nút không full màn hình để trông gọn hơn
              ),
            ],
          ],
        ),
      ),
    );
  }
}
