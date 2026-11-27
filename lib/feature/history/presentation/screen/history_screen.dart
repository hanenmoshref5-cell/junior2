import 'package:flutter/material.dart';
import 'dart:io';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';
import '../../../measure/data/models/measurement_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = MeasurementService();
  String _selected = 'اليوم';
  final List<String> _filters = [
    'اليوم',
    '3 أيام',
    'أسبوع',
    'شهر',
    'شهران',
    'سنة',
  ];
  List<MeasurementModel> _measurements = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime from;
      switch (_selected) {
        case 'اليوم':
          from = DateTime(now.year, now.month, now.day);
          break;
        case '3 أيام':
          from = now.subtract(const Duration(days: 3));
          break;
        case 'أسبوع':
          from = now.subtract(const Duration(days: 7));
          break;
        case 'شهر':
          from = now.subtract(const Duration(days: 30));
          break;
        case 'شهران':
          from = now.subtract(const Duration(days: 60));
          break;
        default:
          from = now.subtract(const Duration(days: 365));
      }
      _measurements = await _service.getMeasurements(from: from, to: now);
    } catch (e) {
      print('❌ خطأ في تحميل القياسات: $e');
      if (mounted) {
        if (e is SocketException ||
            e.toString().contains('Failed host lookup')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لا يتوفر اتصال إنترنت. لا يمكننا عرض قياساتك السابقة دون إنترنت.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('حدث خطأ أثناء تحميل القياسات.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _statusColor(String s) {
    switch (s) {
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
        title: const Text('سجل القياسات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // فلتر الفترة
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final isSel = _selected == _filters[i];
                  return GestureDetector(
                    onTap: () {
                      if (mounted) {
                        setState(() => _selected = _filters[i]);
                        _fetch();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.darkBrown
                            : AppColors.lightBeige,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel
                              ? AppColors.darkBrown
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        _filters[i],
                        style: AppTextStyles.label.copyWith(
                          color: isSel ? AppColors.white : AppColors.grey,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_measurements.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: AppColors.lightGrey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد قياسات في هذه الفترة',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _measurements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = _measurements[_measurements.length - 1 - i];
                    final color = _statusColor(m.status);
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          // التاريخ
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.measuredAt.hour.toString().padLeft(2, '0')}:${m.measuredAt.minute.toString().padLeft(2, '0')}',
                                style: AppTextStyles.caption,
                              ),
                              Text(
                                '${m.measuredAt.day}/${m.measuredAt.month}/${m.measuredAt.year}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                          const Spacer(),
                          // الطريقة
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightBeige,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              m.method == 'manual' ? 'يدوي' : 'كاميرا',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // الحالة
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              m.statusLabel,
                              style: AppTextStyles.whiteText(
                                fontSize: 11,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // القيمة
                          Text(
                            '${m.value.toInt()}',
                            style: AppTextStyles.headlineMedium,
                          ),
                          Text(' mg/dL', style: AppTextStyles.caption),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
