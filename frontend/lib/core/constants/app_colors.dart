import 'package:flutter/material.dart';

/// Travel Palette: White cards, charcoal actions and energetic lime green accents (#D6F248).
class AppColors {
  AppColors._();

  // === Primary & Action ===
  static const primary = Color(0xFF1E3A2F);
  static const primaryDark = Color(0xFF12241D);
  static const primaryLight = Color(0xFF2E5948);
  static const primarySurface = Color(0xFFEAF5F0);
  static const action = Color(0xFF1B1D1F);

  // === Lime Accent (Hero visual from travel design reference) ===
  static const lime = Color(0xFFD6F248);
  static const limeLight = Color(0xFFE5F87B);
  static const limeDark = Color(0xFFA5C118);
  static const limeSurface = Color(0xFFF4FBD6);

  static const accent = Color(0xFFD6F248);
  static const accentLight = Color(0xFFE5F87B);
  static const accentSurface = Color(0xFFF4FBD6);

  // === Neutrals ===
  static const textPrimary = Color(0xFF171717);
  static const textSecondary = Color(0xFF6B7275);
  static const textHint = Color(0xFF9CA3AF);
  static const textOnPrimary = Colors.white;
  static const background = Color(0xFFF7F8F6);
  static const surface = Colors.white;
  static const divider = Color(0xFFECEEED);
  static const border = Color(0xFFE2E5E3);

  // === Status ===
  static const success = Color(0xFF1E824C);
  static const successSurface = Color(0xFFEAF6EE);
  static const warning = Color(0xFF946000);
  static const warningSurface = Color(0xFFFFF5D9);
  static const error = Color(0xFFB63737);
  static const errorSurface = Color(0xFFFCEEEE);
  static const info = Color(0xFF3464A1);
  static const infoSurface = Color(0xFFEDF3FC);

  // === Trips ===
  static const tripUpcoming = info;
  static const tripOngoing = success;
  static const tripCompleted = textSecondary;
  static const tripCancelled = error;

  // === Visual Effects ===
  static const shimmer = Color(0xFFE8ECE9);
  static const overlay = Color(0x66000000);
  static const star = Color(0xFFFFBF16);
  static const glassDark = Color(0x99171717);
  static const glassLight = Color(0xD9FFFFFF);
}
