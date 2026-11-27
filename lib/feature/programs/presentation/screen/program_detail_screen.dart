import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({super.key});

  Map<String, dynamic> _getContent(String type) {
    switch (type) {
      case 'ارتفاع السكر الشديد':
        return {
          'color': AppColors.sugarVeryHigh,
          'icon': Icons.warning_rounded,
          'advice':
              'يجب عليك قطع السكر نهائياً والإكثار من شرب الماء والخضروات الورقية، وممارسة المشي الخفيف يومياً.',
          'breakfast':
              'بيضتان مسلوقتان + عشر زيتونات + ملعقة لبن كبيرة + ربع رغيف أسمر',
          'lunch': 'صدر دجاج مشوي + ثلث كوب أرز بني + صحن سلطة خضراء',
          'dinner': 'تونة بالماء + خضروات مشوية + كوب شاي أخضر',
        };
      case 'ارتفاع السكر':
        return {
          'color': AppColors.sugarHigh,
          'icon': Icons.trending_up_rounded,
          'advice':
              'قلل من السكريات والنشويات البيضاء، وحرص على ممارسة الرياضة 30 دقيقة يومياً.',
          'breakfast': 'شوفان بالحليب قليل الدسم + حبة فاكهة صغيرة',
          'lunch': 'سمك مشوي + خضروات مطبوخة + نصف كوب أرز',
          'dinner': 'بيضتان + جبنة قليلة الملح + خضراوات نيئة',
        };
      case 'الحالة الطبيعية':
        return {
          'color': AppColors.sugarNormal,
          'icon': Icons.check_circle_rounded,
          'advice':
              'أنت بصحة جيدة! استمر في نمط حياتك الصحي وحافظ على التوازن الغذائي.',
          'breakfast': 'بيضتان + جبنة + زيتون + رغيف أسمر',
          'lunch': 'دجاج أو سمك + أرز + سلطة',
          'dinner': 'لبن + فاكهة أو خضروات',
        };
      case 'انخفاض السكر':
        return {
          'color': AppColors.sugarLow,
          'icon': Icons.trending_down_rounded,
          'advice':
              'تناول وجبات صغيرة ومتكررة وتجنب الفراغ الطويل بين الوجبات.',
          'breakfast': 'عصير فاكهة طبيعي + خبز بالعسل + لبن',
          'lunch': 'دجاج بالخضروات + كوب أرز + عصير',
          'dinner': 'موز أو تمر + كوب حليب',
        };
      default:
        return {
          'color': AppColors.sugarVeryLow,
          'icon': Icons.arrow_downward_rounded,
          'advice': 'تناول السكر أو العصير فوراً ثم راجع الطبيب في أقرب وقت.',
          'breakfast': 'عصير برتقال + ملعقتان سكر + تمرات',
          'lunch': 'وجبة كاملة تحتوي كربوهيدرات وبروتين',
          'dinner': 'حليب كامل الدسم + فاكهة',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final type = args?['type'] as String? ?? 'الحالة الطبيعية';
    final content = _getContent(type);
    final color = content['color'] as Color;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(type),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // بطاقة الحالة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'أنت الآن في حالة: $type',
                          style: AppTextStyles.headlineMedium,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(content['icon'] as IconData, color: color, size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content['advice'] as String,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('النظام الغذائي المقترح', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 16),

            _MealCard(
              meal: 'الفطور',
              icon: Icons.wb_sunny_rounded,
              color: const Color(0xFFF59E0B),
              content: content['breakfast'] as String,
            ),
            const SizedBox(height: 12),
            _MealCard(
              meal: 'الغداء',
              icon: Icons.restaurant_rounded,
              color: const Color(0xFF10B981),
              content: content['lunch'] as String,
            ),
            const SizedBox(height: 12),
            _MealCard(
              meal: 'العشاء',
              icon: Icons.nightlight_round,
              color: const Color(0xFF6366F1),
              content: content['dinner'] as String,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final String meal, content;
  final IconData icon;
  final Color color;
  const _MealCard({
    required this.meal,
    required this.icon,
    required this.color,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              content,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(meal, style: AppTextStyles.label),
            ],
          ),
        ],
      ),
    );
  }
}
