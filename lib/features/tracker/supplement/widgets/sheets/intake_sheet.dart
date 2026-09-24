// lib/features/tracker/supplement/widgets/intake_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import '../../model/supplement.dart';

class IntakeSheet extends StatefulWidget {
  final Supplement supplement;
  final bool isSideSheet;
  final Function({
    required bool recordIntake,
    required bool restockInventory,
    required double intakeVal,
    required double restockVal,
    required bool useServingsForIntake,
    required bool useServingsForRestock,
    required DateTime selectedTimestamp,
  })
  onConfirm;

  const IntakeSheet({
    super.key,
    required this.supplement,
    required this.onConfirm,
    this.isSideSheet = false,
  });

  @override
  State<IntakeSheet> createState() => _IntakeSheetState();
}

class _IntakeSheetState extends State<IntakeSheet> {
  bool recordIntake = true;
  bool restockInventory = false;
  bool useServingsForIntake = true;
  bool useServingsForRestock = true;
  DateTime selectedTimestamp = DateTime.now();

  final TextEditingController intakeController = TextEditingController(
    text: "1.0",
  );
  final TextEditingController restockController = TextEditingController(
    text: "1.0",
  );

  @override
  void initState() {
    super.initState();
    // Default recordIntake to false if there is no inventory available
    recordIntake = (widget.supplement.remainingStock ?? 0) > 0;
  }

  @override
  void dispose() {
    intakeController.dispose();
    restockController.dispose();
    super.dispose();
  }

  void _validateAndUpdateValue(TextEditingController controller, String text) {
    double? parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      controller.text = "0.5";
    }
  }

  @override
  Widget build(BuildContext context) {
    double iVal = double.tryParse(intakeController.text) ?? 0.0;
    double rVal = double.tryParse(restockController.text) ?? 0.0;

    double neededIntakeWeight = useServingsForIntake
        ? (iVal * widget.supplement.weightPerServing)
        : iVal;
    
    final bool hasStock = (widget.supplement.remainingStock ?? 0) >= (neededIntakeWeight - 0.0001);
    final bool intakeValid = recordIntake && iVal > 0 && hasStock;
    final bool restockValid = restockInventory && rVal > 0;

    final bool isActionEnabled = intakeValid || restockValid;

    String buttonLabel = "ENABLE AN ACTION ABOVE";
    if (isActionEnabled) {
      buttonLabel = "CONFIRM LOG";
    } else if (recordIntake && !hasStock) {
      buttonLabel = "INSUFFICIENT STOCK";
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
        final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 500.0);

        return Align(
          alignment: widget.isSideSheet ? Alignment.center : Alignment.bottomCenter,
          child: SizedBox(
            width: sheetWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: widget.isSideSheet ? double.infinity : null,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: widget.isSideSheet 
                    ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                    : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
                  border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (!widget.isSideSheet) _buildHandle(isCompact),
                    if (widget.isSideSheet) SizedBox(height: 24.0),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 24.w : 24.0, 
                          0, 
                          isCompact ? 24.w : 24.0, 
                          isCompact ? 40.h : 32.0
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            children: [
                              _buildHeader(isCompact),
                              SizedBox(height: isCompact ? 24.h : 20.0),
                              _buildDatePicker(isCompact),
                              SizedBox(height: isCompact ? 16.h : 12.0),

                              // Intake Section
                              _buildActionContainer(
                                isActive: recordIntake,
                                isCompact: isCompact,
                                child: Column(
                                  children: [
                                    _buildToggleRow(
                                      "RECORD INTAKE",
                                      recordIntake,
                                      (v) => setState(() => recordIntake = v),
                                      isCompact: isCompact,
                                      isEnabled: (widget.supplement.remainingStock ?? 0) > 0,
                                    ),
                                    if (recordIntake) ...[
                                      SizedBox(height: isCompact ? 16.h : 12.0),
                                      _buildInputStepperRow(
                                        intakeController,
                                        useServingsForIntake,
                                        (v) => setState(() => useServingsForIntake = v),
                                        isCompact: isCompact,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: isCompact ? 16.h : 12.0),

                              // Restock Section
                              _buildActionContainer(
                                isActive: restockInventory,
                                isCompact: isCompact,
                                child: Column(
                                  children: [
                                    _buildToggleRow(
                                      "RESTOCK INVENTORY",
                                      restockInventory,
                                      (v) => setState(() => restockInventory = v),
                                      isCompact: isCompact,
                                    ),
                                    if (restockInventory) ...[
                                      SizedBox(height: isCompact ? 16.h : 12.0),
                                      _buildInputStepperRow(
                                        restockController,
                                        useServingsForRestock,
                                        (v) =>
                                            setState(() => useServingsForRestock = v),
                                        isCompact: isCompact,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: isCompact ? 32.h : 24.0),

                              _buildActionButton(
                                label: buttonLabel,
                                isEnabled: isActionEnabled,
                                isCompact: isCompact,
                                onPressed: () {
                                  if (isActionEnabled) {
                                    widget.onConfirm(
                                      recordIntake: intakeValid,
                                      restockInventory: restockValid,
                                      intakeVal:
                                          double.tryParse(intakeController.text) ?? 0.5,
                                      restockVal:
                                          double.tryParse(restockController.text) ??
                                          0.5,
                                      useServingsForIntake: useServingsForIntake,
                                      useServingsForRestock: useServingsForRestock,
                                      selectedTimestamp: selectedTimestamp,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputStepperRow(
    TextEditingController controller,
    bool useServings,
    Function(bool) onUnitToggle,
    {required bool isCompact}
  ) {
    double currentValue = double.tryParse(controller.text) ?? 1.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8.w : 8.0, 
              vertical: isCompact ? 4.h : 4.0
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                _stepBtn(Icons.remove, () {
                  double newVal = (currentValue > 0.5)
                      ? currentValue - 0.5
                      : 0.5;
                  setState(() => controller.text = newVal.toStringAsFixed(1));
                }, isCompact),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 18.sp : 18.0),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'(^\d*\.?\d*)'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (text) => setState(
                      () => _validateAndUpdateValue(controller, text),
                    ),
                    onChanged: (text) => setState(() {}),
                  ),
                ),
                _stepBtn(Icons.add, () {
                  double newVal = currentValue + 0.5;
                  setState(() => controller.text = newVal.toStringAsFixed(1));
                }, isCompact),
              ],
            ),
          ),
        ),
        SizedBox(width: isCompact ? 12.w : 10.0),
        _buildSegmentedSelector(
          [widget.supplement.servingUnit, widget.supplement.weightUnit],
          useServings ? 0 : 1,
          (i) => onUnitToggle(i == 0),
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap, bool isCompact) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(isCompact ? 8.r : 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0),
      ),
      child: Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
    ),
  );

  Widget _buildToggleRow(String title, bool value, Function(bool) onChanged, {required bool isCompact, bool isEnabled = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w500,
            color: isEnabled ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4),
            fontSize: isCompact ? null : 11.0,
          ),
        ),
        Switch.adaptive(
          value: isEnabled ? value : false,
          activeTrackColor: AppColors.crimson,
          onChanged: isEnabled ? onChanged : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(bool isCompact) {
    return _buildActionContainer(
      isActive: true,
      isCompact: isCompact,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "DATE & TIME",
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? null : 11.0,
            ),
          ),
          GestureDetector(
            onTap: _pickDateTime,
            child: Text(
              DateFormat('MMM d, h:mm a').format(selectedTimestamp),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.crimson,
                fontWeight: FontWeight.w500,
                fontSize: isCompact ? null : 11.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CLEANED: Inline configurations removed; everything runs through AppPickerTheme definitions smoothly
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: selectedTimestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child!,
        ),
      ),
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        useRootNavigator: true,
        initialTime: TimeOfDay.fromDateTime(selectedTimestamp),
        builder: (context, child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child!,
          ),
        ),
      );

      if (time != null) {
        setState(
          () => selectedTimestamp = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        );
      }
    }
  }

  Widget _buildHeader(bool isCompact) => Row(
    children: [
      Container(
        padding: EdgeInsets.all(isCompact ? 10.r : 10.0),
        decoration: BoxDecoration(
          color: AppColors.crimson.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add_task_rounded,
          color: AppColors.crimson,
          size: isCompact ? 24.r : 24.0,
        ),
      ),
      SizedBox(width: isCompact ? 12.w : 12.0),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "LOG ACTIVITY", 
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
  );

  Widget _buildHandle(bool isCompact) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 12.0),
    alignment: Alignment.center,
    child: Container(
      width: isCompact ? 40.w : 40.0,
      height: isCompact ? 4.h : 4.0,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3.r),
      ),
    ),
  );

  Widget _buildActionContainer({
    required bool isActive,
    required Widget child,
    required bool isCompact,
  }) => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: isActive ? 1.0 : 0.6,
    child: Container(
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(
          color: isActive
              ? AppColors.crimson.withValues(alpha: 0.2)
              : AppColors.white.withValues(alpha: 0.05),
        ),
      ),
      child: child,
    ),
  );

  Widget _buildSegmentedSelector(
    List<String> labels,
    int activeIndex,
    Function(int) onTap,
    {required bool isCompact}
  ) => Container(
    height: isCompact ? 48.h : 40.0,
    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(labels.length, (i) {
        final isActive = activeIndex == i;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 12.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? AppColors.crimson : Colors.transparent,
              borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
            ),
            child: Text(
              labels[i].toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: isCompact ? 10.sp : 9.0,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _buildActionButton({
    required String label,
    required bool isEnabled,
    required VoidCallback onPressed,
    required bool isCompact,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? 60.h : 52.0,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.crimson
              : AppColors.crimson.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.crimson.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
          border: isEnabled
              ? null
              : Border.all(color: AppColors.crimson.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonPrimary.copyWith(
            fontSize: isCompact ? 16.sp : 14.0,
            color: isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
