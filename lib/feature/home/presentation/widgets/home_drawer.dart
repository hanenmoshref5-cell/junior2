import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../../core/routes/app_routes.dart';
import '../../business/controller/home_controller.dart';

/// الدرج الجانبي للصفحة الرئيسية
class HomeDrawer extends StatelessWidget {
  final HomeController controller;

  const HomeDrawer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cream,
      child: Column(
        children: [
          // ── رأس الدرج ────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // صورة المستخدم
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Get.toNamed(AppRoutes.profile);
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent,
                            width: 2.5,
                          ),
                          color: AppColors.mediumBrown,
                        ),
                        child: controller.userImageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  controller.userImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.white,
                                      size: 36,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                color: AppColors.white,
                                size: 36,
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // اسم المستخدم
                    Text(
                      controller.userName,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Get.toNamed(AppRoutes.profile);
                      },
                      child: Text(
                        'تعديل الملف الشخصي',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── قائمة الروابط ────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _DrawerItem(
                  icon: Icons.home_rounded,
                  label: 'الرئيسية',
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.show_chart_rounded,
                  label: 'سجل القياسات',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed(AppRoutes.history);
                  },
                ),
                _DrawerItem(
                  icon: Icons.person_rounded,
                  label: 'الملف الشخصي',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed(AppRoutes.profile);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(),
                ),
                _DrawerItem(
                  icon: Icons.language_rounded,
                  label: 'اللغة',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'قريباً',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),

          // ── زر الخروج ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                controller.logout();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.sugarVeryHigh.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.sugarVeryHigh.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: AppColors.sugarVeryHigh,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'تسجيل الخروج',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.sugarVeryHigh,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.lightBeige,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.darkBrown, size: 20),
      ),
      title: Text(label, style: AppTextStyles.headlineSmall),
      trailing:
          trailing ??
          const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.grey,
            size: 16,
          ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
