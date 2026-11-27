import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// حقل نص مخصص قابل لإعادة الاستخدام
class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixWidget,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // التسمية
        Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        // حقل الإدخال
        Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.isPassword && _obscureText,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            inputFormatters: widget.inputFormatters,
            focusNode: widget.focusNode,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTextStyles.hint,
              hintTextDirection: TextDirection.rtl,
              // خلفية الحقل
              filled: true,
              fillColor: _isFocused
                  ? AppColors.white
                  : AppColors.lightBeige,
              // الحدود
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.divider,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.sugarVeryHigh,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.sugarVeryHigh,
                  width: 2,
                ),
              ),
              // أيقونات
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused ? AppColors.accent : AppColors.grey,
                      size: 20,
                    )
                  : null,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.grey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                  : widget.suffixWidget,
              // مسافات داخلية
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              // نص الخطأ
              errorStyle: AppTextStyles.caption.copyWith(
                color: AppColors.sugarVeryHigh,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
