import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/calorie/model/saved_meal.dart';

class MealQuickLogCard extends StatelessWidget {
  final SavedMeal meal;
  final VoidCallback onTap;

  const MealQuickLogCard({
    super.key,
    required this.meal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: Container(
          constraints: BoxConstraints(minWidth: 145.w),
          margin: EdgeInsets.only(right: 16.w),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  "LOG MEAL",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name.toUpperCase(),
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: AppColors.crimson, size: 16.r),
                      SizedBox(width: 4.w),
                      Text(
                        "${meal.calories.toInt()} KCAL",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.only(top: 8.h),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniMacro(context, "${meal.protein?.toInt() ?? '-'}P", Colors.blueAccent),
                    SizedBox(width: 8.w),
                    _buildMiniMacro(context, "${meal.carbs?.toInt() ?? '-'}C", Colors.greenAccent),
                    SizedBox(width: 8.w),
                    _buildMiniMacro(context, "${meal.fats?.toInt() ?? '-'}F", Colors.orangeAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMacro(BuildContext context, String label, Color color) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
