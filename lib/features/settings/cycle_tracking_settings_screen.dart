import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/core/widgets/elite_unit_toggle_card.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';

class CycleTrackingSettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const CycleTrackingSettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<CycleTrackingSettingsScreen> createState() => _CycleTrackingSettingsScreenState();
}

class _CycleTrackingSettingsScreenState extends State<CycleTrackingSettingsScreen> {
  late TextEditingController _intervalController;
  late bool _workoutReminders;
  late int _workoutDaysInterval;

  @override
  void initState() {
    super.initState();
    final settings = context.read<CycleProvider>().settings;
    _workoutReminders = settings.workoutRemindersEnabled;
    _workoutDaysInterval = settings.workoutReminderInterval;
    _intervalController = TextEditingController(text: _workoutDaysInterval.toString());
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;

                return Column(
                  children: [
                    EliteSettingsAppBar(
                      title: 'TRAINING SETTINGS', 
                      isCompact: isCompact,
                      showBackButton: !widget.isEmbedded,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 24.0 : 24.w
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: isLargeScreen ? 10.0 : 10.h
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                  _buildSectionHeader('WORKOUT REMINDERS', isLargeScreen),
                                  SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                  
                                  _buildNotificationCard(
                                    title: "Workout Schedule",
                                    subtitle: "Remind me to train every",
                                    value: _workoutReminders,
                                    isLargeScreen: isLargeScreen,
                                    onChanged: (val) {
                                      setState(() => _workoutReminders = val);
                                      provider.updateSettings(provider.settings.copyWith(
                                        workoutRemindersEnabled: val,
                                        workoutReminderInterval: _workoutDaysInterval,
                                      ));
                                    },
                                    child: _buildSmallTextField(
                                      controller: _intervalController,
                                      suffix: "Days",
                                      isLargeScreen: isLargeScreen,
                                      onChanged: (val) {
                                        final parsed = int.tryParse(val);
                                        if (parsed != null) {
                                          setState(() => _workoutDaysInterval = parsed);
                                          provider.updateSettings(provider.settings.copyWith(
                                            workoutRemindersEnabled: _workoutReminders,
                                            workoutReminderInterval: parsed,
                                          ));
                                        }
                                      },
                                    ),
                                  ),

                                  SizedBox(height: isLargeScreen ? 32.0 : 32.h),

                                  _buildSectionHeader('AUTOMATION & LOGGING', isLargeScreen),
                                  SizedBox(height: isLargeScreen ? 12.0 : 12.h),

                                  _buildSimpleToggleCard(
                                    title: "Smart Auto Date Log",
                                    subtitle: "Auto-log today's date on completion unless a workout was already logged today",
                                    value: provider.settings.smartAutoDateEnabled,
                                    isLargeScreen: isLargeScreen,
                                    onChanged: (val) {
                                      provider.updateSettings(provider.settings.copyWith(
                                        smartAutoDateEnabled: val,
                                      ));
                                    },
                                  ),

                                  SizedBox(height: isLargeScreen ? 32.0 : 32.h),

                                  _buildSectionHeader('DISPLAY UNITS', isLargeScreen),
                                  SizedBox(height: isLargeScreen ? 12.0 : 12.h),

                                  EliteUnitToggleCard(
                                    title: "Weight Unit",
                                    subtitle: "Switch between LBS and KGS",
                                    options: const ["LBS", "KGS"],
                                    selectedIndex: provider.settings.weightUnit == WeightUnit.lbs ? 0 : 1,
                                    onSelected: (index) {
                                      provider.updateSettings(provider.settings.copyWith(
                                        weightUnit: index == 0 ? WeightUnit.lbs : WeightUnit.kgs,
                                      ));
                                    },
                                  ),

                                  // ── NAVIGATION & SPACING FIX ──
                                  SizedBox(height: MediaQuery.of(context).padding.bottom + (isLargeScreen ? 100.0 : 100.h)),
                                ],
                              ),
                            ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isLargeScreen) {
    return Row(
      children: [
        Container(
          width: isLargeScreen ? 3.0 : 3.w,
          height: isLargeScreen ? 12.0 : 12.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(isLargeScreen ? 2.0 : 2.r),
          ),
        ),
        SizedBox(width: isLargeScreen ? 8.0 : 8.w),
        Text(
          title,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard({
    required String title, 
    required String subtitle, 
    required bool value, 
    required bool isLargeScreen,
    required Function(bool) onChanged,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.labelMedium.adaptive(context)),
              Switch.adaptive(
                value: value, 
                onChanged: onChanged,
                activeTrackColor: AppColors.crimson,
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 10.0 : 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subtitle, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.textSecondary,
              )),
              child,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required bool isLargeScreen,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMedium.adaptive(context)),
                SizedBox(height: isLargeScreen ? 4.0 : 4.h),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isLargeScreen ? 16.0 : 16.w),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.crimson,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTextField({
    required TextEditingController controller, 
    required String suffix, 
    required bool isLargeScreen,
    required Function(String) onChanged
  }) {
    return Container(
      width: isLargeScreen ? 100.0 : 100.w,
      padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 12.0 : 12.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(isLargeScreen ? 6.0 : 8.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: onChanged,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.white, 
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          SizedBox(width: isLargeScreen ? 4.0 : 4.w),
          Text(
            suffix,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary, 
            ),
          ),
        ],
      ),
    );
  }
}
