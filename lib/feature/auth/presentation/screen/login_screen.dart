import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/widgets/custom_text_field.dart';
import '../../../../core/routes/app_routes.dart';
import '../../business/controller/auth_controller.dart';

/// شاشة تسجيل الدخول
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(
      builder: (controller) {
        final formKey = GlobalKey<FormState>();

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // ── رأس الصفحة ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(36),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: AppColors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'مرحباً بعودتك',
                            style: AppTextStyles.displayLarge.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'سجّل دخولك لمتابعة صحتك',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.beige.withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── النموذج ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        CustomTextField(
                          label: 'البريد الإلكتروني',
                          hint: 'example@email.com',
                          controller: controller.emailController,
                          prefixIcon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: controller.validateEmail,
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 20),

                        CustomTextField(
                          label: 'كلمة المرور',
                          hint: 'أدخل كلمة المرور',
                          controller: controller.passwordController,
                          prefixIcon: Icons.lock_rounded,
                          isPassword: true,
                          validator: controller.validatePassword,
                          textInputAction: TextInputAction.done,
                        ),

                        const SizedBox(height: 12),

                        // نسيت كلمة المرور
                        // Align(
                        //   alignment: Alignment.centerLeft,
                        //   child: GestureDetector(
                        //     onTap: () => Get.toNamed(AppRoutes.resetPassword),
                        //     child: Text(
                        //       'نسيت كلمة المرور؟',
                        //       style: AppTextStyles.accentText(fontSize: 13),
                        //     ),
                        //   ),
                        // ),

                        const SizedBox(height: 32),

                        // زر الدخول
                        Obx(
                          () => CustomButton(
                            label: 'تسجيل الدخول',
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                controller.login(context);
                              }
                            },
                            isLoading: controller.isLoginLoading.value,
                            icon: Icons.login_rounded,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // فاصل
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text('أو', style: AppTextStyles.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // إنشاء حساب
                        CustomButton(
                          label: 'إنشاء حساب جديد',
                          onPressed: () => Get.toNamed(AppRoutes.register),
                          type: ButtonType.outline,
                          icon: Icons.person_add_rounded,
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
