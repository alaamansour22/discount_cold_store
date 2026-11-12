import 'package:flutter/material.dart';
import '../constants/app_assets.dart';

/// كلاس الألوان الموحد الشامل لجميع الشاشات والـ Widgets
class AppColors {
  const AppColors._();

  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color secondarySlate = Color(0xFF1E293B);
  static const Color secondaryBlue = Color(0xFF1D4ED8);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color zoneC2Blue = Color(0xFF1D4ED8);
  static const Color zoneC3Teal = Color(0xFF0F766E);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color mixedPurple = Color(0xFF7E22CE);
  static const Color scaffoldBackground = Color(0xFFF1F5F9);
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color cardBackground = Colors.white;
  static const Color cardWhite = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);
}

class AppTheme {
  const AppTheme._();

  // متوفرة أيضاً عبر AppTheme مباشرة لضمان التوافق التام في كل الملفات
  static const Color primaryNavy = AppColors.primaryNavy;
  static const Color secondarySlate = AppColors.secondarySlate;
  static const Color secondaryBlue = AppColors.secondaryBlue;
  static const Color accentCyan = AppColors.accentCyan;
  static const Color zoneC2Blue = AppColors.zoneC2Blue;
  static const Color zoneC3Teal = AppColors.zoneC3Teal;
  static const Color successGreen = AppColors.successGreen;
  static const Color warningAmber = AppColors.warningAmber;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color mixedPurple = AppColors.mixedPurple;
  static const Color scaffoldBackground = AppColors.scaffoldBackground;
  static const Color surfaceLight = AppColors.surfaceLight;
  static const Color cardBackground = AppColors.cardBackground;
  static const Color cardWhite = AppColors.cardWhite;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color borderLight = AppColors.borderLight;

  static double responsiveTextScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 1.08;
    if (width >= 800) return 1.02;
    if (width < 360) return 0.90;
    return 1.0;
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppAssets.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: zoneC2Blue,
        primary: zoneC2Blue,
        secondary: accentCyan,
        error: dangerRed,
        surface: cardBackground,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppAssets.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 1.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: zoneC2Blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: AppAssets.fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}