import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum ButtonType { primary, secondary, outline, ghost }

/// زر مخصص قابل لإعادة الاستخدام في التطبيق
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double height;
  final IconData? icon;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.width,
    this.height = 54,
    this.icon,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: height,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    switch (type) {
      case ButtonType.primary:
        return _PrimaryButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          icon: icon,
          borderRadius: borderRadius,
        );
      case ButtonType.secondary:
        return _SecondaryButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          icon: icon,
          borderRadius: borderRadius,
        );
      case ButtonType.outline:
        return _OutlineButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          isLoading: isLoading,
          icon: icon,
          borderRadius: borderRadius,
        );
      case ButtonType.ghost:
        return _GhostButton(
          label: label,
          onPressed: isLoading ? null : onPressed,
          icon: icon,
        );
    }
  }
}

// ── زر رئيسي (بني داكن مع تدرج) ──────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double borderRadius;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : AppColors.primaryGradient,
        color: onPressed == null ? AppColors.lightGrey : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: AppColors.darkBrown.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: AppTextStyles.buttonLarge),
                ],
              ),
      ),
    );
  }
}

// ── زر ثانوي (ذهبي) ───────────────────────────────────────────
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double borderRadius;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: AppTextStyles.buttonLarge),
                ],
              ),
      ),
    );
  }
}

// ── زر بإطار ──────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double borderRadius;

  const _OutlineButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.darkBrown, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: AppColors.darkBrown,
                strokeWidth: 2.5,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.darkBrown, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppTextStyles.buttonLarge.copyWith(color: AppColors.darkBrown),
                ),
              ],
            ),
    );
  }
}

// ── زر شفاف ───────────────────────────────────────────────────
class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _GhostButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.buttonMedium.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
