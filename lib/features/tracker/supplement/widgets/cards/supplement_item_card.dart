import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_item.dart';
import 'package:intl/intl.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class SupplementItemCard extends StatelessWidget {
  final SupplementItem entry;
  final bool isCompact;

  const SupplementItemCard({
    super.key, 
    required this.entry,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;

    if (entry.type == "Restock") {
      iconColor = Colors.green;
      iconData = Icons.inventory_2_outlined;
    } else if (entry.type == "Both") {
      iconColor = Colors.blueAccent;
      iconData = Icons.published_with_changes_rounded;
    } else {
      iconColor = AppColors.crimson;
      iconData = Icons.timer_outlined;
    }

    String? badgeText;
    Color? badgeColor;

    final String details = entry.details.toUpperCase();
    
    if (details.startsWith("MEAL LOG:")) {
      badgeText = "MEAL";
      badgeColor = Colors.orangeAccent;
    } else if (details.contains("NOTIFICATION")) {
      badgeText = "NOTIF";
      badgeColor = Colors.tealAccent;
    } else if (details.contains("QUICK LOG") || details.contains("QUICK RESTOCK")) {
      badgeText = "QUICK";
      badgeColor = Colors.blueAccent;
    } else if (details.contains("STACK LOG")) {
      badgeText = "STACK";
      badgeColor = AppColors.crimson;
    } else if (details.startsWith("INTAKE:") || details.startsWith("RESTOCK:")) {
      badgeText = "MANUAL";
      badgeColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.02)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 10.r : 8.0),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: isCompact ? 18.r : 16.0),
          ),
          SizedBox(width: isCompact ? 15.w : 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.supplementName.toUpperCase(),
                              style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            SizedBox(width: isCompact ? 8.w : 6.0),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 6.w : 6.0, 
                                vertical: isCompact ? 2.h : 2.0
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor!.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(isCompact ? 4.r : 4.0),
                                border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                badgeText,
                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm | MMM d').format(entry.timestamp),
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 4.h : 4.0),
                Text(
                  entry.details,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
