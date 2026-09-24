import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class AuthInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffixIcon;
  final bool enabled;
  final bool isWideLayout;
  final TextInputType keyboardType;

  const AuthInputField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.enabled = true,
    this.isWideLayout = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      style: AppTextStyles.inputText.adaptive(context).copyWith(
        color: AppColors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isWideLayout ? 24 : 20.w,
          vertical: isWideLayout ? 20 : 18.h,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.crimson, size: isWideLayout ? 22 : 20.r)
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isWideLayout;
  final bool isEnabled;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isWideLayout = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveEnabled = isEnabled && !isLoading;

    return GestureDetector(
      onTap: effectiveEnabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: effectiveEnabled ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          height: isWideLayout ? 60 : 56.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: effectiveEnabled ? [
              BoxShadow(
                color: AppColors.crimson.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ] : null,
          ),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool isWideLayout;
  final bool isLoading;

  const AuthSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isWideLayout = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: isWideLayout ? 60 : 54.h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  SizedBox(width: isWideLayout ? 16 : 12.w),
                  Text(
                    label,
                    style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AuthSocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isWideLayout;

  const AuthSocialIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isWideLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isWideLayout ? 56 : 54.h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, color: color, size: isWideLayout ? 32 : 28.r),
      ),
    );
  }
}

class AuthDividerWithText extends StatelessWidget {
  final String text;
  final bool isWideLayout;
  const AuthDividerWithText({super.key, required this.text, this.isWideLayout = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.white.withValues(alpha: 0.1))),
        Flexible(
          flex: 4,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isWideLayout ? 24 : 16.w),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.white.withValues(alpha: 0.1))),
      ],
    );
  }
}

class AuthBrandingSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isWideLayout;

  const AuthBrandingSection({
    super.key,
    required this.title,
    required this.subtitle,
    this.isWideLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint("AuthBranding: Rendering Hero destination for '$title'");
    return Column(
      crossAxisAlignment: isWideLayout ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'branding_title',
          child: Material(
            type: MaterialType.transparency,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: isWideLayout ? TextAlign.center : TextAlign.start,
                style: AppTextStyles.h1.adaptive(context).copyWith(
                  fontSize: isWideLayout ? 64 : 48,
                  height: 0.9,
                  color: AppColors.white,
                  letterSpacing: -2,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          subtitle,
          textAlign: isWideLayout ? TextAlign.center : TextAlign.start,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary,
            letterSpacing: isWideLayout ? 4 : 2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
