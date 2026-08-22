import 'package:flutter/material.dart';

/// Centralized color palette for SafeGuard.
///
/// Light, trustworthy travel-safety visual direction:
/// - white / very light backgrounds
/// - dark navy primary text
/// - muted gray secondary text
/// - teal/green as the primary brand accent
/// - semantic status colors: safe (green), warning (orange),
///   danger (red), information (blue)
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F5);

  // Brand accent (teal/green)
  static const Color accent = Color(0xFF0F6E5B);
  static const Color accentDark = Color(0xFF0B4F42);

  // Text
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);

  // Structure
  static const Color border = Color(0xFFE4E7EC);

  // Semantic status colors
  static const Color safe = Color(0xFF1B8A4A);
  static const Color safeSurface = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFEF3E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFEAF1FE);

  // Reserved for emergency / danger / destructive actions only
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFDECEC);
}