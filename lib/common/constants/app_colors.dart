import 'package:flutter/material.dart';

/// ألوان التطبيق الرئيسية
class AppColors {
  AppColors._();

  // ── الألوان الأساسية ──────────────────────────────────────────
  static const Color darkBrown = Color(0xFF3F3837);
  static const Color mediumBrown = Color(0xFF6B4F4A);
  static const Color lightBrown = Color(0xFF8B6355);
  static const Color beige = Color(0xFFE8DCC4);
  static const Color lightBeige = Color(0xFFF5F0E6);
  static const Color cream = Color(0xFFFAF7F2);

  // ── لون التمييز (Accent) ──────────────────────────────────────
  static const Color accent = Color(0xFFBE8A4A);
  static const Color accentLight = Color(0xFFD4A96A);
  static const Color accentDark = Color(0xFF9A6A30);

  // ── ألوان الحالة الصحية ───────────────────────────────────────
  static const Color sugarNormal = Color(0xFF4CAF82); // طبيعي  - أخضر دافئ
  static const Color sugarHigh = Color(0xFFE07B54); // مرتفع  - برتقالي
  static const Color sugarVeryHigh = Color(0xFFD64444); // مرتفع جداً - أحمر
  static const Color sugarLow = Color(0xFF5B9BD5); // منخفض  - أزرق
  static const Color sugarVeryLow = Color(0xFF3A6EA8); // منخفض جداً

  // ── ألوان محايدة ──────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF1A1410);
  static const Color grey = Color(0xFF9E9589);
  static const Color lightGrey = Color(0xFFD4CFC8);
  static const Color divider = Color(0xFFEAE5DC);

  // ── ألوان الإجراءات والحالات ───────────────────────────────
  static const Color red = Color.fromARGB(255, 220, 53, 69);

  // ── تدرجات لونية ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [darkBrown, mediumBrown],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentDark, accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient beigeGradient = LinearGradient(
    colors: [lightBeige, cream],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFF5F0E6), Color(0xFFEDE5D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
