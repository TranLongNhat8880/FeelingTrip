import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();
  static ThemeData get lightTheme {
    final text = AppTypography.textTheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return ThemeData(
      useMaterial3: true,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textHint,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.buttonHeight),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.textPrimary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
        ),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surface,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.textOnPrimary),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: AppColors.inputSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.textHint),
        labelStyle: text.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        suffixIconColor: AppColors.textHint,
        prefixIconColor: AppColors.textHint,
        errorMaxLines: 3,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        ),
        checkmarkColor: AppColors.textOnPrimary,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.textOnPrimary
                : AppColors.textPrimary,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.sheetRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.sheetRadius),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.action,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(primary: AppColors.primaryLight),
    textTheme: AppTypography.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}
