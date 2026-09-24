import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class CycleMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? date;
  final bool isCompact;

  const CycleMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.date,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 20.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon, 
            color: AppColors.crimson, 
            size: isCompact ? 20.r : 20.0,
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelLarge.adaptive(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: 2),
                Text(
                  date!,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
