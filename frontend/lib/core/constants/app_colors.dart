import 'package:flutter/material.dart';

/// Coastal travel palette shared by all presentation components.
class AppColors {
  AppColors._();
  static const primary = Color(0xFF0077E6);
  static const primaryDark = Color(0xFF0055C4);
  static const primaryLight = Color(0xFF13B5FA);
  static const primarySurface = Color(0xFFE3F4FF);
  static const action = primary;
  static const accent = primary;
  static const accentLight = primaryLight;
  static const accentSurface = primarySurface;
  // Compatibility aliases for existing team components.
  static const lime = accent;
  static const limeLight = accentLight;
  static const limeDark = primaryDark;
  static const limeSurface = accentSurface;
  static const textPrimary = Color(0xFF09143B);
  static const textSecondary = Color(0xFF5D6889);
  static const textHint = Color(0xFF969DB3);
  static const textOnPrimary = Colors.white;
  static const background = Color(0xFFF0FAFF);
  static const surface = Colors.white;
  static const inputSurface = Color(0xFFF8FAFD);
  static const primaryBorder = Color(0xFFBADDFF);
  static const primaryText = primaryDark;
  static const loadingOverlay = Color(0xCCF0FAFF);
  static const divider = Color(0xFFE8EDF5);
  static const border = Color(0xFFDEE4EF);
  static const success = Color(0xFF008B57);
  static const successSurface = Color(0xFFEDF7ED);
  static const warning = Color(0xFF946000);
  static const warningSurface = Color(0xFFFFF5D9);
  static const error = Color(0xFFE53946);
  static const errorSurface = Color(0xFFFCEEEE);
  static const info = Color(0xFF0066D6);
  static const infoSurface = Color(0xFFEDF3FC);
  static const tripUpcoming = info;
  static const tripOngoing = success;
  static const tripCompleted = textSecondary;
  static const tripCancelled = error;
  static const shimmer = Color(0xFFD9E8F6);
  static const overlay = Color(0x66000000);
  static const star = Color(0xFFFFBF16);
  static const glassDark = Color(0x9909143B);
  static const glassLight = Color(0xD9FFFFFF);
}
