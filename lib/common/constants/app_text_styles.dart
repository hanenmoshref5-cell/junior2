import 'package:flutter/material.dart';
import 'app_colors.dart';

/// أنماط النصوص المستخدمة في التطبيق
/// الخط المستخدم: Cairo - خط عربي جميل وعصري
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Cairo';

  // ── عناوين رئيسية ─────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.darkBrown,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.darkBrown,
    height: 1.3,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.darkBrown,
    height: 1.4,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.darkBrown,
    height: 1.4,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.darkBrown,
    height: 1.4,
  );

  // ── نصوص عادية ────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.darkBrown,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.darkBrown,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.grey,
    height: 1.5,
  );

  // ── نصوص الأزرار ──────────────────────────────────────────────
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  // ── نصوص مساعدة ───────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.grey,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumBrown,
  );

  static const TextStyle hint = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.grey,
  );

  // ── نصوص الأرقام والقياسات ────────────────────────────────────
  static const TextStyle measurementValue = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: AppColors.darkBrown,
    height: 1.0,
  );

  static const TextStyle measurementUnit = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.grey,
  );

  // ── نصوص ملونة جاهزة ──────────────────────────────────────────
  static TextStyle accentText({double fontSize = 14}) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: AppColors.accent,
  );

  static TextStyle whiteText({double fontSize = 14, FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize,
    fontWeight: weight,
    color: AppColors.white,
  );

  static TextStyle coloredText({required Color color, double fontSize = 14, FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize,
    fontWeight: weight,
    color: color,
  );
}
