import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_unit_toggle_card.dart';

import 'package:rugged/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:provider/provider.dart';

class SleepSettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const SleepSettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SleepSettingsScreen> createState() => _SleepSettingsScreenState();
}

class _SleepSettingsScreenState extends State<SleepSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Consumer<SleepProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;

                return Column(
                  children: [
                    EliteSettingsAppBar(
                      title: "SLEEP SETTINGS", 
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
                                
                                _buildSectionHeader("GLOBAL PREFERENCES", isLargeScreen),
                                
                                EliteUnitToggleCard(
                                  title: "Time Format",
                                  subtitle: "Switch between 12H and 24H clock",
                                  options: const ["12H", "24H"],
                                  selectedIndex: settings.use24HourClock ? 1 : 0,
                                  selectedColor: AppColors.crimson,
                                  onSelected: (v) {
                                    provider.updateSettings(settings.copyWith(
                                      use24HourClock: v == 1,
                                    ));
                                  },
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
}
