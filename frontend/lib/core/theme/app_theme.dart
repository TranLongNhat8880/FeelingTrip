import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

// ================================================================================
// CẤU HÌNH THEME CỦA APP – Tông Teal + Coral
// ================================================================================

class AppTheme {
  AppTheme._();

  // === LIGHT THEME ===
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.textOnPrimary,
          secondary: AppColors.accent,
          onSecondary: AppColors.textOnPrimary,
          error: AppColors.error,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnPrimary,
          ),
        ),

        // Elevated Button (nút chính)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            minimumSize: const Size(double.infinity, 50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Outlined Button (nút phụ)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Text Button
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // FAB (nút tròn nổi – dùng màu Coral)
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 4,
          shape: CircleBorder(),
        ),

        // Input (ô nhập liệu)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          hintStyle: const TextStyle(color: AppColors.textHint),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
        ),

        // Card
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),

        // Chip (tag nhỏ)
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.primarySurface,
          labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        // Bottom Navigation Bar
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),

        // Divider
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      );

  // === DARK THEME (mở rộng sau) ===
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          secondary: AppColors.accent,
          error: AppColors.error,
          surface: Color(0xFF1E293B), // Slate 800
        ),
      );
}
