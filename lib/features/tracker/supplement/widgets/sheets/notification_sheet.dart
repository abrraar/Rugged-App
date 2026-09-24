// lib/features/tracker/supplement/widgets/sheets/notification_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import '../../model/supplement.dart';

class NotificationSheet extends StatefulWidget {
  final Supplement supplement;
  final List<SupplementReminder> initialReminders;
  final bool initialEnabled;
  final bool isSideSheet;

  const NotificationSheet({
    super.key,
    required this.supplement,
    required this.initialReminders,
    required this.initialEnabled,
    this.isSideSheet = false,
  });

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  late bool recordEnabled;
  late bool restockEnabled;

  late List<SupplementReminder> intakeReminders;
  ReminderMode _selectedMode = ReminderMode.schedule;
  
  double lowStockThreshold = 5.0;
  bool restockUseServings = true;

  final List<bool> intakeUseServings = [];
  final List<TextEditingController> _intakeControllers = [];
  final List<TextEditingController> _intervalControllers = [];
  late TextEditingController _restockController;

  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  void initState() {
    super.initState();
    intakeReminders = widget.initialReminders
        .where((r) => r.type == ReminderType.intake)
        .toList();
    
    recordEnabled = widget.initialEnabled && intakeReminders.isNotEmpty;

    if (intakeReminders.isNotEmpty) {
      _selectedMode = intakeReminders.first.reminderMode;
    }

    final restockReminder = widget.initialReminders.firstWhere(
      (r) => r.type == ReminderType.lowStock,
      orElse: () => SupplementReminder(
        days: [],
        times: [],
        value: 5.0,
        type: ReminderType.lowStock,
      ),
    );

    restockEnabled = widget.initialEnabled && widget.initialReminders.any(
      (r) => r.type == ReminderType.lowStock,
    );
    lowStockThreshold = restockReminder.value;

    if (widget.supplement.weightPerServing > 0 && (lowStockThreshold % widget.supplement.weightPerServing == 0)) {
      restockUseServings = true;
      _restockController = TextEditingController(
        text: (lowStockThreshold / widget.supplement.weightPerServing).toStringAsFixed(1),
      );
    } else {
      restockUseServings = false;
      _restockController = TextEditingController(
        text: lowStockThreshold.toStringAsFixed(1),
      );
    }

    for (int i = 0; i < intakeReminders.length; i++) {
      intakeUseServings.add(true);
      _intakeControllers.add(TextEditingController(
        text: intakeReminders[i].value.toStringAsFixed(1),
      ));

      int startingInterval = intakeReminders[i].intervalValue ?? 30;
      if (intakeReminders[i].intervalUnit == IntervalUnit.minute && startingInterval < 15) {
        startingInterval = 15;
      }
      _intervalControllers.add(TextEditingController(
        text: startingInterval.toString(),
      ));
    }
  }

  @override
  void dispose() {
    for (var c in _intakeControllers) {
      c.dispose();
    }
    for (var c in _intervalControllers) {
      c.dispose();
    }
    _restockController.dispose();
    super.dispose();
  }

  void _addNewIntakeSlot() {
    setState(() {
      intakeReminders.add(
        SupplementReminder(
          days: [], times: [], value: 1.0, type: ReminderType.intake,
          reminderMode: _selectedMode, intervalValue: 30, intervalUnit: IntervalUnit.minute,
        ),
      );
      intakeUseServings.add(true);
      _intakeControllers.add(TextEditingController(text: "1.0"));
      _intervalControllers.add(TextEditingController(text: "30"));
    });
  }

  void _handleSaveAndExit() {
    List<SupplementReminder> updatedIntake = [];
    
    for (int i = 0; i < intakeReminders.length; i++) {
      var r = intakeReminders[i].copyWith(reminderMode: _selectedMode);
      if (_selectedMode == ReminderMode.schedule) {
        if (r.days.isEmpty) continue;
        if (r.times.isEmpty) {
          r = r.copyWith(times: [TimeOfDay.now()]);
        }
      }
      updatedIntake.add(r);
    }

    if (updatedIntake.isEmpty && _selectedMode == ReminderMode.schedule) {
      recordEnabled = false;
    }

    bool masterActive = recordEnabled || restockEnabled;

    context.read<SupplementProvider>().updateNotificationSettings(
      targetId: widget.supplement.id,
      isStack: false, 
      masterEnabled: masterActive, 
      recordEnabled: recordEnabled, 
      restockEnabled: restockEnabled,
      intakeReminders: recordEnabled ? updatedIntake : [], 
      lowStockThresholds: restockEnabled ? {
        widget.supplement.id: restockUseServings
            ? lowStockThreshold * widget.supplement.weightPerServing
            : lowStockThreshold
      } : {},
    );
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
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: widget.isSideSheet ? double.infinity : null,
                  constraints: widget.isSideSheet ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                      if (widget.isSideSheet) SizedBox(height: 24.0),
                      if (!widget.isSideSheet) _buildHandle(isCompact),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isCompact ? 24.w : 24.0, 
                            0, 
                            isCompact ? 24.w : 24.0, 
                            isCompact ? 40.h : 32.0
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(isCompact),
                              SizedBox(height: isCompact ? 24.h : 20.0),
                              _sectionHeader(
                                "INTAKE SCHEDULE",
                                Icons.history_edu_rounded,
                                recordEnabled,
                                isCompact,
                                (val) {
                                  setState(() {
                                    recordEnabled = val;
                                    if (val && intakeReminders.isEmpty) {
                                      _addNewIntakeSlot();
                                    }
                                  });
                                },
                              ),
                              if (recordEnabled) ...[
                                _buildModeSelectorMaster(isCompact),
                                SizedBox(height: isCompact ? 12.h : 10.0),
                                ...intakeReminders.asMap().entries.map((e) => _buildIntakeCard(e.value, e.key, isCompact)),
                                _buildAddButton("ADD TIME SLOT", _addNewIntakeSlot, isCompact),
                              ],
                              SizedBox(height: isCompact ? 32.h : 24.0),
                              _sectionHeader(
                                "INVENTORY ALERTS", 
                                Icons.inventory_2_rounded, 
                                restockEnabled, 
                                isCompact,
                                (val) => setState(() => restockEnabled = val)
                              ),
                              if (restockEnabled) ...[
                                _instructionTile("Enter any inventory threshold value above 0 to trigger restock notifications.", isCompact),
                                SizedBox(height: isCompact ? 12.h : 10.0),
                                _buildLowStockCard(isCompact),
                              ],
                              SizedBox(height: isCompact ? 32.h : 24.0),
                            ],
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
      ),
    );
  }

  Widget _buildModeSelectorMaster(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 2.r : 2.0),
      margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0)),
      child: Row(
        children: [
          _modeBtnMaster("FIXED SCHEDULE", ReminderMode.schedule, isCompact),
          _modeBtnMaster("INTERVAL LOOP", ReminderMode.interval, isCompact),
        ],
      ),
    );
  }

  Widget _modeBtnMaster(String l, ReminderMode m, bool isCompact) {
    bool active = _selectedMode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = m),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 10.0),
          decoration: BoxDecoration(color: active ? AppColors.crimson : Colors.transparent, borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0)),
          alignment: Alignment.center,
          child: Text(l, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: active ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildIntakeCard(SupplementReminder reminder, int index, bool isCompact) {
    bool useServings = intakeUseServings[index];
    bool isSchedule = _selectedMode == ReminderMode.schedule;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 24.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("SET DOSE CONFIG", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0)),
              IconButton(
                onPressed: () => setState(() {
                  intakeReminders.removeAt(index);
                  intakeUseServings.removeAt(index);
                  _intakeControllers[index].dispose();
                  _intakeControllers.removeAt(index);
                  _intervalControllers[index].dispose();
                  _intervalControllers.removeAt(index);
                }),
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withValues(alpha: 0.7), size: isCompact ? 20.r : 20.0),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8.h : 6.0),
          Container(
            padding: EdgeInsets.all(isCompact ? 8.r : 6.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
              border: Border.all(color: AppColors.crimson.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _valueInputStepper(
                    controller: _intakeControllers[index],
                    value: reminder.value,
                    isInventory: false,
                    isCompact: isCompact,
                    onChanged: (val) => setState(() {
                      intakeReminders[index] = reminder.copyWith(value: val);
                    }),
                  ),
                ),
                SizedBox(width: isCompact ? 12.w : 12.0),
                _unitBtn(widget.supplement.servingUnit.toUpperCase(), useServings, () => setState(() => intakeUseServings[index] = true), isCompact),
                SizedBox(width: isCompact ? 4.w : 4.0),
                _unitBtn(widget.supplement.weightUnit.toUpperCase(), !useServings, () => setState(() => intakeUseServings[index] = false), isCompact),
              ],
            ),
          ),
          Divider(color: AppColors.white.withValues(alpha: 0.05), height: isCompact ? 32.h : 24.0),

          if (isSchedule) ...[
            _buildDayPicker(reminder, index, isCompact),
            SizedBox(height: isCompact ? 20.h : 16.0),
            _buildTimeChips(reminder, index, isCompact),
          ] else ...[
            _buildIntervalPicker(reminder, index, isCompact),
          ],
        ],
      ),
    );
  }

  Widget _buildIntervalPicker(SupplementReminder reminder, int index, bool isCompact) {
    int currentVal = reminder.intervalValue ?? 30;
    IntervalUnit currentUnit = reminder.intervalUnit ?? IntervalUnit.minute;
    final controller = _intervalControllers[index];
    int minLimit = (currentUnit == IntervalUnit.minute) ? 15 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("REMIND ME EVERY:", style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0)),
            const Spacer(),
            Container(
              width: isCompact ? 140.w : 120.0,
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 4.w : 4.0, vertical: isCompact ? 2.h : 2.0),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0)),
              child: Row(
                children: [
                  _stepBtn(Icons.remove, () {
                    int next = currentVal - 1;
                    int finalVal = next >= minLimit ? next : minLimit;
                    controller.text = finalVal.toString();
                    setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: finalVal));
                  }, isCompact),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      onChanged: (text) {
                        int? parsed = int.tryParse(text);
                        if (parsed != null) {
                           setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: parsed));
                        }
                      },
                      onFieldSubmitted: (text) {
                        int? parsed = int.tryParse(text);
                        int finalVal = (parsed == null || parsed < minLimit) ? minLimit : parsed;
                        controller.text = finalVal.toString();
                        setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: finalVal));
                      },
                    ),
                  ),
                  _stepBtn(Icons.add, () {
                    int next = currentVal + 1;
                    controller.text = next.toString();
                    setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: next));
                  }, isCompact),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 16.h : 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _unitBtn("MINS", currentUnit == IntervalUnit.minute, () {
                int finalVal = currentVal;
                if (finalVal < 15) { finalVal = 15; controller.text = "15"; }
                setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.minute, intervalValue: finalVal));
            }, isCompact),
            SizedBox(width: 6.w),
            _unitBtn("HRS", currentUnit == IntervalUnit.hour, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.hour)), isCompact),
            SizedBox(width: 6.w),
            _unitBtn("DAYS", currentUnit == IntervalUnit.day, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.day)), isCompact),
          ],
        ),
      ],
    );
  }

  Widget _buildLowStockCard(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 24.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("THRESHOLD CONFIG", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0)),
          SizedBox(height: isCompact ? 16.h : 12.0),
          Container(
            padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(isCompact ? 20.r : 14.0)),
            child: Column(
              children: [
                _valueInputStepper(
                  controller: _restockController,
                  value: lowStockThreshold,
                  isInventory: true,
                  isCompact: isCompact,
                  onChanged: (val) => setState(() => lowStockThreshold = val),
                ),
                SizedBox(height: isCompact ? 16.h : 12.0),
                Row(
                  children: [
                    Expanded(child: _unitBtn(widget.supplement.servingUnit.toUpperCase(), restockUseServings, () {
                        if (!restockUseServings) {
                          setState(() {
                            double currentWeight = double.tryParse(_restockController.text) ?? 0.0;
                            if (widget.supplement.weightPerServing > 0) {
                              _restockController.text = (currentWeight / widget.supplement.weightPerServing).toStringAsFixed(1);
                              lowStockThreshold = double.tryParse(_restockController.text) ?? 0.0;
                            }
                            restockUseServings = true;
                          });
                        }
                    }, isCompact)),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(child: _unitBtn(widget.supplement.weightUnit.toUpperCase(), !restockUseServings, () {
                        if (restockUseServings) {
                          setState(() {
                            double currentServings = double.tryParse(_restockController.text) ?? 0.0;
                            _restockController.text = (currentServings * widget.supplement.weightPerServing).toStringAsFixed(1);
                            lowStockThreshold = double.tryParse(_restockController.text) ?? 0.0;
                            restockUseServings = false;
                          });
                        }
                    }, isCompact)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueInputStepper({required TextEditingController controller, required double value, required bool isInventory, required bool isCompact, required Function(double) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4.w : 4.0, vertical: isCompact ? 2.h : 2.0),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepBtn(Icons.remove, () {
            double minVal = isInventory ? 0.0 : 0.5;
            double newVal = (value > minVal) ? value - 0.5 : minVal;
            controller.text = newVal.toStringAsFixed(1);
            onChanged(newVal);
          }, isCompact),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))],
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              onChanged: (text) {
                double? parsed = double.tryParse(text);
                if (parsed != null) { if (!isInventory && parsed < 0.5) return; onChanged(parsed); }
              },
              onSubmitted: (text) {
                double? parsed = double.tryParse(text);
                double minVal = isInventory ? 0.0 : 0.5;
                if (parsed == null || parsed < minVal) { controller.text = minVal.toStringAsFixed(1); onChanged(minVal); }
              },
            ),
          ),
          _stepBtn(Icons.add, () {
            double newVal = value + 0.5;
            controller.text = newVal.toStringAsFixed(1);
            onChanged(newVal);
          }, isCompact),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap, bool isCompact) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(isCompact ? 6.r : 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(icon, color: AppColors.crimson, size: isCompact ? 16.r : 16.0),
    ),
  );

  Widget _unitBtn(String label, bool active, VoidCallback onTap, bool isCompact) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 12.0, vertical: isCompact ? 10.h : 8.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: active ? AppColors.crimson : AppColors.background, borderRadius: BorderRadius.circular(10.r)),
          child: Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: active ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
      );

  Widget _buildDayPicker(SupplementReminder reminder, int index, bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isSelected = reminder.days.contains(i + 1);
        return GestureDetector(
          onTap: () => setState(() {
              if (isSelected) {
                reminder.days.remove(i + 1);
              } else {
                reminder.days.add(i + 1);
              }
          }),
          child: Container(
            width: isCompact ? 36.r : 32.0, 
            height: isCompact ? 36.r : 32.0,
            decoration: BoxDecoration(color: isSelected ? AppColors.crimson : AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.white.withValues(alpha: 0.05))),
            alignment: Alignment.center,
            child: Text(weekDays[i], style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: isCompact ? 10.sp : 10.0)),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChips(SupplementReminder reminder, int index, bool isCompact) {
    return Wrap(
      spacing: isCompact ? 8.w : 8.0, 
      runSpacing: isCompact ? 8.h : 8.0,
      children: [
        ...reminder.times.map((t) => Chip(
            backgroundColor: AppColors.surface,
            label: Text(t.format(context), style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? null : 10.0)),
            deleteIcon: Icon(Icons.close, size: isCompact ? 14.r : 14.0, color: AppColors.crimson),
            onDeleted: () => setState(() => reminder.times.remove(t)),
          ),
        ),
        Opacity(
          opacity: reminder.days.isNotEmpty ? 1.0 : 0.4,
          child: GestureDetector(
            onTap: reminder.days.isNotEmpty ? () => _selectTime(reminder) : null,
            child: Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 12.0, vertical: isCompact ? 8.h : 8.0),
                decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: isCompact ? 14.r : 14.0, color: AppColors.crimson),
                    SizedBox(width: 4.w),
                    Text("ADD TIME", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 10.0)),
                  ],
                ),
              ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(SupplementReminder reminder) async {
    final picked = await showTimePicker(
      context: context,
      useRootNavigator: true,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: child!,
        ),
      ),
    );
    if (picked != null && !reminder.times.contains(picked)) {
      setState(() => reminder.times.add(picked));
    }
  }

  Widget _buildHeader(bool isCompact) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 10.r : 10.0), 
          decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle), 
          child: Icon(Icons.notifications_active_rounded, color: AppColors.crimson, size: isCompact ? 22.r : 22.0)
        ),
        SizedBox(width: isCompact ? 12.w : 12.0),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("SUPPLEMENT NOTIFICATION", style: AppTextStyles.h3.copyWith(fontSize: isCompact ? null : 18.0)),
              Text(
                widget.supplement.name.toUpperCase(), 
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary, 
                  letterSpacing: 1.2,
                  fontSize: isCompact ? null : 10.0,
                )
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
  }

  Widget _sectionHeader(String l, IconData i, bool v, bool isCompact, Function(bool) o) =>
      Padding(
        padding: EdgeInsets.only(bottom: isCompact ? 8.h : 6.0),
        child: Row(
          children: [
            Icon(i, color: AppColors.crimson, size: isCompact ? 16.r : 16.0),
            SizedBox(width: isCompact ? 8.w : 8.0),
            Text(l, style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0)),
            const Spacer(),
            Transform.scale(scale: 0.8, child: Switch.adaptive(value: v, activeTrackColor: AppColors.crimson, onChanged: o)),
          ],
        ),
      );

  Widget _buildAddButton(String l, VoidCallback o, bool isCompact) => GestureDetector(
    onTap: o,
    child: Container(
      margin: EdgeInsets.only(top: isCompact ? 12.h : 10.0),
      padding: EdgeInsets.symmetric(vertical: isCompact ? 14.h : 14.0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0), border: Border.all(color: AppColors.white.withValues(alpha: 0.05)), color: AppColors.white.withValues(alpha: 0.02)),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: isCompact ? 18.r : 18.0),
          SizedBox(width: isCompact ? 8.w : 8.0),
          Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0)),
        ],
      ),
    ),
  );

  Widget _instructionTile(String t, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 14.0, vertical: isCompact ? 12.h : 10.0),
      decoration: BoxDecoration(
        color: AppColors.crimson.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.15), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: isCompact ? 14.r : 14.0, color: AppColors.crimson),
          SizedBox(width: isCompact ? 10.w : 10.0),
          Expanded(child: Text(t, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isCompact) => Center(child: Container(margin: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 10.0), width: isCompact ? 40.w : 40.0, height: isCompact ? 4.h : 4.0, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r))));
}
