import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/widgets/custom_text_field.dart';
import '../../../../common/widgets/custom_snack_bar.dart';
import '../../../auth/business/controller/auth_controller.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _authController = Get.find<AuthController>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;

  bool _isSaveLoading = false;
  bool _isImageLoading = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final user = _authController.currentUser.value;
    _firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: user?.lastName ?? '');
    _weightCtrl = TextEditingController(text: user?.weight.toString() ?? '');
    _heightCtrl = TextEditingController(text: user?.height.toString() ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  // ── اختيار صورة من الجهاز ────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _isImageLoading = true;
    });

    try {
      final url = await _profileService.uploadProfileImage(_selectedImage!);

      // تحديث المستخدم الحالي بالـ URL الجديد
      final updated = _authController.currentUser.value?.copyWith(
        profileImageUrl: url,
      );
      if (updated != null) _authController.currentUser.value = updated;

      if (mounted) CustomSnackBar.success(context, 'تم تحديث الصورة بنجاح ✅');
    } catch (e) {
      if (mounted) CustomSnackBar.error(context, 'فشل رفع الصورة: $e');
      setState(() => _selectedImage = null);
    } finally {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  // ── حفظ التغييرات بـ Supabase ────────────────────────────────
  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final weight = double.tryParse(_weightCtrl.text);
    final height = double.tryParse(_heightCtrl.text);

    if (firstName.isEmpty || lastName.isEmpty) {
      CustomSnackBar.warning(context, 'الاسم الأول واسم العائلة مطلوبان');
      return;
    }

    setState(() => _isSaveLoading = true);

    try {
      // حفظ بـ Supabase
      final updated = await _profileService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        weight: weight,
        height: height,
      );

      // تحديث المستخدم بالـ GetX عشان يتحدث بكل الشاشات فوراً
      _authController.currentUser.value = updated;

      if (mounted) CustomSnackBar.success(context, 'تم حفظ التغييرات بنجاح ✅');
    } catch (e) {
      if (mounted) CustomSnackBar.error(context, 'فشل الحفظ: $e');
    } finally {
      if (mounted) setState(() => _isSaveLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── صورة البروفايل ────────────────────────────────
            Center(
              child: Stack(
                children: [
                  // الصورة
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 3),
                    ),
                    child: ClipOval(
                      child: _isImageLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                              ),
                            )
                          : _buildAvatar(),
                    ),
                  ),

                  // زر الكاميرا
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: GestureDetector(
                      onTap: _isImageLoading ? null : _pickImage,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          gradient: AppColors.accentGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Obx(
              () => Center(
                child: Text(
                  _authController.currentUser.value?.email ?? '',
                  style: AppTextStyles.caption,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── حقول البيانات ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'الاسم الأول',
                    controller: _firstNameCtrl,
                    prefixIcon: Icons.person_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'اسم العائلة',
                    controller: _lastNameCtrl,
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'الوزن (كغ)',
                    controller: _weightCtrl,
                    prefixIcon: Icons.monitor_weight_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,1}'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'الطول (سم)',
                    controller: _heightCtrl,
                    prefixIcon: Icons.height_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,1}'),
                      ),
                    ],
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── زر الحفظ ──────────────────────────────────────
            CustomButton(
              label: 'حفظ التغييرات',
              onPressed: _save,
              isLoading: _isSaveLoading,
              icon: Icons.save_rounded,
            ),

            const SizedBox(height: 12),

            // ── زر تسجيل الخروج ───────────────────────────────
            CustomButton(
              label: 'تسجيل الخروج',
              onPressed: () => _authController.logout(),
              type: ButtonType.outline,
              icon: Icons.logout_rounded,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── بناء الصورة حسب المصدر ───────────────────────────────────
  Widget _buildAvatar() {
    // صورة محلية مختارة حديثاً
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover);
    }

    // صورة من Supabase Storage
    final imageUrl = _authController.currentUser.value?.profileImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(),
      );
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppColors.mediumBrown,
      child: const Icon(Icons.person_rounded, color: AppColors.white, size: 50),
    );
  }
}
