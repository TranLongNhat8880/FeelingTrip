import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ================================================================================
// WIDGET DÙNG CHUNG: Avatar Placeholder (Hình đại diện)
// ================================================================================
// Xử lý thông minh: 
// - Nếu có URL ảnh mạng → Hiện ảnh.
// - Nếu không có ảnh → Lấy chữ cái đầu của tên và tô màu nền Teal.
// Giúp danh sách người dùng luôn đẹp và không bị lỗi ảnh vỡ.
//
// Cách dùng:
//   AvatarPlaceholder(imageUrl: 'http...', name: 'Hải', radius: 30)
//   AvatarPlaceholder(name: 'Tùng', radius: 24)
// ================================================================================

class AvatarPlaceholder extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;

  const AvatarPlaceholder({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24.0, // Mặc định cỡ vừa
  });

  @override
  Widget build(BuildContext context) {
    // Có ảnh → Hiện ảnh thật
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: AppColors.primarySurface,
        onBackgroundImageError: (e, s) {
          // Lỗi load ảnh mạng thì rớt xuống fallback bên dưới
        },
      );
    }

    // Không có ảnh → Lấy chữ cái đầu tiên (vd: "Tùng" -> "T")
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySurface,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8, // Font size tự động scale theo khung tròn
        ),
      ),
    );
  }
}
