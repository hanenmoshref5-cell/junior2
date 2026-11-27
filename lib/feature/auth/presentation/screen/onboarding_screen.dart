import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../core/routes/app_routes.dart';

/// بيانات كل شريحة في الأونبوردينج
class _OnboardingData {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String description;

  const _OnboardingData({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.description,
  });
}

/// شاشة التعريف بالتطبيق - تظهر عند أول فتح فقط
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showButton = false;

  final List<_OnboardingData> _slides = const [
    _OnboardingData(
      icon: Icons.favorite_rounded,
      iconBg: Color(0xFFFFE4E4),
      title: 'راقب سكرك بذكاء',
      description:
          'قس مستوى السكر في دمك باستخدام كاميرا هاتفك دون الحاجة لأي أدوات طبية إضافية',
    ),
    _OnboardingData(
      icon: Icons.show_chart_rounded,
      iconBg: Color(0xFFE4F0FF),
      title: 'تتبع تقدمك',
      description:
          'احتفظ بسجل كامل لقياساتك وشاهد تطور مستوى سكرك عبر الزمن من خلال رسوم بيانية واضحة',
    ),
    _OnboardingData(
      icon: Icons.restaurant_menu_rounded,
      iconBg: Color(0xFFE4FFE9),
      title: 'نصائح مخصصة لك',
      description:
          'احصل على برامج غذائية ونصائح صحية مصممة خصيصاً لحالتك الصحية ومستوى سكرك',
    ),
    _OnboardingData(
      icon: Icons.chat_rounded,
      iconBg: Color(0xFFFFF5E4),
      title: 'مساعدك الصحي',
      description:
          'اطرح أسئلتك الصحية واحصل على إجابات فورية من مساعدنا الذكي على مدار الساعة',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // تشغيل القلب التلقائي كل ثانيتين
    _startAutoPlay();
  }

  void _startAutoPlay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentPage < _slides.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startAutoPlay();
      } else {
        // آخر شريحة - إظهار الزر
        if (mounted) setState(() => _showButton = true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.beigeGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── زر تخطي ─────────────────────────────────────
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedOpacity(
                    opacity: _showButton ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: TextButton(
                      onPressed: () => Get.offAllNamed(AppRoutes.login),
                      child: Text(
                        'تخطي',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── الشرائح ──────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      if (index == _slides.length - 1) _showButton = true;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return _buildSlide(_slides[index]);
                  },
                ),
              ),

              // ── مؤشرات الصفحات ───────────────────────────────
              _buildPageIndicators(),

              const SizedBox(height: 32),

              // ── زر البدء ─────────────────────────────────────
              AnimatedOpacity(
                opacity: _showButton ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: AnimatedSlide(
                  offset: _showButton ? Offset.zero : const Offset(0, 0.5),
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        CustomButton(
                          label: 'ابدأ الآن',
                          onPressed: _showButton
                              ? () => Get.offAllNamed(AppRoutes.register)
                              : null,
                          type: ButtonType.primary,
                          icon: Icons.arrow_back_rounded,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'هل تمتلك حساباً بالفعل؟  ',
                              style: AppTextStyles.bodySmall,
                            ),
                            GestureDetector(
                              onTap: () => Get.offAllNamed(AppRoutes.login),
                              child: Text(
                                'سجّل الدخول',
                                style: AppTextStyles.accentText(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // أيقونة
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: data.iconBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.iconBg.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(data.icon, size: 64, color: AppColors.darkBrown),
          ),

          const SizedBox(height: 48),

          // العنوان
          Text(
            data.title,
            style: AppTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // الوصف
          Text(
            data.description,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _slides.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? AppColors.darkBrown : AppColors.lightGrey,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
