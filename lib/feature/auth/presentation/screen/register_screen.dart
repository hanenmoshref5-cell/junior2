import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/widgets/custom_text_field.dart';
import '../../../../core/routes/app_routes.dart';
import '../../business/controller/auth_controller.dart';
import '../widgets/gender_selector.dart';

/// شاشة إنشاء الحساب
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(
      builder: (controller) {
        final formKey = GlobalKey<FormState>();

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            slivers: [
              // ── رأس الصفحة ────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.darkBrown,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: 30),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_add_rounded,
                                color: AppColors.accent,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'إنشاء حساب جديد',
                              style: AppTextStyles.displayMedium.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              'أدخل بياناتك للبدء',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.beige.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── نموذج التسجيل ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // الاسم الأول والأخير
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'الاسم الأول',
                                hint: 'مثال: أحمد',
                                controller: controller.firstNameController,
                                prefixIcon: Icons.person_rounded,
                                validator: controller.validateName,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                label: 'اسم العائلة',
                                hint: 'مثال: محمد',
                                controller: controller.lastNameController,
                                prefixIcon: Icons.person_outline_rounded,
                                validator: controller.validateName,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // البريد الإلكتروني
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

                        // كلمة المرور
                        CustomTextField(
                          label: 'كلمة المرور',
                          hint: '6 أحرف على الأقل',
                          controller: controller.passwordController,
                          prefixIcon: Icons.lock_rounded,
                          isPassword: true,
                          validator: controller.validatePassword,
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 20),

                        // تأكيد كلمة المرور
                        CustomTextField(
                          label: 'تأكيد كلمة المرور',
                          hint: 'أعد إدخال كلمة المرور',
                          controller: controller.confirmPasswordController,
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: controller.validateConfirmPassword,
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 20),

                        // الجنس
                        GenderSelector(
                          selectedGender: controller.selectedGender,
                          onChanged: (val) =>
                              controller.selectedGender.value = val,
                        ),

                        const SizedBox(height: 20),

                        // تاريخ الميلاد
                        Obx(
                          () => CustomTextField(
                            label: 'تاريخ الميلاد',
                            hint: 'اضغط لاختيار تاريخ ميلادك',
                            controller: TextEditingController(
                              text: controller.birthDateDisplay.value,
                            ),
                            prefixIcon: Icons.calendar_month_rounded,
                            readOnly: true,
                            onTap: () => controller.pickBirthDate(context),
                            suffixWidget: const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: AppColors.grey,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // الوزن والطول
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'الوزن (كغ)',
                                hint: 'مثال: 70',
                                controller: controller.weightController,
                                prefixIcon: Icons.monitor_weight_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,1}'),
                                  ),
                                ],
                                validator: controller.validateWeight,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                label: 'الطول (سم)',
                                hint: 'مثال: 170',
                                controller: controller.heightController,
                                prefixIcon: Icons.height_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,1}'),
                                  ),
                                ],
                                validator: controller.validateHeight,
                                textInputAction: TextInputAction.done,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // زر التسجيل
                        Obx(
                          () => CustomButton(
                            label: 'إنشاء الحساب',
                            onPressed: controller.isRegisterLoading.value
                                ? null
                                : () {
                                    if (formKey.currentState!.validate()) {
                                      controller.register(context);
                                    }
                                  },
                            isLoading: controller.isRegisterLoading.value,
                            icon: Icons.arrow_back_rounded,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // رابط تسجيل الدخول
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'هل تمتلك حساباً بالفعل؟  ',
                                style: AppTextStyles.bodySmall,
                              ),
                              GestureDetector(
                                onTap: () => Get.toNamed(AppRoutes.login),
                                child: Text(
                                  'سجّل الدخول',
                                  style: AppTextStyles.accentText(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
