import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/widgets/custom_snack_bar.dart';
import '../../data/models/measurement_model.dart';
import '../../../home/business/controller/home_controller.dart';

class ManualInputScreen extends StatefulWidget {
  const ManualInputScreen({super.key});
  @override
  State<ManualInputScreen> createState() => _ManualInputScreenState();
}

class _ManualInputScreenState extends State<ManualInputScreen> {
  final _controller = TextEditingController();
  final _service = MeasurementService();
  bool _isFasting = false;
  bool _isLoading = false;
  MeasurementModel? _result;

  Future<void> _analyze() async {
    final value = double.tryParse(_controller.text);
    if (value == null) {
      CustomSnackBar.error(context, 'الرجاء إدخال قيمة صحيحة');
      return;
    }
    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      // حفظ بالـ Supabase
      final saved = await _service.saveMeasurement(
        value: value,
        method: 'manual',
        isFasting: _isFasting,
      );
      setState(() => _result = saved);

      if (mounted) {
        CustomSnackBar.success(context, 'تم حفظ القياس بنجاح ✅');
        // تحديث HomeController
        try {
          final homeController = Get.find<HomeController>();
          await homeController.refreshLatestMeasurement();
        } catch (e) {
          debugPrint('⚠️ تحديث HomeController: $e');
        }
      }
    } catch (e) {
      if (mounted)
        CustomSnackBar.error(
          context,
          'فشل الحفظ: لايوجد اتصال بالإنترنت تأكد من اتصالك وحاول مرة أخرى',
        );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'normal':
        return AppColors.sugarNormal;
      case 'high':
        return AppColors.sugarHigh;
      case 'very_high':
        return AppColors.sugarVeryHigh;
      case 'low':
        return AppColors.sugarLow;
      default:
        return AppColors.sugarVeryLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('إدخال قياس يدوي'),
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
            const SizedBox(height: 8),
            // بطاقة الإدخال
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkBrown.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('قيمة السكر (mg/dL)', style: AppTextStyles.label),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,1}'),
                      ),
                    ],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.measurementValue,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: AppTextStyles.measurementValue.copyWith(
                        color: AppColors.lightGrey,
                      ),
                      filled: true,
                      fillColor: AppColors.lightBeige,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.accent,
                          width: 2,
                        ),
                      ),
                      suffix: Text(
                        'mg/dL',
                        style: AppTextStyles.measurementUnit,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // تشيك بوكس الصيام
                  GestureDetector(
                    onTap: () => setState(() => _isFasting = !_isFasting),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isFasting
                            ? AppColors.darkBrown.withOpacity(0.08)
                            : AppColors.lightBeige,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isFasting
                              ? AppColors.darkBrown
                              : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isFasting
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: _isFasting
                                ? AppColors.darkBrown
                                : AppColors.grey,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'أنا صائم حالياً',
                                style: AppTextStyles.headlineSmall,
                              ),
                              Text(
                                'سيتم التحليل بناءً على حالة الصيام',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.no_food_rounded,
                            color: AppColors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            CustomButton(
              label: 'تحليل وحفظ القياس',
              onPressed: _analyze,
              isLoading: _isLoading,
              icon: Icons.analytics_rounded,
            ),

            // نتيجة التحليل
            if (_result != null) ...[
              const SizedBox(height: 24),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _statusColor(_result!.status).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _statusColor(_result!.status).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getAdvice(_result!.status),
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(_result!.status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _result!.statusLabel,
                            style: AppTextStyles.whiteText(
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Get.toNamed('/programs'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkBrown.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.medical_services_rounded,
                              color: AppColors.darkBrown,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'عرض البرامج المناسبة لحالتك',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.darkBrown,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getAdvice(String status) {
    switch (status) {
      case 'normal':
        return 'سكرك طبيعي ممتاز، استمر في نمط حياتك الصحي';
      case 'high':
        return 'سكرك مرتفع، تجنب السكريات والنشويات الآن';
      case 'very_high':
        return 'سكرك مرتفع جداً، يُنصح بمراجعة الطبيب فوراً';
      case 'low':
        return 'سكرك منخفض، تناول شيئاً حلواً فوراً';
      default:
        return 'سكرك منخفض جداً، تناول سكراً أو عصيراً فوراً';
    }
  }
}
