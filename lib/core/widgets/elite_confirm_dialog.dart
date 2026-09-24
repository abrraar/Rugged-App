import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EliteConfirmDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = "DELETE",
    String cancelText = "CANCEL",
    Color confirmColor = AppColors.crimson,
    IconData icon = Icons.warning_amber_rounded,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600; // Use a reasonable breakpoint for dialog content
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
            ),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
                  decoration: BoxDecoration(
                    color: confirmColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: confirmColor,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  title.toUpperCase(),
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 12.w : 12.0, 
                  0, 
                  isCompact ? 12.w : 12.0, 
                  isCompact ? 16.h : 16.0
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                            border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cancelText.toUpperCase(),
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(
                            color: confirmColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                            border: Border.all(color: confirmColor.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            confirmText.toUpperCase(),
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                              color: confirmColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
