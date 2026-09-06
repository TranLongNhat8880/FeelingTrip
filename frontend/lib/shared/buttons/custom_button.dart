import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ================================================================================
// WIDGET DÙNG CHUNG: Custom Button
// ================================================================================
// Nút bấm chuẩn hóa cho toàn app. Hỗ trợ loading, outline, disabled.
//
// Cách dùng:
//   CustomButton(text: 'Đăng nhập', onPressed: _login)
//   CustomButton(text: 'Đang xử lý...', isLoading: true, onPressed: null)
//   CustomButton(text: 'Hủy', isOutline: true, onPressed: _cancel)
// ================================================================================

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutline;
  final Color? backgroundColor;
  final double? width;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutline = false,
    this.backgroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutline) {
      return SizedBox(
        width: width ?? double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _buildChild(color: AppColors.primary),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
        ),
        child: _buildChild(color: Colors.white),
      ),
    );
  }

  Widget _buildChild({required Color color}) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 2,
        ),
      );
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isOutline ? AppColors.primary : null,
      ),
    );
  }
}
