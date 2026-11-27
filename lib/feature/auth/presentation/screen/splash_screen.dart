import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/routes/app_routes.dart';
import '../../business/controller/auth_controller.dart';
import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';

/// شاشة البداية - تظهر عند كل فتح للتطبيق
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );

    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // التحقق من الجلسة أو عرض الأونبوردينج عند أول تشغيل
    final authController = Get.put(AuthController());
    _handleStartup(authController);
  }

  Future<void> _handleStartup(AuthController authController) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    
    if (!hasSeenOnboarding) {
      await prefs.setBool('hasSeenOnboarding', true);
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    authController.checkSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── الشعار ──────────────────────────────────
                    Transform.scale(
                      scale: _scaleAnim.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              gradient: AppColors.accentGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: AppColors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── اسم التطبيق ──────────────────────────────
                    Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: Column(
                          children: [
                            Text(
                              'قياس السكر',
                              style: AppTextStyles.displayLarge.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'راقب صحتك بذكاء',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.beige.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ── مؤشر التحميل ─────────────────────────────
                    Opacity(
                      opacity: _fadeAnim.value,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2.5,
                          backgroundColor: AppColors.white.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
