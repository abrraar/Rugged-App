import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import '../model/body_comp_settings.dart';

class BodyCompNotificationSheet extends StatefulWidget {
  final String title;
  final List<BodyCompReminder> initialReminders;
  final bool initialEnabled;
  final Function(bool, List<BodyCompReminder>) onSave;
  final bool isSideSheet;

  const BodyCompNotificationSheet({
    super.key,
    required this.title,
    required this.initialReminders,
    required this.initialEnabled,
    required this.onSave,
    this.isSideSheet = false,
  });

  @override
  State<BodyCompNotificationSheet> createState() => _BodyCompNotificationSheetState();
}

class _BodyCompNotificationSheetState extends State<BodyCompNotificationSheet> {
  late bool enabled;
  late List<BodyCompReminder> reminders;
  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  void initState() {
    super.initState();
    enabled = widget.initialEnabled;
    reminders = List.from(widget.initialReminders);
    // Ensure at least one schedule exists
    if (reminders.isEmpty) {
      reminders.add(BodyCompReminder(days: [], times: []));
    }
  }

  void _addNewSlot() {
    setState(() {
      reminders.add(BodyCompReminder(days: [], times: []));
    });
  }

  void _handleSave() {
    List<BodyCompReminder> finalReminders = [];
    bool anyDaySelected = false;

    for (var r in reminders) {
      if (r.days.isNotEmpty) {
        anyDaySelected = true;
        // If days are selected but no time, auto-add current time
        if (r.times.isEmpty) {
          finalReminders.add(r.copyWith(times: [TimeOfDay.now()]));
        } else {
          finalReminders.add(r);
        }
      } else {
        finalReminders.add(r);
      }
    }

    // A reminder can only be ON if at least one day is selected
    bool finalEnabled = enabled && anyDaySelected;

    widget.onSave(finalEnabled, finalReminders);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _handleSave();
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
                  constraints: widget.isSideSheet ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: widget.isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
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
                                "REMINDER SCHEDULE",
                                Icons.notifications_active_rounded,
                                enabled,
                                isCompact,
                                (val) {
                                  setState(() {
                                    enabled = val;
                                    if (val && reminders.isEmpty) {
                                      _addNewSlot();
                                    }
                                  });
                                },
                              ),
                              if (enabled) ...[
                                ...reminders.asMap().entries.map((e) => _buildReminderCard(e.value, e.key, isCompact)),
                                _buildAddButton("ADD TIME SLOT", _addNewSlot, isCompact),
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
          decoration: BoxDecoration(
            color: AppColors.crimson.withValues(alpha : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications_active_rounded, color: AppColors.crimson, size: isCompact ? 22.r : 20.0),
        ),
        SizedBox(width: isCompact ? 12.w : 12.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title.toUpperCase(), 
                style: AppTextStyles.h3.copyWith(fontSize: isCompact ? null : 18.0)
              ),
              Text(
                "SET TRACKING REMINDERS", 
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

  Widget _sectionHeader(String l, IconData i, bool v, bool isCompact, Function(bool) o) => Padding(
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

  Widget _buildReminderCard(BodyCompReminder reminder, int index, bool isCompact) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha : 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("SCHEDULE ${index + 1}", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.white, fontSize: isCompact ? null : 11.0)),
              if (reminders.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    reminders.removeAt(index);
                  }),
                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withValues(alpha : 0.7), size: isCompact ? 20.r : 18.0),
                ),
            ],
          ),
          SizedBox(height: isCompact ? 12.h : 10.0),
          _buildDayPicker(reminder, index, isCompact),
          SizedBox(height: isCompact ? 20.h : 16.0),
          _buildTimeChips(reminder, index, isCompact),
        ],
      ),
    );
  }

  Widget _buildDayPicker(BodyCompReminder reminder, int index, bool isCompact) {
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
            width: isCompact ? 36.r : 34.0,
            height: isCompact ? 36.r : 34.0,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.crimson : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
            ),
            alignment: Alignment.center,
            child: Text(
              weekDays[i],
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: isCompact ? 10.sp : 10.0,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChips(BodyCompReminder reminder, int index, bool isCompact) {
    final bool daysSelected = reminder.days.isNotEmpty;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: daysSelected ? 1.0 : 0.3,
      child: Wrap(
        spacing: isCompact ? 8.w : 8.0,
        runSpacing: isCompact ? 8.h : 8.0,
        children: [
          ...reminder.times.map(
            (t) => Chip(
              backgroundColor: AppColors.surface,
              label: Text(t.format(context), style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? null : 10.0)),
              deleteIcon: Icon(Icons.close, size: isCompact ? 14.r : 14.0, color: AppColors.crimson),
              onDeleted: daysSelected ? () => setState(() => reminder.times.remove(t)) : null,
            ),
          ),
          GestureDetector(
            onTap: daysSelected ? () => _selectTime(reminder) : null,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12.w : 12.0, 
                vertical: isCompact ? 8.h : 6.0
              ),
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha : 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: isCompact ? 14.r : 14.0, color: AppColors.crimson),
                  SizedBox(width: isCompact ? 4.w : 4.0),
                  Text("ADD TIME", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 10.0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BodyCompReminder reminder) async {
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

  Widget _buildAddButton(String l, VoidCallback o, bool isCompact) => GestureDetector(
        onTap: o,
        child: Container(
          margin: EdgeInsets.only(top: isCompact ? 12.h : 10.0),
          padding: EdgeInsets.symmetric(vertical: isCompact ? 14.h : 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
            border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
            color: AppColors.white.withValues(alpha : 0.02),
          ),
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

  Widget _buildHandle(bool isCompact) => Center(
        child: Container(
          margin: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
          width: isCompact ? 40.w : 40.0,
          height: isCompact ? 4.h : 4.0,
          decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha : 0.3), borderRadius: BorderRadius.circular(2.r)),
        ),
      );
}
