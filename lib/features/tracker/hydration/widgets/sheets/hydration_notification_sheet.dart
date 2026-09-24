// lib/features/tracker/hydration/widgets/sheets/hydration_notification_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import '../../provider/hydration_provider.dart';
import '../../model/hydration_reminder.dart';

class HydrationNotificationSheet extends StatefulWidget {
  final bool isSideSheet;
  const HydrationNotificationSheet({super.key, this.isSideSheet = false});

  @override
  State<HydrationNotificationSheet> createState() => _HydrationNotificationSheetState();
}

class _HydrationNotificationSheetState extends State<HydrationNotificationSheet> {
  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];
  
  late List<HydrationReminder> _localReminders;
  late bool _remindersEnabled;
  HydrationReminderMode _selectedMode = HydrationReminderMode.schedule;
  final List<TextEditingController> _intervalControllers = [];

  @override
  void initState() {
    super.initState();
    final settings = context.read<HydrationProvider>().settings;
    _remindersEnabled = settings.remindersEnabled;
    _localReminders = List.from(settings.reminders);
    
    if (_localReminders.isNotEmpty) {
      _selectedMode = _localReminders.first.mode;
    }

    for (var r in _localReminders) {
      _intervalControllers.add(TextEditingController(text: r.intervalValue?.toString() ?? "60"));
    }
  }

  @override
  void dispose() {
    for (var c in _intervalControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleSaveAndExit() {
    final provider = context.read<HydrationProvider>();
    final settings = provider.settings;

    List<HydrationReminder> validatedReminders = [];
    if (_remindersEnabled) {
      for (int i = 0; i < _localReminders.length; i++) {
        var r = _localReminders[i].copyWith(mode: _selectedMode);
        
        if (_selectedMode == HydrationReminderMode.schedule) {
          if (r.days.isNotEmpty) {
            // Rule: If days picked but no times, set current time
            if (r.times.isEmpty) {
              validatedReminders.add(r.copyWith(times: [TimeOfDay.now()]));
            } else {
              validatedReminders.add(r);
            }
          }
        } else {
          // Interval mode
          validatedReminders.add(r);
        }
      }
    }

    bool finalEnabled = _remindersEnabled;
    if (validatedReminders.isEmpty) {
      finalEnabled = false;
    }

    provider.updateSettings(settings.copyWith(
      reminders: validatedReminders,
      remindersEnabled: finalEnabled,
    ));
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
                  widget.isSideSheet ? 0 : (isCompact ? 8.h : 8.0), 
                  isCompact ? 24.w : 24.0, 
                  isCompact ? 40.h : 32.0
                ),
                child: Column(
                  mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isSideSheet) SizedBox(height: 24.0),
                    if (!widget.isSideSheet)
                      Center(
                        child: Container(
                          width: isCompact ? 40.w : 40.0, 
                          height: isCompact ? 4.h : 4.0,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(alpha: 0.3), 
                            borderRadius: BorderRadius.circular(2.r)
                          ),
                        ),
                      ),
                    if (!widget.isSideSheet) SizedBox(height: isCompact ? 24.h : 20.0),
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded, 
                          color: Colors.blueAccent, 
                          size: isCompact ? 24.r : 24.0
                        ),
                        SizedBox(width: isCompact ? 12.w : 12.0),
                        Expanded(
                          child: Text(
                            "HYDRATION REMINDERS", 
                            style: AppTextStyles.h3.copyWith(fontSize: isCompact ? null : 18.0)
                          ),
                        ),
                        if (widget.isSideSheet)
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 24.h : 20.0),
                    _buildMasterToggle(isCompact),
                    if (_remindersEnabled) ...[
                      SizedBox(height: isCompact ? 16.h : 12.0),
                      _buildModeSelectorMaster(isCompact),
                      SizedBox(height: isCompact ? 12.h : 10.0),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * (widget.isSideSheet ? 0.75 : 0.45)),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              ..._localReminders.asMap().entries.map((e) => _buildReminderCard(e.value, e.key, isCompact)),
                              _buildAddButton(isCompact),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMasterToggle(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      margin: EdgeInsets.only(bottom: isCompact ? 8.h : 6.0),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), border: Border.all(color: AppColors.white.withValues(alpha: 0.05))),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: AppColors.white, size: isCompact ? 22.r : 22.0),
          SizedBox(width: isCompact ? 16.w : 16.0),
          Expanded(child: Text("ENABLE REMINDERS", style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0))),
          Switch(
            value: _remindersEnabled, activeThumbColor: Colors.blueAccent, 
            onChanged: (val) {
              setState(() {
                _remindersEnabled = val;
                if (val && _localReminders.isEmpty) {
                  _localReminders.add(HydrationReminder(days: [], times: [], mode: _selectedMode));
                  _intervalControllers.add(TextEditingController(text: "60"));
                }
              });
            },
          ),
        ],
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
          _modeBtnMaster("FIXED SCHEDULE", HydrationReminderMode.schedule, isCompact),
          _modeBtnMaster("INTERVAL LOOP", HydrationReminderMode.interval, isCompact),
        ],
      ),
    );
  }

  Widget _modeBtnMaster(String l, HydrationReminderMode m, bool isCompact) {
    bool active = _selectedMode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = m),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 10.0),
          decoration: BoxDecoration(color: active ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0)),
          alignment: Alignment.center,
          child: Text(l, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: active ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildReminderCard(HydrationReminder reminder, int index, bool isCompact) {
    bool isSchedule = _selectedMode == HydrationReminderMode.schedule;
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 12.0),
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0), border: Border.all(color: AppColors.white.withValues(alpha: 0.05))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("SET CONFIG #${index + 1}", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, color: Colors.blueAccent, fontSize: isCompact ? null : 11.0)),
              if (_localReminders.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary, size: isCompact ? 20.r : 20.0),
                  onPressed: () => setState(() {
                    _localReminders.removeAt(index);
                    _intervalControllers[index].dispose();
                    _intervalControllers.removeAt(index);
                  }),
                ),
            ],
          ),
          SizedBox(height: isCompact ? 8.h : 8.0),
          if (isSchedule) ...[
            _buildDayPicker(reminder, index, isCompact),
            SizedBox(height: isCompact ? 16.h : 16.0),
            _buildTimeChips(reminder, index, isCompact),
          ] else ...[
            _buildIntervalPicker(reminder, index, isCompact),
          ],
        ],
      ),
    );
  }

  Widget _buildIntervalPicker(HydrationReminder reminder, int index, bool isCompact) {
    return Row(
      children: [
        Text("EVERY", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isCompact ? null : 11.0)),
        const Spacer(),
        _buildIntervalValueField(reminder, index, isCompact),
        SizedBox(width: isCompact ? 8.w : 8.0),
        _buildIntervalUnitSelector(reminder, index, isCompact),
      ],
    );
  }

  Widget _buildIntervalValueField(HydrationReminder reminder, int index, bool isCompact) {
    final controller = _intervalControllers[index];
    return Container(
      width: isCompact ? 60.w : 60.0, 
      height: isCompact ? 36.h : 36.0,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0)),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(top: 8)),
        onChanged: (val) {
            int newVal = int.tryParse(val) ?? 60;
            if (newVal < 1) newVal = 1;
            _localReminders[index] = reminder.copyWith(intervalValue: newVal);
        },
      ),
    );
  }

  Widget _buildIntervalUnitSelector(HydrationReminder reminder, int index, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.w : 8.0),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0)),
      child: DropdownButton<HydrationIntervalUnit>(
        value: reminder.intervalUnit ?? HydrationIntervalUnit.minute,
        underline: const SizedBox(),
        dropdownColor: AppColors.surface,
        items: [
          DropdownMenuItem(value: HydrationIntervalUnit.minute, child: Text("MINS", style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0))),
          DropdownMenuItem(value: HydrationIntervalUnit.hour, child: Text("HRS", style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0))),
        ],
        onChanged: (val) {
            setState(() => _localReminders[index] = reminder.copyWith(intervalUnit: val));
        },
      ),
    );
  }

  Widget _buildDayPicker(HydrationReminder reminder, int index, bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = reminder.days.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              final newDays = List<int>.from(reminder.days);
              isSelected ? newDays.remove(day) : newDays.add(day);
              
              if (newDays.isEmpty && _localReminders.length > 1) {
                 _localReminders.removeAt(index);
                 _intervalControllers[index].dispose();
                 _intervalControllers.removeAt(index);
              } else {
                 _localReminders[index] = reminder.copyWith(days: newDays);
              }
            });
          },
          child: Container(
            width: isCompact ? 32.r : 32.0, 
            height: isCompact ? 32.r : 32.0,
            decoration: BoxDecoration(color: isSelected ? Colors.blueAccent : AppColors.surface, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(weekDays[i], style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: isCompact ? 10.sp : 10.0)),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChips(HydrationReminder reminder, int index, bool isCompact) {
    return Wrap(
      spacing: isCompact ? 8.w : 8.0, 
      runSpacing: isCompact ? 8.h : 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...reminder.times.map((t) => Chip(
          backgroundColor: AppColors.surface,
          visualDensity: VisualDensity.compact,
          label: Text(t.format(context), style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0)),
          onDeleted: () => setState(() => _localReminders[index] = reminder.copyWith(times: List.from(reminder.times)..remove(t))),
          deleteIcon: Icon(Icons.close, size: isCompact ? 14.r : 14.0, color: Colors.blueAccent),
        )),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context, 
              useRootNavigator: true,
              initialTime: TimeOfDay.now(),
              builder: (context, child) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.blueAccent,
                          onPrimary: Colors.white,
                          surface: AppColors.surface,
                          onSurface: Colors.white,
                        ),
                        timePickerTheme: Theme.of(context).timePickerTheme.copyWith(
                          dayPeriodColor: WidgetStateColor.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.blueAccent;
                            }
                            return Colors.white.withValues(alpha: 0.05);
                          }),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                        ),
                      ),
                      child: child!,
                    ),
                  ),
                );
              },
            );
            if (picked != null) {
              setState(() => _localReminders[index] = reminder.copyWith(times: List.from(reminder.times)..add(picked)));
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12.w : 12.0, 
              vertical: isCompact ? 8.h : 8.0
            ),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Icon(Icons.access_time_rounded, size: isCompact ? 14.r : 14.0, color: Colors.blueAccent),
                SizedBox(width: isCompact ? 4.w : 4.0),
                Text("ADD TIME", style: AppTextStyles.labelSmall.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.w500, fontSize: isCompact ? 10.sp : 10.0)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(bool isCompact) {
    return GestureDetector(
      onTap: () => setState(() {
        _localReminders.add(HydrationReminder(days: [], times: [], mode: _selectedMode));
        _intervalControllers.add(TextEditingController(text: "60"));
      }),
      child: Container(
        margin: EdgeInsets.only(top: isCompact ? 12.h : 10.0),
        padding: EdgeInsets.symmetric(vertical: isCompact ? 14.h : 14.0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0), border: Border.all(color: AppColors.white.withValues(alpha: 0.05)), color: AppColors.white.withValues(alpha: 0.02)),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: isCompact ? 18.r : 18.0),
            SizedBox(width: isCompact ? 8.w : 8.0),
            Text("ADD NEW SLOT", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 11.0)),
        ]),
      ),
    );
  }
}
