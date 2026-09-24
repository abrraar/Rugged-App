import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/calorie/calorie_screen.dart';
import 'package:rugged/features/tracker/hydration/hydration_screen.dart';
import 'package:rugged/features/tracker/sleep/sleep_screen.dart';
import 'package:rugged/features/tracker/supplement/supplement_screen.dart';

import 'body_composition/body_composition_screen.dart';
import 'cycle_tracker/cycle_tracking_screen.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  // UPDATED: index range is now 0-5
  // 0: Cycle, 1: Body Comp, 2: Calorie, 3: Hydration, 4: Sleep, 5: Supplements
  int _activeIndex = -1;

  void _handleTap(int index, VoidCallback navigationCallback) {
    setState(() {
      _activeIndex = index;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      navigationCallback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < kMobileBreakpoint;
        
        final double hPad = !isCompact 
            ? (width - kMaxContentWidth).clamp(24.0, double.infinity) / 2 
            : 20.w;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT TRACKING MODULE',
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: isCompact ? 15.h : 12.0),

                    // 1. HIT Tracker
                    _buildHubCard(
                      index: 0,
                      title: 'HIT TRACKER',
                      subtitle: 'High Intensity Training Tracker',
                      icon: Icons.fitness_center_rounded,
                      isCompact: isCompact,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CycleTrackingScreen(),
                          ),
                        );
                      },
                    ),

                    // 2. Body Composition
                    _buildHubCard(
                      index: 1,
                      title: 'BODY COMPOSITION',
                      subtitle: 'Weight, Body Fat & Muscle Mass',
                      icon: Icons.accessibility_new_rounded,
                      isCompact: isCompact,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BodyCompositionScreen(),
                          ),
                        );
                      },
                    ),

                    // 3. Calorie Tracking
                    _buildHubCard(
                      index: 2,
                      title: 'CALORIE TRACKER',
                      subtitle: 'Daily Intake & Macros',
                      icon: Icons.local_fire_department_rounded,
                      isCompact: isCompact,
                      onTap: () => _handleTap(2, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CalorieScreen()),
                        );
                      }),
                    ),

                    // 4. Hydration
                    _buildHubCard(
                      index: 3,
                      title: 'HYDRATION',
                      subtitle: 'Daily Water Intake & Trends',
                      icon: Icons.water_drop_rounded,
                      isCompact: isCompact,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HydrationScreen(),
                          ),
                        );
                      },
                    ),

                    // 5. Sleep Tracking (NEW MODULE)
                    _buildHubCard(
                      index: 4,
                      title: 'SLEEP TRACKING',
                      subtitle: 'Monitor Rest & Recovery Quality',
                      icon: Icons.bedtime_rounded,
                      isCompact: isCompact,
                      onTap: () => _handleTap(4, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SleepScreen()),
                        );
                      }),
                    ),

                    // 6. Supplement Stack
                    _buildHubCard(
                      index: 5,
                      title: 'SUPPLEMENT STACK',
                      subtitle: 'Vitamins, Creatine & Performance',
                      icon: Icons.medication_liquid_rounded,
                      isCompact: isCompact,
                      onTap: () => _handleTap(5, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SupplementScreen(),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHubCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    bool isActive = _activeIndex == index;

    Color cardColor = isActive
        ? AppColors.crimson
        : AppColors.surfaceLight.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => _handleTap(index, onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: isCompact ? 15.h : 12.0),
        width: double.infinity,
        height: isCompact ? 110.h : 90.0,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: isCompact ? -15.w : -12.0,
              bottom: isCompact ? -15.h : -12.0,
              child: Icon(
                icon,
                size: isCompact ? 110.r : 90.0,
                color: AppColors.white.withValues(alpha: 0.03),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 20.0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.white, size: isCompact ? 28.r : 22.0),
                  ),
                  SizedBox(width: isCompact ? 15.w : 16.0),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.h3.adaptive(context).copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: isActive
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.white.withValues(alpha: 0.3),
                    size: isCompact ? 18 : 14.0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
