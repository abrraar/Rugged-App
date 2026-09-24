import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../tracker/supplement/model/supplement.dart';

class QuickLogCard extends StatelessWidget {
  final Supplement item;
  final bool isRestock;
  final VoidCallback onTap;

  const QuickLogCard({
    super.key,
    required this.item,
    required this.isRestock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color themeColor = isRestock ? Colors.green : AppColors.crimson;
    final String actionLabel = isRestock ? "RESTOCK" : "RECORD";
    final IconData actionIcon = isRestock ? Icons.add_circle_rounded : Icons.remove_circle_rounded;

    final String amountDisplay = isRestock
        ? "${item.pinnedRestockAmount} ${item.pinnedUseServingsRestock ? item.servingUnit : item.weightUnit}"
        : "${item.pinnedIntakeAmount} ${item.pinnedUseServingsIntake ? item.servingUnit : item.weightUnit}";

    final provider = Provider.of<SupplementProvider>(context);
    final String remainingServings = provider.getRemainingServings(item);

    final bool canLog = isRestock || provider.canLogSupplement(item.id);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: canLog ? 1.0 : 0.5,
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
                    color: themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    actionLabel,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      fontWeight: FontWeight.w500,
                      color: themeColor,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.toUpperCase(),
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
                        Icon(actionIcon, color: themeColor, size: 16.r),
                        SizedBox(width: 4.w),
                        Text(
                          amountDisplay.toUpperCase(),
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
                      Text(
                        "STOCK",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        "${(item.remainingStock ?? 0).toInt()}${item.weightUnit} | $remainingServings",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: provider.getStockColor(item),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
