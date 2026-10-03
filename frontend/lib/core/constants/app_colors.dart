import 'package:flutter/material.dart';

/// Light travel palette, orange actions and understated neutral surfaces.
class AppColors {
  AppColors._();
  static const primary = Color(0xFFED6426);
  static const primaryDark = Color(0xFFC84F17);
  static const primaryLight = Color(0xFFFF925C);
  static const primarySurface = Color(0xFFFFF1EB);
  static const action = primary;
  static const accent = primary;
  static const accentLight = primaryLight;
  static const accentSurface = primarySurface;
  // Compatibility aliases for existing team components.
  static const lime = accent;
  static const limeLight = accentLight;
  static const limeDark = primaryDark;
  static const limeSurface = accentSurface;
  static const textPrimary = Color(0xFF292929);
  static const textSecondary = Color(0xFF727272);
  static const textHint = Color(0xFF999999);
  static const textOnPrimary = Colors.white;
  static const background = Color(0xFFF7F7F7);
  static const surface = Colors.white;
  static const inputSurface = Color(0xFFFAFAFA);
  static const primaryBorder = Color(0xFFFFD4BE);
  static const primaryText = primaryDark;
  static const loadingOverlay = Color(0xCCF7F7F7);
  static const divider = Color(0xFFEEEEEE);
  static const border = Color(0xFFE7E7E7);
  static const success = Color(0xFF388E3C);
  static const successSurface = Color(0xFFEDF7ED);
  static const warning = Color(0xFF946000);
  static const warningSurface = Color(0xFFFFF5D9);
  static const error = Color(0xFFB63737);
  static const errorSurface = Color(0xFFFCEEEE);
  static const info = Color(0xFF3464A1);
  static const infoSurface = Color(0xFFEDF3FC);
  static const tripUpcoming = info;
  static const tripOngoing = success;
  static const tripCompleted = textSecondary;
  static const tripCancelled = error;
  static const shimmer = Color(0xFFECECEC);
  static const overlay = Color(0x66000000);
  static const star = Color(0xFFFFBF16);
  static const glassDark = Color(0x99292929);
  static const glassLight = Color(0xD9FFFFFF);
}
