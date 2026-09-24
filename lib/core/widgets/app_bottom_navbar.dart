import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class AppBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      color: Colors.transparent, 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(index: 0, icon: Icons.home_filled, label: 'Home'),
          _buildNavItem(index: 1, icon: Icons.fitness_center_outlined, label: 'Exercises'),
          _buildNavItem(index: 2, icon: Icons.edit_outlined, label: 'Tracker'),
          _buildNavItem(index: 3, icon: Icons.person_outline, label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem({required int index, required IconData icon, required String label}) {
    final isSelected = index == currentIndex;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        height: 48.h,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20.w : 12.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.crimson.withValues(alpha: 0.15),
              blurRadius: 20.r,
              spreadRadius: -2.r,
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.white : AppColors.white.withValues(alpha: 0.2),
              size: 24.r,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Row(
                      children: [
                        SizedBox(width: 8.w),
                        Text(
                          label,
                          style: AppTextStyles.buttonPrimary.copyWith(
                            color: AppColors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
