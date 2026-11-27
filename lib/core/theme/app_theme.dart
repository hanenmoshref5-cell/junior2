import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/constants/app_colors.dart';
import '../../common/constants/app_text_styles.dart';

/// ثيم التطبيق الموحد
class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkBrown,
      primary: AppColors.darkBrown,
      secondary: AppColors.accent,
      surface: AppColors.lightBeige,
      background: AppColors.cream,
      error: AppColors.sugarVeryHigh,
    ),
    scaffoldBackgroundColor: AppColors.cream,

    // ── AppBar ────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBrown,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.headlineMedium,
      iconTheme: IconThemeData(color: AppColors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),

    // ── Card ──────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── ElevatedButton ────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkBrown,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        textStyle: AppTextStyles.buttonLarge,
        minimumSize: const Size(double.infinity, 54),
      ),
    ),

    // ── OutlinedButton ────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkBrown,
        side: const BorderSide(color: AppColors.darkBrown, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(double.infinity, 54),
        textStyle: AppTextStyles.buttonLarge,
      ),
    ),

    // ── TextButton ────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppTextStyles.buttonMedium.copyWith(color: AppColors.accent),
      ),
    ),

    // ── InputDecoration ───────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightBeige,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.sugarVeryHigh,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: AppTextStyles.hint,
      labelStyle: AppTextStyles.label,
    ),

    // ── BottomSheet ───────────────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),

    // ── Divider ───────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 0,
    ),

    // ── Dialog ────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: AppTextStyles.headlineMedium,
      contentTextStyle: AppTextStyles.bodyMedium,
    ),

    // ── SnackBar ──────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.white,
      ),
    ),
  );
}
