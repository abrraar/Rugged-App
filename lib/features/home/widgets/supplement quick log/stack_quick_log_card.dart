import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_stack.dart';

class StackQuickLogCard extends StatelessWidget {
  final SupplementStack stack;
  final VoidCallback onTap;

  const StackQuickLogCard({
    super.key,
    required this.stack,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 170;
        final double padding = isCompact ? 12 : 16;

        return GestureDetector(
          onTap: onTap,
          child: IntrinsicWidth(
            child: Container(
              constraints: BoxConstraints(minWidth: isCompact ? 150.r : 200.r),
              margin: const EdgeInsets.only(right: 12),
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "STACK",
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: AppColors.crimson,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (stack.sharedBy != null)
                        Icon(Icons.share_rounded, color: Colors.blueAccent, size: isCompact ? 12 : 14),
                    ],
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                  Text(
                    stack.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${stack.items.length} ITEMS",
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: isCompact ? 10 : 12,
                          color: AppColors.crimson,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
