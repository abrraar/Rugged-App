// lib/core/widgets/app_search_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final bool showAdd;
  final bool showFilter;
  final int? maxLength;
  final VoidCallback? onAddTap;
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onChanged;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.showAdd = true,
    this.showFilter = true,
    this.maxLength,
    this.onAddTap,
    this.onFilterTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.sizeOf(context).width < kMobileBreakpoint;

    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4.h : 4.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: isCompact ? 44.h : 48.0,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.05),
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                maxLength: maxLength,
                inputFormatters: [
                  if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
                ],
                style: AppTextStyles.inputText.adaptive(context).copyWith(
                  color: AppColors.white,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: hintText,
                  hintStyle: AppTextStyles.inputHint.adaptive(context).copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 18.r : 20.0,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 12.0),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: isCompact ? 8.w : 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedButton(showFilter, Icons.tune_rounded, onFilterTap, isCompact),
                _buildAnimatedButton(showAdd, Icons.add_rounded, onAddTap, isCompact),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton(bool show, IconData icon, VoidCallback? onTap, bool isCompact) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
      },
      child: show
          ? _buildCompactIconButton(icon, onTap, isCompact, key: ValueKey(icon))
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  Widget _buildCompactIconButton(IconData icon, VoidCallback? onTap, bool isCompact, {Key? key}) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: isCompact ? 6.w : 8.0),
        padding: EdgeInsets.all(isCompact ? 8.r : 10.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          color: AppColors.white.withValues(alpha: 0.9),
          size: isCompact ? 20.r : 22.0,
        ),
      ),
    );
  }
}
