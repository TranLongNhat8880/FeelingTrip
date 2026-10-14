import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

// ================================================================================
// WIDGET: Bong bóng chat của Linh vật (App Tour)
// ================================================================================
// Dùng kết hợp với ShowcaseView để tạo hướng dẫn sử dụng.
// Thay vì chỉ hiện chữ, ta hiện một con linh vật ảo (hiện tại dùng Icon)
// đang nói chuyện với người dùng. Rất thân thiện!
// ================================================================================

class MascotTooltip extends StatelessWidget {
  final String message;
  final bool isArrowTop; // Mũi tên bong bóng chỉ lên hay chỉ xuống

  const MascotTooltip({
    super.key,
    required this.message,
    this.isArrowTop = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250, // Giới hạn chiều rộng bong bóng
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Linh vật (Placeholder bằng Icon Thú cưng)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.accentSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets, // Đổi thành avatar thật sau này
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSizes.spaceS),

          // 2. Bong bóng chat
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                  bottomLeft: isArrowTop
                      ? const Radius.circular(16)
                      : Radius.zero,
                  topLeft: isArrowTop ? Radius.zero : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppSizes.fontBody,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
