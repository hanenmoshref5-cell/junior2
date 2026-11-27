import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';

class _ProgramItem {
  final String title, subtitle, route;
  final Color color;
  final IconData icon;
  const _ProgramItem({required this.title, required this.subtitle, required this.route, required this.color, required this.icon});
}

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  static final List<_ProgramItem> _programs = [
    _ProgramItem(title: 'ارتفاع السكر الشديد', subtitle: '> 300 mg/dL', route: '/program-detail', color: AppColors.sugarVeryHigh, icon: Icons.arrow_upward_rounded),
    _ProgramItem(title: 'ارتفاع السكر', subtitle: '200 - 300 mg/dL', route: '/program-detail', color: AppColors.sugarHigh, icon: Icons.trending_up_rounded),
    _ProgramItem(title: 'الحالة الطبيعية', subtitle: '70 - 140 mg/dL', route: '/program-detail', color: AppColors.sugarNormal, icon: Icons.check_circle_rounded),
    _ProgramItem(title: 'انخفاض السكر', subtitle: '55 - 70 mg/dL', route: '/program-detail', color: AppColors.sugarLow, icon: Icons.trending_down_rounded),
    _ProgramItem(title: 'انخفاض السكر الشديد', subtitle: '< 55 mg/dL', route: '/program-detail', color: AppColors.sugarVeryLow, icon: Icons.arrow_downward_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('البرامج الصحية'),
        leading: IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded), onPressed: () => Get.back()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('اختر حالتك للحصول على برنامج مخصص', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _programs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final p = _programs[i];
                  return GestureDetector(
                    onTap: () => Get.toNamed(p.route, arguments: {'type': p.title}),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.color.withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(color: p.color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back_ios_rounded, color: AppColors.grey, size: 16),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(p.title, style: AppTextStyles.headlineSmall),
                              Text(p.subtitle, style: AppTextStyles.caption),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: p.color.withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(p.icon, color: p.color, size: 24),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
