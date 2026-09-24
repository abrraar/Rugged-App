import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:rugged/features/tracker/body_composition/widgets/body_comp_notification_sheet.dart';
import 'package:rugged/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:rugged/features/tracker/body_composition/model/body_comp_settings.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/core/widgets/elite_unit_toggle_card.dart';

class BodyCompConfigScreen extends StatefulWidget {
  final bool isEmbedded;
  const BodyCompConfigScreen({super.key, this.isEmbedded = false});

  @override
  State<BodyCompConfigScreen> createState() => _BodyCompConfigScreenState();
}

class _BodyCompConfigScreenState extends State<BodyCompConfigScreen> {
  void _showReminderSheet(String type, BodyCompProvider provider) {
    String title = "";
    List<BodyCompReminder> initialReminders = [];
    bool initialEnabled = false;

    if (type == "weight") {
      title = "Weight";
      initialReminders = provider.settings.weightReminders;
      initialEnabled = provider.settings.weightRemindersEnabled;
    } else if (type == "fat") {
      title = "Body Fat";
      initialReminders = provider.settings.fatReminders;
      initialEnabled = provider.settings.fatRemindersEnabled;
    } else if (type == "muscle") {
      title = "Muscle Mass";
      initialReminders = provider.settings.muscleReminders;
      initialEnabled = provider.settings.muscleRemindersEnabled;
    }

    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => BodyCompNotificationSheet(
        isSideSheet: isSideSheet,
        title: title,
        initialReminders: initialReminders,
        initialEnabled: initialEnabled,
        onSave: (enabled, reminders) {
          BodyCompSettings updatedSettings = provider.settings;
          if (type == "weight") {
            updatedSettings = provider.settings.copyWith(
              weightRemindersEnabled: enabled,
              weightReminders: reminders,
            );
          } else if (type == "fat") {
            updatedSettings = provider.settings.copyWith(
              fatRemindersEnabled: enabled,
              fatReminders: reminders,
            );
          } else if (type == "muscle") {
            updatedSettings = provider.settings.copyWith(
              muscleRemindersEnabled: enabled,
              muscleReminders: reminders,
            );
          }
          
          provider.updateSettings(updatedSettings);

          if (enabled && !initialEnabled && mounted) {
            EliteSnackbar.show(context, "${title.toUpperCase()} REMINDER ACTIVATED");
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Consumer<BodyCompProvider>(
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
                      title: "BODY COMP SETTINGS", 
                      isCompact: isCompact,
                      showBackButton: !widget.isEmbedded,
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 24.0 : 24.w
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                                
                                _buildSectionHeader("MEASUREMENT UNITS", isLargeScreen),
                                EliteUnitToggleCard(
                                  title: "Body Comp Weight Unit",
                                  subtitle: "Switch between LBS and KGS",
                                  options: const ["LBS", "KGS"],
                                  selectedIndex: provider.settings.weightUnit == WeightUnit.kgs ? 1 : 0,
                                  onSelected: (index) {
                                    provider.updateSettings(provider.settings.copyWith(
                                      weightUnit: index == 1 ? WeightUnit.kgs : WeightUnit.lbs,
                                    ));
                                  },
                                ),
                                SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                EliteUnitToggleCard(
                                  title: "Height Unit",
                                  subtitle: "Switch between CM and FT/IN",
                                  options: const ["FT", "CM"],
                                  selectedIndex: provider.settings.heightUnit == HeightUnit.cm ? 1 : 0,
                                  onSelected: (index) {
                                    provider.updateSettings(provider.settings.copyWith(
                                      heightUnit: index == 1 ? HeightUnit.cm : HeightUnit.ftIn,
                                    ));
                                  },
                                ),

                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                _buildSectionHeader("TRACKING REMINDERS", isLargeScreen),
                                _buildReminderCard(
                                  title: "Weight Reminders",
                                  isEnabled: provider.settings.weightRemindersEnabled,
                                  onTap: () => _showReminderSheet("weight", provider),
                                  isLargeScreen: isLargeScreen,
                                ),
                                SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                _buildReminderCard(
                                  title: "Body Fat Reminders",
                                  isEnabled: provider.settings.fatRemindersEnabled,
                                  onTap: () => _showReminderSheet("fat", provider),
                                  isLargeScreen: isLargeScreen,
                                ),
                                SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                _buildReminderCard(
                                  title: "Muscle Mass Reminders",
                                  isEnabled: provider.settings.muscleRemindersEnabled,
                                  onTap: () => _showReminderSheet("muscle", provider),
                                  isLargeScreen: isLargeScreen,
                                ),
                                
                                SizedBox(height: isLargeScreen ? 40.0 : 40.h),
                              ],
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLargeScreen ? 12.0 : 12.h, 
        left: isLargeScreen ? 4.0 : 4.w
      ),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.crimson,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildReminderCard({required String title, required bool isEnabled, required VoidCallback onTap, required bool isLargeScreen}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 12.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: isEnabled ? AppColors.crimson : AppColors.white, size: isLargeScreen ? 22.0 : 22.r),
            SizedBox(width: isLargeScreen ? 16.0 : 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.white, 
                    fontWeight: FontWeight.w500,
                  )),
                  Text(
                    isEnabled ? "ACTIVE" : "DISABLED",
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: isEnabled ? AppColors.crimson : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: isLargeScreen ? 14.0 : 14.r),
          ],
        ),
      ),
    );
  }
}
