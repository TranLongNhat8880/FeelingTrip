import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AvatarPlaceholder extends StatelessWidget {
  const AvatarPlaceholder({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
  });
  final String? imageUrl;
  final String name;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
          fontSize: radius * .75,
        ),
      ),
    );
    return Semantics(
      label: 'Ảnh đại diện: $name',
      image: true,
      child: ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          color: AppColors.primarySurface,
          child: imageUrl == null || imageUrl!.isEmpty
              ? fallback
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
