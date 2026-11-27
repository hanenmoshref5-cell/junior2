import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../common/widgets/custom_snack_bar.dart';
import '../../../../core/routes/app_routes.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

/// كونترولر الـ Auth - مربوط بـ Supabase
class AuthController extends GetxController {
  final _authService = AuthService();

  // ── حالات التحميل ─────────────────────────────────────────────
  final RxBool isLoginLoading = false.obs;
  final RxBool isRegisterLoading = false.obs;
  final RxBool isResetLoading = false.obs;

  // ── حقول التسجيل ──────────────────────────────────────────────
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  final resetEmailController = TextEditingController();

  final RxString selectedGender = ''.obs;
  final Rx<DateTime?> birthDate = Rx<DateTime?>(null);
  final RxString birthDateDisplay = ''.obs;

  // ── المستخدم الحالي ───────────────────────────────────────────
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  // ──────────────────────────────────────────────────────────────
  // التحقق من الجلسة عند بدء التطبيق
  // ──────────────────────────────────────────────────────────────
  Future<void> checkSession() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = await _authService.getCurrentUser();

    if (user != null) {
      currentUser.value = user;
      Get.offAllNamed(AppRoutes.home);
    } else if (_authService.isLoggedIn) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      // أول مرة أو مش مسجل دخول
      Get.offAllNamed(AppRoutes.login);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Validation — نفس المنطق السابق
  // ──────────────────────────────────────────────────────────────
  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
    if (value.trim().length < 2) return 'يجب أن يكون على الأقل حرفين';
    if (!RegExp(r'^[\u0600-\u06FFa-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'يجب أن يحتوي على أحرف فقط';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
    if (!GetUtils.isEmail(value.trim())) return 'بريد إلكتروني غير صالح';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'كلمة المرور مطلوبة';
    if (value.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'تأكيد كلمة المرور مطلوب';
    if (value != passwordController.text) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  String? validateWeight(String? value) {
    if (value == null || value.isEmpty) return 'الوزن مطلوب';
    final w = double.tryParse(value);
    if (w == null) return 'أدخل رقماً صحيحاً';
    if (w < 20 || w > 300) return 'أدخل وزناً منطقياً (20-300 كغ)';
    return null;
  }

  String? validateHeight(String? value) {
    if (value == null || value.isEmpty) return 'الطول مطلوب';
    final h = double.tryParse(value);
    if (h == null) return 'أدخل رقماً صحيحاً';
    if (h < 50 || h > 250) return 'أدخل طولاً منطقياً (50-250 سم)';
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // اختيار تاريخ الميلاد
  // ──────────────────────────────────────────────────────────────
  Future<void> pickBirthDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF3F3837),
            onPrimary: Color(0xFFFFFFFF),
            surface: Color(0xFFF5F0E6),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      birthDate.value = picked;
      birthDateDisplay.value = '${picked.day}/${picked.month}/${picked.year}';
    }
  }

  // ──────────────────────────────────────────────────────────────
  // التسجيل عبر Supabase
  // ──────────────────────────────────────────────────────────────
  Future<void> register(BuildContext context) async {
    if (selectedGender.value.isEmpty) {
      CustomSnackBar.warning(context, 'الرجاء اختيار الجنس');
      return;
    }
    if (birthDate.value == null) {
      CustomSnackBar.warning(context, 'الرجاء تحديد تاريخ الميلاد');
      return;
    }

    isRegisterLoading.value = true;
    try {
      final user = await _authService.register(
        email: emailController.text.trim(),
        password: passwordController.text,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        gender: selectedGender.value,
        birthDate: birthDate.value!,
        weight: double.parse(weightController.text),
        height: double.parse(heightController.text),
      );

      currentUser.value = user;

      if (context.mounted) {
        CustomSnackBar.success(context, 'تم إنشاء الحساب بنجاح 🎉');
      }
      await Future.delayed(const Duration(milliseconds: 800));
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      if (context.mounted) {
        String msg = 'حدث خطأ، يرجى المحاولة مجدداً';
        if (e.toString().contains('already registered')) {
          msg = 'هذا البريد الإلكتروني مسجل مسبقاً';
        } else if (e.toString().contains('profiles')) {
          msg = 'خطأ في حفظ البيانات. تأكد من صحة جميع الحقول';
        } else if (e.toString().contains('password')) {
          msg = 'كلمة المرور ضعيفة جداً. استخدم 6 أحرف على الأقل';
        } else if (e.toString().contains('rate limit') ||
            e.toString().contains('429')) {
          msg = 'حاولت بسرعة كبيرة! انتظر 5-10 دقائق وحاول مجدداً بريد مختلف';
        }
        CustomSnackBar.error(context, msg);
        print('Register Error: $e'); 
      }
    } finally {
      isRegisterLoading.value = false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // تسجيل الدخول عبر Supabase
  // ──────────────────────────────────────────────────────────────
  Future<void> login(BuildContext context) async {
    isLoginLoading.value = true;
    try {
      final user = await _authService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      currentUser.value = user;

      if (context.mounted) {
        CustomSnackBar.success(context, 'مرحباً بعودتك! 👋');
      }
      await Future.delayed(const Duration(milliseconds: 600));
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.error(
          context,
          'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        );
      }
    } finally {
      isLoginLoading.value = false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // إعادة تعيين كلمة المرور عبر Supabase
  // ──────────────────────────────────────────────────────────────
  // Future<void> resetPassword(BuildContext context) async {
  //   isResetLoading.value = true;
  //   try {
  //     await _authService.resetPassword(resetEmailController.text.trim());

  //     if (context.mounted) {
  //       CustomSnackBar.success(
  //         context,
  //         'تم إرسال رابط إعادة التعيين إلى بريدك',
  //       );
  //     }
  //     await Future.delayed(const Duration(milliseconds: 800));
  //     Get.back();
  //   } catch (e) {
  //     if (context.mounted) {
  //       CustomSnackBar.error(context, 'البريد الإلكتروني غير مسجل');
  //     }
  //   } finally {
  //     isResetLoading.value = false;
  //   }
  // }

  // ──────────────────────────────────────────────────────────────
  // تسجيل الخروج
  // ──────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    weightController.dispose();
    heightController.dispose();
    resetEmailController.dispose();
    super.onClose();
  }
}
