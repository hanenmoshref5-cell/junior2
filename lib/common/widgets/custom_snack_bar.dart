import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum SnackBarType { success, error, warning, info }

/// مساعد عرض الـ SnackBar في التطبيق
class CustomSnackBar {
  CustomSnackBar._();

  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final config = _getConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: AppColors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        backgroundColor: config.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: duration,
        elevation: 6,
      ),
    );
  }

  // دوال مختصرة
  static void success(BuildContext context, String message) =>
      show(context: context, message: message, type: SnackBarType.success);

  static void error(BuildContext context, String message) =>
      show(context: context, message: message, type: SnackBarType.error);

  static void warning(BuildContext context, String message) =>
      show(context: context, message: message, type: SnackBarType.warning);

  static void info(BuildContext context, String message) =>
      show(context: context, message: message, type: SnackBarType.info);

  static _SnackBarConfig _getConfig(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _SnackBarConfig(
          color: AppColors.sugarNormal,
          icon: Icons.check_circle_rounded,
        );
      case SnackBarType.error:
        return _SnackBarConfig(
          color: AppColors.sugarVeryHigh,
          icon: Icons.error_rounded,
        );
      case SnackBarType.warning:
        return _SnackBarConfig(
          color: AppColors.accent,
          icon: Icons.warning_rounded,
        );
      case SnackBarType.info:
        return _SnackBarConfig(
          color: AppColors.mediumBrown,
          icon: Icons.info_rounded,
        );
    }
  }
}

class _SnackBarConfig {
  final Color color;
  final IconData icon;
  const _SnackBarConfig({required this.color, required this.icon});
}
