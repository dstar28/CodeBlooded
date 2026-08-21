import 'package:flutter/material.dart';

/// Centralized color palette for SafeGuard.
///
/// Dark, safety-oriented visual direction:
/// - navy background
/// - deep blue surfaces
/// - cyan/blue accent as the primary brand color
/// - red/pink reserved for emergency & destructive actions only
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF131A2C);
  static const Color surfaceVariant = Color(0xFF1A2338);

  // Brand accent
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentDark = Color(0xFF0EA5C4);

  // Text
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF8B95A7);

  // Structure
  static const Color border = Color(0xFF232B42);

  // Reserved for emergency / danger / destructive actions only
  static const Color danger = Color(0xFFFF4D6D);
}