import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class CycleStatusCard extends StatelessWidget {
  final String activeCycle;
  final int completedWorkouts;
  final int totalWorkouts;
  final double workOutputGrowth;
  final bool isCompact;

  const CycleStatusCard({
    super.key,
    required this.activeCycle,
    required this.completedWorkouts,
    required this.totalWorkouts,
    this.workOutputGrowth = 0.0,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate progress fraction
    final double progress = totalWorkouts > 0 ? (completedWorkouts / totalWorkouts).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
                  SizedBox(width: 8.w),
                  Text(
                    'CYCLE STATUS',
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (workOutputGrowth != 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: workOutputGrowth > 0 ? Colors.green.withValues(alpha: 0.2) : AppColors.crimson.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    "${workOutputGrowth > 0 ? "+" : ""}${(workOutputGrowth * 100).toStringAsFixed(1)}% STRENGTH PROGRESS",
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: workOutputGrowth > 0 ? Colors.greenAccent : AppColors.crimson,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Data Rows
          _buildStatusRow(context, 'Active Routine', activeCycle.toUpperCase(), isCompact),
          SizedBox(height: 10.h),
          _buildStatusRow(
            context,
            'Overall Progress',
            '$completedWorkouts OF $totalWorkouts COMPLETED',
            isCompact,
          ),

          SizedBox(height: 16.h),

          // Progress Bar: Showing how far the user has progressed in the cycle
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.background.withValues(alpha: 0.5),
              color: AppColors.crimson,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, String value, bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.labelMedium.adaptive(context).copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
