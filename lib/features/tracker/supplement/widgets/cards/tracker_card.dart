import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/supplement/model/supplement.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';

class TrackerCard extends StatefulWidget {
  final Supplement supplement;
  final VoidCallback onLogTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onQuickLogTap; 
  final bool isCompact;

  const TrackerCard({
    super.key,
    required this.supplement,
    required this.onLogTap,
    required this.onNotificationTap,
    required this.onQuickLogTap,
    this.isCompact = true,
  });

  @override
  State<TrackerCard> createState() => _TrackerCardState();
}

class _TrackerCardState extends State<TrackerCard> {
  bool _showIngredients = false; // Tracks toggle state for visibility

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SupplementProvider>(context);

    // Dynamic stock text calculation with safety fallback checks
    String weightStockText;
    String? servingsStockText;
    if (widget.supplement.remainingStock == null) {
      weightStockText = "NO STOCK VALUE ENTERED";
    } else {
      weightStockText =
          "${widget.supplement.remainingStock!.toInt()}${widget.supplement.weightUnit}";
      servingsStockText =
          "${provider.getRemainingServings(widget.supplement)} left";
    }

    // Expiry and Days Remaining calculation variables
    String expiryText = "";
    Color expiryColor = AppColors.textSecondary;
    if (widget.supplement.expiryDate != null) {
      final date = widget.supplement.expiryDate!;
      final daysLeft = provider.getDaysUntilExpiry(date);
      expiryColor = provider.getExpiryColor(date);

      final dateString = "${date.day}/${date.month}/${date.year}";
      if (daysLeft < 0) {
        expiryText = "EXPIRED ($dateString)";
      } else if (daysLeft == 0) {
        expiryText = "EXPIRES TODAY ($dateString)";
      } else {
        expiryText = "Expires: $dateString ($daysLeft days left)";
      }
    }

    final bool isCompact = widget.isCompact;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16.r : 14.0, 
        isCompact ? 20.r : 16.0, 
        isCompact ? 12.r : 10.0, 
        isCompact ? 20.r : 16.0
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intake Log Button
          Padding(
            padding: EdgeInsets.only(top: isCompact ? 2.h : 2.0),
            child: GestureDetector(
              onTap: widget.onLogTap,
              child: Container(
                padding: EdgeInsets.all(isCompact ? 8.r : 6.0),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.crimson,
                  size: isCompact ? 20.r : 18.0,
                ),
              ),
            ),
          ),
          SizedBox(width: isCompact ? 15.w : 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supplement.name.toUpperCase(),
                  style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (widget.supplement.sharedBy != null) ...[
                  SizedBox(height: isCompact ? 4.h : 4.0),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 6.w : 6.0, 
                      vertical: isCompact ? 2.h : 2.0
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(isCompact ? 4.r : 4.0),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, color: Colors.blueAccent, size: isCompact ? 8.r : 8.0),
                        SizedBox(width: isCompact ? 4.w : 4.0),
                        Text(
                          "SHARED BY ${widget.supplement.sharedBy!.toUpperCase()}",
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Toggle row button for showing/hiding ingredients with interactive arrow indicator icon
                if (widget.supplement.ingredients.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showIngredients = !_showIngredients;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(top: isCompact ? 4.h : 4.0, bottom: isCompact ? 4.h : 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showIngredients
                                ? "Hide Ingredients"
                                : "Show Ingredients",
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Icon(
                            _showIngredients
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                            size: isCompact ? 12.r : 12.0,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Ingredients breakdown column rendered right beneath the toggle action
                  if (_showIngredients)
                    Padding(
                      padding: EdgeInsets.only(top: isCompact ? 2.h : 2.0, bottom: isCompact ? 4.h : 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.supplement.ingredients.map((
                          ingredient,
                        ) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: isCompact ? 2.h : 2.0),
                            child: Text(
                              "• ${ingredient.name}: ${ingredient.amount.toInt()}${ingredient.unit}",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],

                SizedBox(height: isCompact ? 4.h : 4.0),
                Text(
                  "1 ${widget.supplement.servingUnit} (${widget.supplement.weightPerServing.toStringAsFixed(1)}${widget.supplement.weightUnit})",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "Stock: ",
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          TextSpan(
                            text: weightStockText,
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: widget.supplement.remainingStock == null
                                  ? AppColors.textSecondary.withValues(alpha: 0.6)
                                  : provider.getStockColor(widget.supplement),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (servingsStockText != null) ...[
                      SizedBox(height: isCompact ? 2.h : 2.0),
                      Text(
                        servingsStockText,
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: provider.getStockColor(widget.supplement),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),

                // Expiry Date and Days metrics placed right beneath Stock line layout
                if (expiryText.isNotEmpty) ...[
                  SizedBox(height: isCompact ? 2.h : 2.0),
                  Text(
                    expiryText,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: expiryColor,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: isCompact ? 12.w : 10.0),
          // Pins Icon Button
          _buildQuickActionButton(
            icon: Icons.push_pin_rounded,
            isActive: widget.supplement.isPinnedToHome,
            isCompact: isCompact,
            onTap: widget.onQuickLogTap,
          ),
          SizedBox(width: isCompact ? 8.w : 6.0),
          // Notification Toggle Button
          _buildQuickActionButton(
            icon: Icons.notifications_active_outlined,
            isActive: widget.supplement.notificationsEnabled,
            isCompact: isCompact,
            onTap: widget.onNotificationTap,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isCompact ? 8.r : 6.0),
        decoration: BoxDecoration(
          color: isActive ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0),
          border: Border.all(
            color: isActive ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.crimson : AppColors.textSecondary,
          size: isCompact ? 18.r : 16.0,
        ),
      ),
    );
  }
}
