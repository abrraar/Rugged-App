// lib/features/tracker/supplement/widgets/sheets/stack_notification_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import '../../model/supplement.dart';
import '../../model/supplement_stack.dart';

class StackNotificationSheet extends StatefulWidget {
  final SupplementStack stack;
  final List<SupplementReminder> initialReminders;
  final bool initialEnabled;
  final bool isSideSheet;

  const StackNotificationSheet({
    super.key,
    required this.stack,
    required this.initialReminders,
    required this.initialEnabled,
    this.isSideSheet = false,
  });

  @override
  State<StackNotificationSheet> createState() => _StackNotificationSheetState();
}

class _StackNotificationSheetState extends State<StackNotificationSheet> {
  late bool recordEnabled;
  late bool restockEnabled;

  late List<SupplementReminder> intakeReminders;
  ReminderMode _selectedMode = ReminderMode.schedule;

  final Map<String, double> lowStockValues = {};
  final Map<String, bool> lowStockUseServings = {};
  final Map<String, TextEditingController> _lowStockControllers = {};

  final List<Map<String, TextEditingController>> _itemControllers = [];
  final List<Map<String, bool>> _itemUseServings = [];
  final List<TextEditingController> _intervalControllers = [];

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

    restockEnabled = widget.initialEnabled && widget.initialReminders.any(
      (r) => r.type == ReminderType.lowStock,
    );

    for (int i = 0; i < intakeReminders.length; i++) {
      _initItemStatesForReminder(intakeReminders[i]);
    }

    for (var item in widget.stack.items) {
      final existing = widget.initialReminders.firstWhere(
        (r) => r.type == ReminderType.lowStock && r.supplementId == item.id,
        orElse: () => SupplementReminder(
          days: [], times: [], value: 5.0, type: ReminderType.lowStock, supplementId: item.id,
        ),
      );
      lowStockValues[item.id] = existing.value;
      if (item.weightPerServing > 0 && (existing.value % item.weightPerServing == 0)) {
        lowStockUseServings[item.id] = true;
        _lowStockControllers[item.id] = TextEditingController(text: (existing.value / item.weightPerServing).toStringAsFixed(1));
      } else {
        lowStockUseServings[item.id] = false;
        _lowStockControllers[item.id] = TextEditingController(text: existing.value.toStringAsFixed(1));
      }
    }
  }

  void _initItemStatesForReminder(SupplementReminder reminder) {
    Map<String, TextEditingController> controllers = {};
    Map<String, bool> useServings = {};

    int startingValue = reminder.intervalValue ?? 30;
    if (reminder.intervalUnit == IntervalUnit.minute && startingValue < 15) startingValue = 15;
    _intervalControllers.add(TextEditingController(text: startingValue.toString()));

    for (var item in widget.stack.items) {
      final double initialValue = reminder.stackItemValues?[item.id] ?? 1.0;
      controllers[item.id] = TextEditingController(text: initialValue.toStringAsFixed(1));
      useServings[item.id] = true;
    }
    _itemControllers.add(controllers);
    _itemUseServings.add(useServings);
  }

  void _performFinalCleanupAndSave() {
    List<SupplementReminder> updatedIntake = [];
    
    for (int i = 0; i < intakeReminders.length; i++) {
      var r = intakeReminders[i].copyWith(reminderMode: _selectedMode);
      
      if (_selectedMode == ReminderMode.schedule) {
        if (r.days.isEmpty) continue;
        if (r.times.isEmpty) {
          r = r.copyWith(times: [TimeOfDay.now()]);
        }
      }

      final Map<String, double> itemValues = {};
      for (var item in widget.stack.items) {
        double? val = double.tryParse(_itemControllers[i][item.id]?.text ?? "");
        itemValues[item.id] = (val == null || val <= 0) ? 1.0 : val;
      }
      r = r.copyWith(stackItemValues: itemValues);
      updatedIntake.add(r);
    }

    if (updatedIntake.isEmpty && _selectedMode == ReminderMode.schedule) {
      recordEnabled = false;
    }

    final Map<String, double> thresholds = {};
    for (var item in widget.stack.items) {
      double raw = double.tryParse(_lowStockControllers[item.id]?.text ?? "") ?? 5.0;
      thresholds[item.id] = (lowStockUseServings[item.id] ?? false) ? raw * item.weightPerServing : raw;
    }

    bool masterActive = recordEnabled || restockEnabled;

    context.read<SupplementProvider>().updateNotificationSettings(
      targetId: widget.stack.id, 
      isStack: true, 
      masterEnabled: masterActive,
      recordEnabled: recordEnabled, 
      restockEnabled: restockEnabled,
      intakeReminders: recordEnabled ? updatedIntake : [], 
      lowStockThresholds: restockEnabled ? thresholds : {},
    );
  }

  @override
  void dispose() {
    for (var m in _itemControllers) {
      for (var c in m.values) {
        c.dispose();
      }
    }
    for (var c in _intervalControllers) {
      c.dispose();
    }
    for (var c in _lowStockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) { if (didPop) _performFinalCleanupAndSave(); },
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
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05))
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: _buildHeader(isCompact)),
                                  if (widget.isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 24.h : 20.0),
                              _sectionHeader(
                                "STACK SCHEDULE", 
                                Icons.layers_rounded, 
                                recordEnabled, 
                                isCompact,
                                (v) => setState(() {
                                    recordEnabled = v;
                                    if (v && intakeReminders.isEmpty) _addNewSlot();
                                })
                              ),
                              if (recordEnabled) ...[
                                _buildModeSelectorMaster(isCompact),
                                SizedBox(height: isCompact ? 12.h : 10.0),
                                ...intakeReminders.asMap().entries.map((e) => _buildGranularCard(e.value, e.key, isCompact)),
                                _buildAddButton("ADD NEW TIME SLOT", _addNewSlot, isCompact),
                              ],
                              SizedBox(height: isCompact ? 32.h : 24.0),
                              _sectionHeader(
                                "INVENTORY ALERTS", 
                                Icons.inventory_2_rounded, 
                                restockEnabled, 
                                isCompact,
                                (v) => setState(() => restockEnabled = v)
                              ),
                              if (restockEnabled) ...[
                                _instructionTile("Enter any inventory threshold value above 0 to trigger restock notifications.", isCompact),
                                SizedBox(height: isCompact ? 12.h : 10.0),
                                ...widget.stack.items.map((i) => _buildLowStockCard(i, isCompact)),
                              ],
                            ]
                          )
                        )
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

  void _addNewSlot() {
    setState(() {
      final r = SupplementReminder(
        days: [], 
        times: [], 
        value: 1.0, 
        type: ReminderType.intake, 
        supplementIds: widget.stack.items.map((i) => i.id).toList(), 
        reminderMode: _selectedMode, 
        intervalValue: 30, 
        intervalUnit: IntervalUnit.minute
      );
      intakeReminders.add(r);
      _initItemStatesForReminder(r);
    });
  }

  Widget _buildModeSelectorMaster(bool isCompact) {
    return Container(padding: EdgeInsets.all(isCompact ? 2.r : 2.0), margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0)), child: Row(children: [
          _modeBtnMaster("FIXED SCHEDULE", ReminderMode.schedule, isCompact),
          _modeBtnMaster("INTERVAL LOOP", ReminderMode.interval, isCompact),
    ]));
  }

  Widget _modeBtnMaster(String l, ReminderMode m, bool isCompact) {
    bool active = _selectedMode == m;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _selectedMode = m), child: Container(padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 10.0), decoration: BoxDecoration(color: active ? AppColors.crimson : Colors.transparent, borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0)), alignment: Alignment.center, child: Text(l, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: active ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500)))));
  }

  Widget _buildGranularCard(SupplementReminder reminder, int index, bool isCompact) {
    bool isSchedule = _selectedMode == ReminderMode.schedule;
    return Container(margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0), padding: EdgeInsets.all(isCompact ? 20.r : 16.0), decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(isCompact ? 24.r : 16.0), border: Border.all(color: AppColors.white.withValues(alpha: 0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("TIME SLOT CONFIG", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0)),
              if (intakeReminders.length > 1) IconButton(onPressed: () => setState(() { 
                intakeReminders.removeAt(index); 
                for (var c in _itemControllers[index].values) {
                  c.dispose();
                }
                _itemControllers.removeAt(index); 
                _itemUseServings.removeAt(index);
                _intervalControllers[index].dispose();
                _intervalControllers.removeAt(index); 
              }), icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withValues(alpha: 0.7), size: isCompact ? 20.r : 20.0)),
          ]),
          SizedBox(height: isCompact ? 8.h : 8.0),
          ...widget.stack.items.map((i) => _buildGranularItemRow(index, i, reminder, isCompact)),
          Divider(color: AppColors.white.withValues(alpha: 0.05), height: isCompact ? 24.h : 20.0),
          if (isSchedule) ...[
            _buildDayPicker(reminder, isCompact, (days) => setState(() => intakeReminders[index] = reminder.copyWith(days: days))),
            SizedBox(height: isCompact ? 16.h : 12.0),
            _buildTimeChips(reminder, isCompact, (times) => setState(() => intakeReminders[index] = reminder.copyWith(times: times))),
          ] else ...[
            _buildIntervalPicker(reminder, index, isCompact),
          ],
    ]));
  }

  Widget _buildIntervalPicker(SupplementReminder reminder, int index, bool isCompact) {
    int currentVal = reminder.intervalValue ?? 30;
    IntervalUnit currentUnit = reminder.intervalUnit ?? IntervalUnit.minute;
    final controller = _intervalControllers[index];
    int minLimit = (currentUnit == IntervalUnit.minute) ? 15 : 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
            Text("REMIND ME EVERY:", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isCompact ? 11.sp : 11.0, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(width: isCompact ? 130.w : 120.0, padding: EdgeInsets.symmetric(horizontal: isCompact ? 4.w : 4.0, vertical: isCompact ? 2.h : 2.0), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0)), child: Row(children: [
                  _stepBtn(Icons.remove, () { int next = currentVal - 1; int finalVal = next >= minLimit ? next : minLimit; controller.text = finalVal.toString(); setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: finalVal)); }, isCompact),
                  Expanded(child: TextFormField(controller: controller, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0), inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onFieldSubmitted: (text) { int? p = int.tryParse(text); int f = (p == null || p < minLimit) ? minLimit : p; controller.text = f.toString(); setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: f)); })),
                  _stepBtn(Icons.add, () { int next = currentVal + 1; controller.text = next.toString(); setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: next)); }, isCompact),
            ])),
        ]),
        SizedBox(height: isCompact ? 12.h : 10.0),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _unitBtn("MINS", currentUnit == IntervalUnit.minute, () { int f = currentVal; if (f < 15) { f = 15; controller.text = "15"; } setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.minute, intervalValue: f)); }, isCompact),
            SizedBox(width: 4.w),
            _unitBtn("HRS", currentUnit == IntervalUnit.hour, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.hour)), isCompact),
            SizedBox(width: 4.w),
            _unitBtn("DAYS", currentUnit == IntervalUnit.day, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.day)), isCompact),
        ]),
    ]);
  }

  Widget _buildGranularItemRow(int rIdx, Supplement item, SupplementReminder r, bool isCompact) {
    final enabled = r.supplementIds?.contains(item.id) ?? false;
    final controller = _itemControllers[rIdx][item.id]!;
    final useServings = _itemUseServings[rIdx][item.id]!;
    return AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: enabled ? 1.0 : 0.4, child: Container(margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0), padding: EdgeInsets.all(isCompact ? 12.r : 10.0), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0), border: Border.all(color: enabled ? AppColors.crimson.withValues(alpha: 0.2) : Colors.transparent)), child: Column(children: [
            Row(children: [
                Expanded(child: Text(item.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, fontSize: isCompact ? 11.sp : 11.0))),
                Transform.scale(scale: 0.7, child: Switch.adaptive(value: enabled, activeTrackColor: AppColors.crimson, onChanged: (val) { setState(() { final ids = List<String>.from(r.supplementIds ?? []); val ? ids.add(item.id) : ids.remove(item.id); intakeReminders[rIdx] = r.copyWith(supplementIds: ids); }); })),
            ]),
            if (enabled) ...[
              SizedBox(height: isCompact ? 12.h : 10.0),
              Row(children: [
                  Expanded(child: _valueInputStepper(controller: controller, isCompact: isCompact, onManualChanged: (v) => setState(() {}))),
                  SizedBox(width: isCompact ? 12.w : 10.0),
                  _unitBtn(item.servingUnit, useServings, () => setState(() => _itemUseServings[rIdx][item.id] = true), isCompact),
                  SizedBox(width: 4.w),
                  _unitBtn(item.weightUnit, !useServings, () => setState(() => _itemUseServings[rIdx][item.id] = false), isCompact),
              ]),
            ],
    ])));
  }

  Widget _buildLowStockCard(Supplement item, bool isCompact) {
    bool useServings = lowStockUseServings[item.id] ?? false;
    final controller = _lowStockControllers[item.id]!;
    return Container(margin: EdgeInsets.only(bottom: isCompact ? 16.h : 12.0), padding: EdgeInsets.all(20.r), decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.white.withValues(alpha: 0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.5, color: Colors.white, fontSize: isCompact ? null : 11.0)),
          SizedBox(height: 16.h),
          Container(padding: EdgeInsets.all(12.r), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20.r)), child: Column(children: [
                _valueInputStepper(controller: controller, isCompact: isCompact, onManualChanged: (v) => setState(() {})),
                SizedBox(height: 16.h),
                Row(children: [
                    Expanded(child: _unitBtn(item.servingUnit, useServings, () { if (!useServings) setState(() { double w = double.tryParse(controller.text) ?? 0.0; if (item.weightPerServing > 0) controller.text = (w / item.weightPerServing).toStringAsFixed(1); lowStockUseServings[item.id] = true; }); }, isCompact)),
                    SizedBox(width: 12.w),
                    Expanded(child: _unitBtn(item.weightUnit, !useServings, () { if (useServings) setState(() { double s = double.tryParse(controller.text) ?? 0.0; controller.text = (s * item.weightPerServing).toStringAsFixed(1); lowStockUseServings[item.id] = false; }); }, isCompact)),
                ]),
          ])),
    ]));
  }

  Widget _valueInputStepper({required TextEditingController controller, required bool isCompact, required Function(double) onManualChanged}) {
    double value = double.tryParse(controller.text) ?? 1.0;
    return Container(padding: EdgeInsets.symmetric(horizontal: isCompact ? 4.w : 4.0, vertical: isCompact ? 2.h : 2.0), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10.r)), child: Row(children: [
          _stepBtn(Icons.remove, () { double n = (value > 0.5) ? value - 0.5 : 0.1; if (n <= 0.0) n = 1.0; controller.text = n.toStringAsFixed(1); onManualChanged(n); }, isCompact),
          Expanded(child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))], decoration: const InputDecoration(border: InputBorder.none, isDense: true), onSubmitted: (t) { double? p = double.tryParse(t); controller.text = (p == null || p <= 0) ? "1.0" : p.toStringAsFixed(1); onManualChanged(double.parse(controller.text)); })),
          _stepBtn(Icons.add, () { double n = value + 0.5; controller.text = n.toStringAsFixed(1); onManualChanged(n); }, isCompact),
    ]));
  }

  Widget _buildDayPicker(SupplementReminder r, bool isCompact, Function(List<int>) onChanged) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (i) {
        final sel = r.days.contains(i + 1);
        return GestureDetector(onTap: () => onChanged(sel ? (List.from(r.days)..remove(i + 1)) : (List.from(r.days)..add(i + 1))), child: Container(width: isCompact ? 36.r : 34.0, height: isCompact ? 36.r : 34.0, decoration: BoxDecoration(color: sel ? AppColors.crimson : AppColors.surface, shape: BoxShape.circle, border: Border.all(color: sel ? Colors.transparent : AppColors.white.withValues(alpha: 0.05))), alignment: Alignment.center, child: Text(weekDays[i], style: AppTextStyles.labelSmall.copyWith(color: sel ? Colors.white : AppColors.textSecondary, fontSize: isCompact ? 10.sp : 10.0))));
    }));
  }

  Widget _buildTimeChips(SupplementReminder r, bool isCompact, Function(List<TimeOfDay>) onChanged) {
    return Wrap(spacing: isCompact ? 8.w : 8.0, runSpacing: isCompact ? 8.h : 8.0, children: [
        ...r.times.map((t) => Chip(backgroundColor: AppColors.surface, label: Text(t.format(context), style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? null : 10.0)), onDeleted: () => onChanged(List.from(r.times)..remove(t)), deleteIcon: Icon(Icons.close, size: isCompact ? 14.r : 14.0, color: AppColors.crimson))),
        Opacity(
          opacity: r.days.isNotEmpty ? 1.0 : 0.4,
          child: GestureDetector(
            onTap: r.days.isNotEmpty ? () async { 
              final p = await showTimePicker(
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
              if (p != null) onChanged(List.from(r.times)..add(p)); 
            } : null, 
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 12.0, vertical: isCompact ? 8.h : 6.0), 
              decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)), 
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time_rounded, size: 14.r, color: AppColors.crimson), 
                SizedBox(width: 4.w), 
                Text("ADD TIME", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 10.0))
              ])
            )
          ),
        ),
    ]);
  }

  Widget _buildHeader(bool isCompact) { return Row(children: [Container(padding: EdgeInsets.all(isCompact ? 10.r : 10.0), decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.layers_rounded, color: AppColors.crimson, size: isCompact ? 22.r : 22.0)), SizedBox(width: isCompact ? 12.w : 12.0), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("STACK NOTIFICATION", style: AppTextStyles.h3.copyWith(fontSize: isCompact ? null : 18.0)), Text(widget.stack.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2, fontSize: isCompact ? null : 10.0))]))]); }
  Widget _buildHandle(bool isCompact) => Center(child: Container(margin: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0), width: isCompact ? 40.w : 40.0, height: isCompact ? 4.h : 4.0, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r))));
  Widget _sectionHeader(String l, IconData i, bool v, bool isCompact, Function(bool) o) => Padding(padding: EdgeInsets.only(bottom: isCompact ? 8.h : 6.0), child: Row(children: [Icon(i, color: AppColors.crimson, size: isCompact ? 16.r : 16.0), SizedBox(width: isCompact ? 8.w : 8.0), Text(l, style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0)), const Spacer(), Transform.scale(scale: 0.8, child: Switch.adaptive(value: v, activeTrackColor: AppColors.crimson, onChanged: o))]));
  Widget _instructionTile(String t, bool isCompact) { return Container(padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 14.0, vertical: isCompact ? 12.h : 10.0), decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(isCompact ? 12.r : 12.0), border: Border.all(color: AppColors.crimson.withValues(alpha: 0.15), width: 1.0)), child: Row(children: [Icon(Icons.info_outline_rounded, size: isCompact ? 14.r : 14.0, color: AppColors.crimson), SizedBox(width: isCompact ? 10.w : 10.0), Expanded(child: Text(t, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: AppColors.textSecondary, fontStyle: FontStyle.italic)))])); }
  Widget _stepBtn(IconData i, VoidCallback? o, bool isCompact) => GestureDetector(onTap: o, child: Container(padding: EdgeInsets.all(isCompact ? 6.r : 6.0), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0)), child: Icon(i, color: o != null ? AppColors.crimson : AppColors.crimson.withValues(alpha: 0.3), size: isCompact ? 16.r : 16.0)));
  Widget _unitBtn(String l, bool a, VoidCallback? o, bool isCompact) => GestureDetector(onTap: o, child: Container(padding: EdgeInsets.symmetric(horizontal: isCompact ? 10.w : 10.0, vertical: isCompact ? 8.h : 8.0), decoration: BoxDecoration(color: a ? AppColors.crimson : AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0)), child: Text(l.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 9.sp : 9.0, color: a ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500))));
  Widget _buildAddButton(String l, VoidCallback o, bool isCompact) => GestureDetector(onTap: o, child: Container(margin: EdgeInsets.only(top: isCompact ? 12.h : 12.0), padding: EdgeInsets.symmetric(vertical: isCompact ? 14.h : 12.0), decoration: BoxDecoration(borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0), color: AppColors.white.withValues(alpha: 0.02), border: Border.all(color: AppColors.white.withValues(alpha: 0.05))), alignment: Alignment.center, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: isCompact ? 18.r : 18.0), SizedBox(width: isCompact ? 8.w : 8.0), Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0))])));
}
