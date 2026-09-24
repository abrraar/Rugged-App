import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EliteUnitToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final int selectedIndex;
  final Function(int) onSelected;
  final Color selectedColor;

  const EliteUnitToggleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.selectedColor = AppColors.crimson,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = MediaQuery.of(context).size.width < 600;
        return Container(
          padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isCompact ? 4.h : 4.0),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 12.w : 12.0),
              _EliteToggle(
                options: options,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                selectedColor: selectedColor,
                isCompact: isCompact,
              ),
            ],
          ),
        );
      }
    );
  }
}

class _EliteToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final Function(int) onSelected;
  final Color selectedColor;
  final bool isCompact;

  const _EliteToggle({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    required this.selectedColor,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A), // Deep carbon black background
        borderRadius: BorderRadius.circular(isCompact ? 14.r : 12.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (index) {
          final bool isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16.w : 16.0, 
                vertical: isCompact ? 8.h : 8.0
              ),
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                options[index],
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
