import 'package:flutter/material.dart';

// ================================================================================
// 🎨 BẢNG MÀU CHÍNH THỨC CỦA FEELINGTRIP
// ================================================================================
// Tông chủ đạo: Teal (xanh ngọc) – tự nhiên, khám phá, tin cậy
// Accent: Coral (cam san hô) – năng động, phiêu lưu, nổi bật
//
// Cách dùng:
//   Container(color: AppColors.primary)
//   Text('Hello', style: TextStyle(color: AppColors.textPrimary))
// ================================================================================

class AppColors {
  AppColors._();

  // === PRIMARY – Teal (Xanh ngọc) ===
  // Dùng cho: AppBar, nút chính, icon active, link
  static const Color primary = Color(0xFF0D9488);       // Teal 600
  static const Color primaryDark = Color(0xFF0F766E);   // Teal 700 (AppBar, nút pressed)
  static const Color primaryLight = Color(0xFF5EEAD4);  // Teal 300 (tag, chip, border nhẹ)
  static const Color primarySurface = Color(0xFFCCFBF1); // Teal 100 (nền nhạt, badge)

  // === ACCENT – Coral / Orange ===
  // Dùng cho: FAB, nút CTA nổi bật, thông báo quan trọng, giá tiền
  static const Color accent = Color(0xFFF97316);        // Orange 500
  static const Color accentLight = Color(0xFFFB923C);   // Orange 400
  static const Color accentSurface = Color(0xFFFFF7ED); // Orange 50 (nền nhạt)

  // === NEUTRAL – Xám xanh (Slate) ===
  // Dùng cho: text, divider, border, icon
  static const Color textPrimary = Color(0xFF1E293B);   // Slate 800 (tiêu đề, text chính)
  static const Color textSecondary = Color(0xFF64748B); // Slate 500 (mô tả, text phụ)
  static const Color textHint = Color(0xFF94A3B8);      // Slate 400 (placeholder, hint)
  static const Color textOnPrimary = Color(0xFFFFFFFF); // Text trên nền teal/coral

  // === BACKGROUND ===
  static const Color background = Color(0xFFF8FAFC);    // Slate 50 (nền app)
  static const Color surface = Color(0xFFFFFFFF);        // Nền card, bottom sheet
  static const Color divider = Color(0xFFE2E8F0);       // Slate 200 (đường kẻ)
  static const Color border = Color(0xFFCBD5E1);        // Slate 300 (viền input)

  // === STATUS ===
  static const Color success = Color(0xFF10B981);       // Emerald 500
  static const Color successSurface = Color(0xFFECFDF5); // Emerald 50
  static const Color warning = Color(0xFFF59E0B);       // Amber 500
  static const Color warningSurface = Color(0xFFFFFBEB); // Amber 50
  static const Color error = Color(0xFFEF4444);         // Red 500
  static const Color errorSurface = Color(0xFFFEF2F2);  // Red 50
  static const Color info = Color(0xFF3B82F6);          // Blue 500
  static const Color infoSurface = Color(0xFFEFF6FF);   // Blue 50

  // === TRIP STATUS – Trạng thái chuyến đi ===
  static const Color tripUpcoming = Color(0xFF3B82F6);  // Sắp tới (xanh dương)
  static const Color tripOngoing = Color(0xFF10B981);   // Đang diễn ra (xanh lá)
  static const Color tripCompleted = Color(0xFF64748B); // Đã xong (xám)
  static const Color tripCancelled = Color(0xFFEF4444); // Đã hủy (đỏ)

  // === SPECIAL ===
  static const Color shimmer = Color(0xFFE2E8F0);       // Loading shimmer
  static const Color overlay = Color(0x80000000);        // Overlay tối 50%
  static const Color star = Color(0xFFFBBF24);           // Sao đánh giá (vàng)
}
