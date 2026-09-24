// lib/features/tracker/supplement/widgets/library_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/supplement/model/supplement.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';

import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class LibraryCard extends StatefulWidget {
  final Supplement item;
  final SupplementProvider provider;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isCompact;

  const LibraryCard({
    super.key,
    required this.item,
    required this.provider,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.isCompact = true,
  });

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool isExpanded = false; // Tracks if the action menu is open
  @override
  Widget build(BuildContext context) {
    String daysUntilExpiry = widget.provider
        .getDaysUntilExpiry(widget.item.expiryDate)
        .toString();

    String expiryText = widget.item.expiryDate != null
        ? "${widget.item.expiryDate!.day}/${widget.item.expiryDate!.month}/${widget.item.expiryDate!.year} | $daysUntilExpiry days left"
        : "No expiry set";

    String remainingServings =
        "${widget.provider.getRemainingServings(widget.item)}s left in stock";

    final bool isCompact = widget.isCompact;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      padding: EdgeInsets.fromLTRB(
        isCompact ? 20.w : 16.0, 
        isCompact ? 20.h : 16.0, 
        isCompact ? 12.w : 10.0, 
        isCompact ? 20.h : 16.0
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(
          color: widget.item.isActive
              ? Colors.transparent
              : AppColors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Switch(
                value: widget.item.isActive,
                activeThumbColor: AppColors.crimson,
                onChanged: (v) {
                  final calorieProvider = context.read<CalorieProvider>();
                  widget.provider.toggleSupplementStatus(
                    widget.index, 
                    v,
                    onDeactivated: (id, cals, pro, cho, fat) {
                      calorieProvider.removeSupplementFromAllMeals(id, cals, pro, cho, fat);
                    }
                  );
                },
              ),
              SizedBox(width: isCompact ? 12.w : 12.0),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: isCompact ? 4.h : 4.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: widget.item.isActive
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.item.sharedBy != null) ...[
                        SizedBox(height: isCompact ? 4.h : 4.0),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 8.w : 8.0, 
                            vertical: isCompact ? 4.h : 4.0
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(isCompact ? 6.r : 4.0),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share_rounded, color: Colors.blueAccent, size: isCompact ? 10.r : 10.0),
                              SizedBox(width: isCompact ? 4.w : 4.0),
                              Text(
                                "SHARED BY ${widget.item.sharedBy!.toUpperCase()}",
                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: isCompact ? 4.h : 4.0),
                      Text(
                        remainingServings,
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: widget.provider.getStockColor(widget.item),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      if (widget.item.ingredients.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.only(top: isCompact ? 6.h : 6.0, left: isCompact ? 4.w : 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.item.ingredients.map((ingredient) {
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
                    ],
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 12.w : 12.0),
              Consumer<AuthProvider>(
                builder: (context, authProv, _) {
                  final bool isPro = authProv.isPro;
                  return _buildQuickActionButton(
                    icon: isPro ? Icons.ios_share_rounded : Icons.lock_rounded,
                    isActive: false,
                    isCompact: isCompact,
                    onTap: () async {
                      if (!isPro) {
                        context.push(AppRoutes.proUpgrade);
                        return;
                      }
                      final userName = authProv.displayName;
                      final link = await widget.provider.generateSupplementShareLink(widget.item, userName);
                      
                      if (link != null) {
                        await Share.share(
                          "CHECK OUT THIS SUPPLEMENT SHARED BY $userName IN RUGGED:\n\n$link",
                          subject: "SUPPLEMENT SHARED BY $userName",
                        );
                      }
                    },
                  );
                },
              ),
              SizedBox(width: isCompact ? 8.w : 6.0),
              _buildQuickActionButton(
                icon: isExpanded ? Icons.close_rounded : Icons.more_vert_rounded,
                isActive: isExpanded,
                isCompact: isCompact,
                onTap: () => setState(() => isExpanded = !isExpanded),
              ),
            ],
          ),

          if (isExpanded) ...[
            Padding(
              padding: EdgeInsets.only(top: isCompact ? 12.h : 10.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context,
                      icon: Icons.edit_note_rounded,
                      label: "EDIT",
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                      isCompact: isCompact,
                      onTap: () {
                        setState(() => isExpanded = false);
                        widget.onEdit();
                      },
                    ),
                  ),
                  SizedBox(width: isCompact ? 12.w : 10.0),
                  Expanded(
                    child: _buildActionButton(
                      context,
                      icon: Icons.delete_outline_rounded,
                      label: "DELETE",
                      color: AppColors.crimson.withValues(alpha: 0.1),
                      iconColor: AppColors.crimson,
                      isCompact: isCompact,
                      onTap: () {
                        setState(() => isExpanded = false);
                        widget.onDelete();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.item.expiryDate != null) ...[
            Padding(
              padding: EdgeInsets.only(top: isCompact ? 12.h : 10.0),
              child: Divider(
                color: AppColors.white.withValues(alpha: 0.05),
                thickness: 1,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: isCompact ? 12.r : 12.0,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: isCompact ? 6.w : 6.0),
                    Text(
                      "Expires: ",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      expiryText,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: widget.provider.getExpiryColor(
                          widget.item.expiryDate,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (widget.item.caloriesPerUnit != null)
                  Text(
                    "${widget.item.caloriesPerUnit!.toStringAsFixed(0)} kcal/${widget.item.weightUnit}",
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
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

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 8.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCompact ? 18.r : 16.0, color: iconColor ?? Colors.white),
            SizedBox(width: 8.w),
            Text(
              label,
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                fontWeight: FontWeight.w500,
                color: iconColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
