import 'package:flutter/material.dart';

/// Global palette for Alight Creators (dark mode only).
class AppColors {
  static const background = Color(0xFF0C121D);
  static const surface = Color(0xFF151D29);

  /// Cyan — matches the web's `--primary` (hsl 190 100% 50%).
  static const accent = Color(0xFF00D2FF);

  /// Bright purple — matches the web's `--secondary` (hsl 281 84% 65%).
  /// Used for the "Advanced" badge.
  static const secondary = Color(0xFFC15BF1);

  /// Mint / teal — matches the web's `--accent` (hsl 165 100% 50%).
  /// Used for the "Beginner" badge.
  static const accentMint = Color(0xFF00FFBF);

  static const border = Color(0xFF1E293B);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);
  static const danger = Color(0xFFEF4444);
  static const maleBlue = Color(0xFF2E86FF);
  static const femalePink = Color(0xFFFF4FD8);
}

/// Comfortable "p-6" style padding used across screens.
const kScreenPadding = EdgeInsets.all(24);

/// Phone-shaped max width, mirroring `max-w-md` on the web.
const kPhoneMaxWidth = 448.0;

/// Local font family declared in pubspec.yaml (no network needed).
const kFontFamily = 'VarelaRound';

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: base.textTheme
        .apply(
          fontFamily: kFontFamily,
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: kFontFamily),
    splashColor: AppColors.accent.withValues(alpha: 0.08),
    highlightColor: AppColors.accent.withValues(alpha: 0.05),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontFamily: kFontFamily,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}