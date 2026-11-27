// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// import '../../../../common/constants/app_colors.dart';
// import '../../../../common/constants/app_text_styles.dart';
// import '../../../../common/widgets/custom_button.dart';
// import '../../../../common/widgets/custom_text_field.dart';
// import '../../business/controller/auth_controller.dart';

// /// شاشة إعادة تعيين كلمة المرور
// class ResetPasswordScreen extends StatelessWidget {
//   const ResetPasswordScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return GetBuilder<AuthController>(
//       builder: (controller) {
//         final formKey = GlobalKey<FormState>();

//         return Scaffold(
//           backgroundColor: AppColors.cream,
//           appBar: AppBar(
//             title: const Text('نسيت كلمة المرور'),
//             leading: IconButton(
//               icon: const Icon(Icons.arrow_forward_ios_rounded),
//               onPressed: () => Get.back(),
//             ),
//           ),
//           body: SingleChildScrollView(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
//             child: Form(
//               key: formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   const SizedBox(height: 24),

//                   // أيقونة توضيحية
//                   Center(
//                     child: Container(
//                       width: 100,
//                       height: 100,
//                       decoration: BoxDecoration(
//                         color: AppColors.accent.withOpacity(0.1),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.lock_reset_rounded,
//                         color: AppColors.accent,
//                         size: 48,
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 32),

//                   Text(
//                     'إعادة تعيين كلمة المرور',
//                     style: AppTextStyles.headlineLarge,
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور',
//                     style: AppTextStyles.bodyMedium.copyWith(
//                       color: AppColors.grey,
//                     ),
//                     textAlign: TextAlign.center,
//                     maxLines: 4,
//                     overflow: TextOverflow.ellipsis,
//                   ),

//                   const SizedBox(height: 32),

//                   CustomTextField(
//                     label: 'البريد الإلكتروني',
//                     hint: 'example@email.com',
//                     controller: controller.resetEmailController,
//                     prefixIcon: Icons.email_rounded,
//                     keyboardType: TextInputType.emailAddress,
//                     validator: controller.validateEmail,
//                     textInputAction: TextInputAction.done,
//                   ),

//                   const SizedBox(height: 32),

//                   SizedBox(
//                     width: double.infinity,
//                     child: Obx(
//                       () => CustomButton(
//                         label: 'إرسال رابط الاسترداد',
//                         onPressed: () {
//                           if (formKey.currentState!.validate()) {
//                             controller.resetPassword(context);
//                           }
//                         },
//                         isLoading: controller.isResetLoading.value,
//                         icon: Icons.send_rounded,
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 16),

//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Text(
//                       'العودة لتسجيل الدخول',
//                       style: AppTextStyles.accentText(),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
