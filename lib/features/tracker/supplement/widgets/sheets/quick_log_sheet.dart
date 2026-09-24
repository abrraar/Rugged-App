// lib/features/tracker/supplement/widgets/quick_log_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import '../../model/supplement.dart';

class QuickLogSheet extends StatefulWidget {
  final Supplement supplement;
  final bool isSideSheet;
  final Function({
    required bool isPinned,
    required double intakeVal,
    required bool useServingsIntake,
    required double restockVal,
    required bool useServingsRestock,
  })
  onSave;

  const QuickLogSheet({
    super.key,
    required this.supplement,
    required this.onSave,
    this.isSideSheet = false,
  });

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  late bool recordEnabled;
  late bool restockEnabled;
  late bool useServingsIntake;
  late bool useServingsRestock;

  final TextEditingController intakeController = TextEditingController();
  final TextEditingController restockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    useServingsIntake = widget.supplement.pinnedUseServingsIntake;
    useServingsRestock = widget.supplement.pinnedUseServingsRestock;

    recordEnabled = widget.supplement.pinnedIntakeAmount > 0;
    restockEnabled = widget.supplement.pinnedRestockAmount > 0;

    intakeController.text = widget.supplement.pinnedIntakeAmount > 0
        ? widget.supplement.pinnedIntakeAmount.toString()
        : "";
    restockController.text = widget.supplement.pinnedRestockAmount > 0
        ? widget.supplement.pinnedRestockAmount.toString()
        : "";
  }

  /// Sanitizes inputs right as the user exits the sheet view.
  /// If toggled ON but value is missing or 0, it auto-toggles OFF.
  void _handleSaveAndExit() {
    double iVal = double.tryParse(intakeController.text) ?? 0.0;
    double rVal = double.tryParse(restockController.text) ?? 0.0;

    // Cleanup phase: Turn off switches if fields were left blank or 0
    if (recordEnabled && iVal <= 0.0) {
      recordEnabled = false;
      iVal = 0.0;
    }
    if (restockEnabled && rVal <= 0.0) {
      restockEnabled = false;
      rVal = 0.0;
    }

    widget.onSave(
      isPinned: (recordEnabled && iVal > 0) || (restockEnabled && rVal > 0),
      intakeVal: recordEnabled ? iVal : 0.0,
      useServingsIntake: useServingsIntake,
      restockVal: restockEnabled ? rVal : 0.0,
      useServingsRestock: useServingsRestock,
    );
  }

  @override
  void dispose() {
    intakeController.dispose();
    restockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _handleSaveAndExit();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
          final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 500.0);

          return Align(
            alignment: widget.isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: Container(
                height: widget.isSideSheet ? double.infinity : null,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: widget.isSideSheet 
                    ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                    : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
                  border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                ),
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 24.w : 24.0, 
                  widget.isSideSheet ? 0 : (isCompact ? 16.h : 12.0), 
                  isCompact ? 24.w : 24.0, 
                  isCompact ? 40.h : 32.0
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (widget.isSideSheet) SizedBox(height: 24.0),
                      if (!widget.isSideSheet)
                        // Handle Bar
                        Container(
                          width: isCompact ? 40.w : 40.0,
                          height: isCompact ? 4.h : 4.0,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      if (!widget.isSideSheet) SizedBox(height: isCompact ? 20.h : 16.0),

                      // Header Block
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isCompact ? 10.r : 10.0),
                            decoration: BoxDecoration(
                              color: AppColors.crimson.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.push_pin_rounded,
                              color: AppColors.crimson,
                              size: isCompact ? 22.r : 20.0,
                            ),
                          ),
                          SizedBox(width: isCompact ? 12.w : 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "QUICK LOG SETTINGS", 
                                  style: AppTextStyles.h3.copyWith(fontSize: isCompact ? null : 18.0)
                                ),
                                Text(
                                  widget.supplement.name.toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.2,
                                    fontSize: isCompact ? null : 10.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isSideSheet)
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                        ],
                      ),

                      SizedBox(height: isCompact ? 16.h : 12.0),

                      // Info Help Notice card block
                      Container(
                        padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(isCompact ? 12.r : 12.0),
                          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.crimson,
                              size: isCompact ? 18.r : 16.0,
                            ),
                            SizedBox(width: isCompact ? 10.w : 10.0),
                            Expanded(
                              child: Text(
                                "Activating a toggle and setting values greater than 0 pins this shortcut card onto your dashboard space. Empty fields will auto-disable upon exit.",
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white70,
                                  fontSize: isCompact ? 11.sp : 11.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isCompact ? 24.h : 20.0),

                      // Daily Intake Segment
                      _buildActionSection(
                        title: "DAILY INTAKE",
                        isActive: recordEnabled,
                        controller: intakeController,
                        useServings: useServingsIntake,
                        isCompact: isCompact,
                        onToggleChanged: (val) {
                          setState(() {
                            recordEnabled = val;
                            if (val) {
                              final double currentVal =
                                  double.tryParse(intakeController.text) ?? 0;
                              if (currentVal <= 0) {
                                intakeController.text = "1.0";
                              }
                            } else {
                              intakeController.clear();
                            }
                          });
                        },
                        onUnitToggle: (v) => setState(() => useServingsIntake = v),
                      ),

                      SizedBox(height: isCompact ? 16.h : 12.0),

                      // Common Restock Segment
                      _buildActionSection(
                        title: "COMMON RESTOCK",
                        isActive: restockEnabled,
                        controller: restockController,
                        useServings: useServingsRestock,
                        isCompact: isCompact,
                        onToggleChanged: (val) {
                          setState(() {
                            restockEnabled = val;
                            if (val) {
                              final double currentVal =
                                  double.tryParse(restockController.text) ?? 0;
                              if (currentVal <= 0) {
                                restockController.text = "1.0";
                              }
                            } else {
                              restockController.clear();
                            }
                          });
                        },
                        onUnitToggle: (v) => setState(() => useServingsRestock = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionSection({
    required String title,
    required bool isActive,
    required TextEditingController controller,
    required bool useServings,
    required Function(bool) onToggleChanged,
    required Function(bool) onUnitToggle,
    required bool isCompact,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(
          color: isActive
              ? AppColors.crimson.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontSize: isCompact ? null : 11.0,
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: isActive,
                  activeTrackColor: AppColors.crimson,
                  onChanged: onToggleChanged,
                ),
              ),
            ],
          ),
          if (isActive) ...[
            SizedBox(height: isCompact ? 16.h : 12.0),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: isCompact ? 48.h : 44.0,
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'(^\d*\.?\d*)'),
                        ),
                      ],
                      style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 16.sp : 14.0),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: "1.0",
                        hintStyle: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          fontSize: isCompact ? null : 11.0,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 12.w : 12.0),
                _buildSegmentedSelector(
                  [widget.supplement.servingUnit, widget.supplement.weightUnit],
                  useServings ? 0 : 1,
                  (i) => onUnitToggle(i == 0),
                  isCompact: isCompact,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedSelector(
    List<String> labels,
    int activeIndex,
    Function(int) onTap,
    {required bool isCompact}
  ) {
    return Container(
      height: isCompact ? 48.h : 44.0,
      padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          labels.length,
          (i) => GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 12.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeIndex == i
                    ? AppColors.crimson
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0),
              ),
              child: Text(
                labels[i].toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: isCompact ? 10.sp : 9.0,
                  fontWeight: FontWeight.w500,
                  color: activeIndex == i
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
