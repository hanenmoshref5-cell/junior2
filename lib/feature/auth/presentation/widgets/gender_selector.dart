import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';

/// ويدجت اختيار الجنس
class GenderSelector extends StatelessWidget {
  final RxString selectedGender;
  final void Function(String) onChanged;

  const GenderSelector({
    super.key,
    required this.selectedGender,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الجنس', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Obx(() => Row(
          children: [
            Expanded(
              child: _GenderOption(
                label: 'ذكر',
                icon: Icons.male_rounded,
                isSelected: selectedGender.value == 'ذكر',
                onTap: () => onChanged('ذكر'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderOption(
                label: 'أنثى',
                icon: Icons.female_rounded,
                isSelected: selectedGender.value == 'أنثى',
                onTap: () => onChanged('أنثى'),
              ),
            ),
          ],
        )),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBrown : AppColors.lightBeige,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.darkBrown : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.darkBrown.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.white : AppColors.grey,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.headlineSmall.copyWith(
                color: isSelected ? AppColors.white : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
