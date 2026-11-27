import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';

class _Tip {
  final String category, text;
  final IconData icon;
  const _Tip({required this.category, required this.text, required this.icon});
}

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});
  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  String _selected = 'الكل';

  final List<String> _categories = ['الكل', 'الرياضة', 'الطعام', 'رمضان', 'الروتين اليومي', 'أعراض الارتفاع', 'أعراض الانخفاض'];

  final List<_Tip> _tips = [
    _Tip(category: 'الرياضة', icon: Icons.directions_run_rounded, text: 'امشِ 30 دقيقة يومياً بعد العشاء لتحسين حساسية الأنسولين وخفض السكر.'),
    _Tip(category: 'الرياضة', icon: Icons.fitness_center_rounded, text: 'تمارين المقاومة 3 مرات أسبوعياً تساعد في التحكم بمستوى السكر على المدى البعيد.'),
    _Tip(category: 'الطعام', icon: Icons.no_drinks_rounded, text: 'تجنب المشروبات الغازية والعصائر المصنّعة فهي ترفع السكر بشكل سريع جداً.'),
    _Tip(category: 'الطعام', icon: Icons.set_meal_rounded, text: 'تناول وجبات صغيرة ومتكررة كل 3-4 ساعات للحفاظ على استقرار السكر في الدم.'),
    _Tip(category: 'الطعام', icon: Icons.local_dining_rounded, text: 'فضّل الكربوهيدرات المعقدة كالشوفان والأرز البني على الكربوهيدرات البسيطة.'),
    _Tip(category: 'رمضان', icon: Icons.celebration_rounded, text: 'راقب سكرك بانتظام خلال رمضان خصوصاً قبل الإفطار وبعده بساعتين.'),
    _Tip(category: 'رمضان', icon: Icons.water_drop_rounded, text: 'اشرب كمية كافية من الماء بين الإفطار والسحور للحفاظ على الترطيب.'),
    _Tip(category: 'الروتين اليومي', icon: Icons.bedtime_rounded, text: 'النوم الجيد 7-8 ساعات يساعد في تنظيم مستوى السكر والهرمونات.'),
    _Tip(category: 'الروتين اليومي', icon: Icons.self_improvement_rounded, text: 'تجنب التوتر والضغط النفسي فهو يرفع سكر الدم بشكل ملحوظ.'),
    _Tip(category: 'أعراض الارتفاع', icon: Icons.warning_rounded, text: 'كثرة التبول والعطش الشديد والتعب قد تكون علامات على ارتفاع السكر.'),
    _Tip(category: 'أعراض الارتفاع', icon: Icons.visibility_off_rounded, text: 'ضبابية الرؤية والصداع المستمر قد يدلان على ارتفاع مستوى السكر.'),
    _Tip(category: 'أعراض الانخفاض', icon: Icons.bolt_rounded, text: 'الرجفة والتعرق المفاجئ والشعور بالجوع الشديد قد تكون أعراض هبوط السكر.'),
    _Tip(category: 'أعراض الانخفاض', icon: Icons.psychology_rounded, text: 'التشويش الذهني وصعوبة التركيز من أعراض انخفاض السكر، تناول شيئاً حلواً فوراً.'),
  ];

  List<_Tip> get _filtered => _selected == 'الكل' ? _tips : _tips.where((t) => t.category == _selected).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('النصائح الصحية'),
        leading: IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded), onPressed: () => Get.back()),
      ),
      body: Column(
        children: [
          // فلتر الفئات
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isSelected = _selected == _categories[i];
                return GestureDetector(
                  onTap: () => setState(() => _selected = _categories[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.darkBrown : AppColors.lightBeige,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.darkBrown : AppColors.divider),
                    ),
                    child: Text(_categories[i],
                        style: AppTextStyles.label.copyWith(
                          color: isSelected ? AppColors.white : AppColors.grey,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ),
                );
              },
            ),
          ),

          // قائمة النصائح
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final tip = _filtered[i];
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
                      Expanded(child: Text(tip.text, style: AppTextStyles.bodyMedium, textAlign: TextAlign.right)),
                      const SizedBox(width: 14),
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AppColors.lightBeige, shape: BoxShape.circle),
                        child: Icon(tip.icon, color: AppColors.darkBrown, size: 22),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
