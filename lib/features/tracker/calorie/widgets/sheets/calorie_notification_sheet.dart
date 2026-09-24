import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:provider/provider.dart';
import '../../model/saved_meal.dart';

class CalorieNotificationSheet extends StatefulWidget {
  final SavedMeal meal;
  final bool isSideSheet;

  const CalorieNotificationSheet({
    super.key,
    required this.meal,
    this.isSideSheet = false,
  });

  @override
  State<CalorieNotificationSheet> createState() => _CalorieNotificationSheetState();
}

class _CalorieNotificationSheetState extends State<CalorieNotificationSheet> {
  late bool notificationsEnabled;
  late List<CalorieReminder> reminders;
  CalorieReminderMode _selectedMode = CalorieReminderMode.schedule;
  
  final List<TextEditingController> _intervalControllers = [];
  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  void initState() {
    super.initState();
    notificationsEnabled = widget.meal.notificationsEnabled;
    reminders = List.from(widget.meal.reminders);
    
    if (reminders.isNotEmpty) {
      _selectedMode = reminders.first.reminderMode;
    } else if (notificationsEnabled) {
      _addNewReminderSlot();
    }

    for (var r in reminders) {
      _intervalControllers.add(TextEditingController(text: (r.intervalValue ?? 30).toString()));
    }
  }

  @override
  void dispose() {
    for (var c in _intervalControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addNewReminderSlot() {
    setState(() {
      reminders.add(
        CalorieReminder(
          days: [], times: [],
          reminderMode: _selectedMode, intervalValue: 30, intervalUnit: CalorieIntervalUnit.minute,
        ),
      );
      _intervalControllers.add(TextEditingController(text: "30"));
    });
  }

  void _handleSaveAndExit() {
    List<CalorieReminder> updatedReminders = [];
    
    for (int i = 0; i < reminders.length; i++) {
      final r = reminders[i].copyWith(reminderMode: _selectedMode);
      if (_selectedMode == CalorieReminderMode.schedule) {
        if (r.days.isEmpty) continue;
        updatedReminders.add(r.times.isEmpty ? r.copyWith(times: [TimeOfDay.now()]) : r);
      } else {
        updatedReminders.add(r);
      }
    }

    final updatedMeal = widget.meal.copyWith(
      notificationsEnabled: notificationsEnabled,
      reminders: updatedReminders,
    );

    context.read<CalorieProvider>().updateSavedMeal(updatedMeal);
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
                                "MEAL SCHEDULE",
                                Icons.history_edu_rounded,
                                notificationsEnabled,
                                isCompact,
                                (val) {
                                  setState(() {
                                    notificationsEnabled = val;
                                    if (val && reminders.isEmpty) {
                                      _addNewReminderSlot();
                                    }
                                  });
                                },
                              ),
                              if (notificationsEnabled) ...[
                                _buildModeSelectorMaster(isCompact),
                                SizedBox(height: isCompact ? 12.h : 10.0),
                                ...reminders.asMap().entries.map((e) => _buildReminderCard(e.value, e.key, isCompact)),
                                _buildAddButton("ADD TIME SLOT", _addNewReminderSlot, isCompact),
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
              Text("MEAL NOTIFICATION", style: AppTextStyles.h3.copyWith(fontSize: isCompact ? null : 18.0)),
              Text(
                widget.meal.name.toUpperCase(), 
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

  Widget _buildModeSelectorMaster(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 2.r : 2.0),
      margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0)),
      child: Row(
        children: [
          _modeBtnMaster("FIXED SCHEDULE", CalorieReminderMode.schedule, isCompact),
          _modeBtnMaster("INTERVAL LOOP", CalorieReminderMode.interval, isCompact),
        ],
      ),
    );
  }

  Widget _modeBtnMaster(String l, CalorieReminderMode m, bool isCompact) {
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

  Widget _buildReminderCard(CalorieReminder reminder, int index, bool isCompact) {
    bool isSchedule = _selectedMode == CalorieReminderMode.schedule;

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
              Text("SET REMINDER", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0)),
              if (reminders.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    reminders.removeAt(index);
                    _intervalControllers[index].dispose();
                    _intervalControllers.removeAt(index);
                  }),
                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withValues(alpha: 0.7), size: isCompact ? 20.r : 20.0),
                ),
            ],
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

  Widget _buildIntervalPicker(CalorieReminder reminder, int index, bool isCompact) {
    int currentVal = reminder.intervalValue ?? 30;
    CalorieIntervalUnit currentUnit = reminder.intervalUnit ?? CalorieIntervalUnit.minute;
    final controller = _intervalControllers[index];
    int minLimit = (currentUnit == CalorieIntervalUnit.minute) ? 15 : 1;

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
                    setState(() => reminders[index] = reminder.copyWith(intervalValue: finalVal));
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
                           setState(() => reminders[index] = reminder.copyWith(intervalValue: parsed));
                        }
                      },
                    ),
                  ),
                  _stepBtn(Icons.add, () {
                    int next = currentVal + 1;
                    controller.text = next.toString();
                    setState(() => reminders[index] = reminder.copyWith(intervalValue: next));
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
            _unitBtn("MINS", currentUnit == CalorieIntervalUnit.minute, () {
                int finalVal = currentVal;
                if (finalVal < 15) { finalVal = 15; controller.text = "15"; }
                setState(() => reminders[index] = reminder.copyWith(intervalUnit: CalorieIntervalUnit.minute, intervalValue: finalVal));
            }, isCompact),
            SizedBox(width: 6.w),
            _unitBtn("HRS", currentUnit == CalorieIntervalUnit.hour, () => setState(() => reminders[index] = reminder.copyWith(intervalUnit: CalorieIntervalUnit.hour)), isCompact),
            SizedBox(width: 6.w),
            _unitBtn("DAYS", currentUnit == CalorieIntervalUnit.day, () => setState(() => reminders[index] = reminder.copyWith(intervalUnit: CalorieIntervalUnit.day)), isCompact),
          ],
        ),
      ],
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
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 10.0, vertical: isCompact ? 10.h : 8.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: active ? AppColors.crimson : AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0)),
          child: Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: active ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
      );

  Widget _buildDayPicker(CalorieReminder reminder, int index, bool isCompact) {
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

  Widget _buildTimeChips(CalorieReminder reminder, int index, bool isCompact) {
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
        GestureDetector(
          onTap: () => _selectTime(reminder),
          child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 12.0, vertical: isCompact ? 8.h : 8.0),
              decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0)),
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
      ],
    );
  }

  Future<void> _selectTime(CalorieReminder reminder) async {
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
      padding: EdgeInsets.symmetric(vertical: isCompact ? 14.h : 12.0),
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

  Widget _buildHandle(bool isCompact) => Center(child: Container(margin: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 10.0), width: isCompact ? 40.w : 40.0, height: isCompact ? 4.h : 4.0, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r))));
}
