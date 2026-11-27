import 'package:flutter/material.dart';
import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';

/// بطاقة زر القائمة الرئيسية
class HomeMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const HomeMenuCard({
    super.key,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBrown.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            splashColor: AppColors.accent.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الأيقونة
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                  const SizedBox(height: 10),
                  // التسمية
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
