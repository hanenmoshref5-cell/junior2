import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../../core/routes/app_routes.dart';
import '../../business/controller/home_controller.dart';
import '../widgets/home_drawer.dart';
import '../widgets/home_menu_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    // تحديث البيانات عند الرجوع للشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.refreshLatestMeasurement();
    });

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.cream,
      drawer: HomeDrawer(controller: controller),
      body: CustomScrollView(
        slivers: [
          // ── AppBar بسيط ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppColors.darkBrown,
            surfaceTintColor: AppColors.darkBrown,
            automaticallyImplyLeading: false,
            title: Text(
              'لوحة التحكم',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.white,
              ),
            ),
            leading: GestureDetector(
              onTap: () => scaffoldKey.currentState?.openDrawer(),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_rounded, color: AppColors.white),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.white,
                ),
                onPressed: () {},
              ),
            ],
          ),

          // ── كتلة الترحيب والصورة واسم المستخدم ──────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(color: AppColors.darkBrown),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Get.toNamed(AppRoutes.profile),
                        child: Container(
                          width: 64,
                          height: 64,
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
                                        size: 32,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.white,
                                  size: 32,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مرحباً 👋',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.beige.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Obx(
                              () => Text(
                                controller.userName,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: AppColors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── بطاقة ملخص السكر ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _GlucoseSummaryCard(controller: controller),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
              child: Text('الخدمات', style: AppTextStyles.headlineLarge),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                HomeMenuCard(
                  icon: Icons.fingerprint_rounded,
                  label: 'قياس من الكاميرا',
                  iconColor: const Color(0xFF4CAF82),
                  iconBg: const Color(0xFFE8F5EE),
                  onTap: () => Get.toNamed(AppRoutes.measureFinger),
                ),
                HomeMenuCard(
                  icon: Icons.edit_note_rounded,
                  label: 'إدخال قياس يدوي',
                  iconColor: AppColors.accent,
                  iconBg: const Color(0xFFFFF3E0),
                  onTap: () => Get.toNamed(AppRoutes.manualInput),
                ),
                HomeMenuCard(
                  icon: Icons.medical_services_rounded,
                  label: 'البرامج الصحية',
                  iconColor: const Color(0xFF5B9BD5),
                  iconBg: const Color(0xFFE3F0FB),
                  onTap: () => Get.toNamed(AppRoutes.programs),
                ),
                HomeMenuCard(
                  icon: Icons.lightbulb_rounded,
                  label: 'النصائح الصحية',
                  iconColor: const Color(0xFFE07B54),
                  iconBg: const Color(0xFFFAEDE7),
                  onTap: () => Get.toNamed(AppRoutes.tips),
                ),
                HomeMenuCard(
                  icon: Icons.chat_bubble_rounded,
                  label: 'المساعد الصحي',
                  iconColor: const Color(0xFF8B6355),
                  iconBg: const Color(0xFFF2EBE8),
                  onTap: () => Get.toNamed(AppRoutes.chatbot),
                ),
                HomeMenuCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'سجل القياسات',
                  iconColor: const Color(0xFF9C7EC4),
                  iconBg: const Color(0xFFF1EBF8),
                  onTap: () => Get.toNamed(AppRoutes.history),
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlucoseSummaryCard extends StatelessWidget {
  final HomeController controller;
  const _GlucoseSummaryCard({required this.controller});

  Color get _cardColor {
    final m = controller.latestMeasurement.value;
    if (m == null) return const Color(0xFF4CAF82);
    switch (m.status) {
      case 'high':
        return AppColors.sugarHigh;
      case 'very_high':
        return AppColors.sugarVeryHigh;
      case 'low':
        return AppColors.sugarLow;
      case 'very_low':
        return AppColors.sugarVeryLow;
      default:
        return const Color(0xFF4CAF82);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final m = controller.latestMeasurement.value;
      final color = _cardColor;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'آخر قراءة',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white.withOpacity(0.8),
                      ),
                    ),
                    if (m != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          m.statusLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      m != null ? '${m.value.toInt()}' : '--',
                      style: AppTextStyles.measurementValue.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 6),
                      child: Text(
                        'mg/dL',
                        style: AppTextStyles.measurementUnit.copyWith(
                          color: AppColors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (m == null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'لا توجد قراءات بعد',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.white,
                size: 36,
              ),
            ),
          ],
        ),
      );
    });
  }
}
