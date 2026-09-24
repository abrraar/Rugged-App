// lib/features/profile/profile.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import '../main_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../tracker/body_composition/model/body_comp_log.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Register settings context for MainWrapper header
    WidgetsBinding.instance.addPostFrameCallback((_) {
      activeSettingsContext.value = "profile";
    });

    return Consumer3<AuthProvider, BodyCompProvider, CycleProvider>(
      builder: (context, authProv, bodyProv, cycleProv, _) {
        final lastWeightLog = bodyProv.logs.where((l) => l.type == BodyMetricType.weight).firstOrNull;
        final lastFatLog = bodyProv.logs.where((l) => l.type == BodyMetricType.fat).firstOrNull;
        final lastMuscleLog = bodyProv.logs.where((l) => l.type == BodyMetricType.muscle).firstOrNull;
        
        final height = authProv.height;
        final weight = lastWeightLog?.value;
        final bodyFat = lastFatLog?.value;
        final muscleMass = lastMuscleLog?.value;
        
        double bmi = 0;
        if (height != null && height > 0 && weight != null && weight > 0) {
          bmi = weight / ((height / 100) * (height / 100));
        }

        // Calculate BMR & TDEE
        int? age;
        if (authProv.birthday != null) {
          final now = DateTime.now();
          age = now.year - authProv.birthday!.year;
          if (now.month < authProv.birthday!.month || (now.month == authProv.birthday!.month && now.day < authProv.birthday!.day)) {
            age--;
          }
        }

        double? bmr;
        if (weight != null && height != null && age != null && authProv.gender != null) {
          final gender = authProv.gender!.toLowerCase();
          if (gender == 'male' || gender == 'man') {
            bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
          } else {
            bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
          }
        }

        double? tdee;
        if (bmr != null) {
          tdee = bmr * 1.2; // Default Activity Multiplier (Sedentary)
        }

        double? musclePercent;
        if (muscleMass != null && weight != null && weight > 0) {
          if (lastMuscleLog?.unit == BodyMetricUnit.percentage) {
            musclePercent = muscleMass;
          } else {
            // Calculate percentage from weight
            musclePercent = (muscleMass / weight) * 100;
          }
        }

        // Calculate Elite Records
        double heaviestWeightKg = 0;
        String heaviestExercise = "N/A";
        
        final Set<String> loggedExerciseNames = {};
        double bestGain = 0;
        String bestGainExercise = "N/A";

        // 1. Identify the absolute heaviest lift (Filter for existing exercises)
        for (var log in cycleProv.logs) {
          final name = cycleProv.getExerciseName(log.exerciseId);
          if (name == null) continue; // Skip logs for exercises that have been deleted

          if (log.weightKg > heaviestWeightKg) {
            heaviestWeightKg = log.weightKg;
            heaviestExercise = name;
          }
          
          loggedExerciseNames.add(name);
        }

        // 2. Identify the highest strength gain percentage across active exercises
        for (var exName in loggedExerciseNames) {
          final prog = cycleProv.calculateExerciseProgress(exName);
          if (prog > bestGain) {
            bestGain = prog;
            bestGainExercise = exName;
          }
        }

        // 3. Handle Unit Conversions for Display
        final bool isLbs = cycleProv.settings.weightUnit == WeightUnit.lbs;
        final double displayHeaviestWeight = isLbs ? (heaviestWeightKg * 2.205) : heaviestWeightKg;
        final String weightLabel = isLbs ? "LBS" : "KG";

        return EliteRefreshIndicator(
          onRefresh: () => authProv.forceRefreshProfile(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final bool isCompact = width < kMobileBreakpoint;

              final double hPad = !isCompact 
                  ? (width - kMaxContentWidth).clamp(24.0, double.infinity) / 2 
                  : 16.w;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10.h),
                child: Column(
                  children: [
                    // 1. Sleek Profile Info Card (Glassmorphism style)
                    _buildGlassCard(
                      context,
                      title: 'PROFILE INFORMATION',
                      icon: Icons.person_rounded,
                      isCompact: isCompact,
                      action: GestureDetector(
                        onTap: () => context.push(AppRoutes.editProfile),
                        child: Container(
                          padding: EdgeInsets.all(isCompact ? 8.r : 8.0),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit_rounded, color: AppColors.crimson, size: isCompact ? 18.r : 16.0),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInfoTile(context, 'Name', authProv.displayName, isCompact),
                          _buildInfoTile(context, 'Gender', authProv.gender?.toUpperCase() ?? "NOT SET", isCompact),
                          _buildInfoTile(
                            context,
                            'Birthday', 
                            authProv.birthday != null 
                              ? DateFormat('MMM dd, yyyy').format(authProv.birthday!).toUpperCase() 
                              : "NOT SET",
                            isCompact,
                          ),
                          _buildInfoTile(
                            context,
                            'Height', 
                            height != null ? "${height.toStringAsFixed(0)} cm" : "NOT SET",
                            isCompact,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 20.h : 16.0),

                    // 2. Body Metrics Grid
                  _buildGlassCard(
                    context,
                    title: 'METRICS & COMPOSITION', 
                    icon: Icons.analytics_outlined,
                    isCompact: isCompact,
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isCompact ? 2 : 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: isCompact ? 2.0 : 2.5,
                      children: [
                        _buildMetricBox(context, 'Height', height != null ? height.toStringAsFixed(0) : '--', 'cm', isCompact),
                        _buildMetricBox(context, 'Weight', weight != null && weight > 0 ? weight.toStringAsFixed(1) : '--', 'kg', isCompact),
                        _buildMetricBox(context, 'Body Fat', bodyFat != null && bodyFat > 0 ? bodyFat.toStringAsFixed(1) : '--', '%', isCompact),
                        _buildMetricBox(context, 'Muscle', musclePercent != null && musclePercent > 0 ? musclePercent.toStringAsFixed(1) : '--', '%', isCompact),
                        _buildMetricBox(context, 'BMI', bmi > 0 ? bmi.toStringAsFixed(1) : '--', 'pts', isCompact),
                        _buildMetricBox(context, 'BMR', bmr != null ? bmr.toStringAsFixed(0) : '--', 'kcal', isCompact),
                        _buildMetricBox(context, 'TDEE', tdee != null ? tdee.toStringAsFixed(0) : '--', 'kcal', isCompact),
                      ],
                    ),
                  ),
                    SizedBox(height: isCompact ? 20.h : 16.0),

                    // 3. Strength Records (Elite Tier List)
                    _buildGlassCard(
                      context,
                      title: 'ELITE RECORDS',
                      icon: Icons.emoji_events_rounded,
                      isCompact: isCompact,
                      child: Column(
                        children: [
                          _buildRecordTile(
                            context: context,
                            label: 'Heaviest Lift',
                            exercise: heaviestExercise.toUpperCase(),
                            value: heaviestWeightKg > 0 
                                ? '${displayHeaviestWeight.toStringAsFixed(1)} $weightLabel'
                                : 'NO RECORDS',
                            isHot: heaviestWeightKg > 0,
                            isCompact: isCompact,
                          ),
                          _buildRecordTile(
                            context: context,
                            label: 'Best Strength Gain',
                            exercise: bestGainExercise.toUpperCase(),
                            value: bestGain > 0 
                                ? '+${(bestGain * 100).toStringAsFixed(1)}%'
                                : 'N/A',
                            isHot: bestGain > 0,
                            isCompact: isCompact,
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 50.h),
                  ],
                ),
              );
            }
          ),
        );
      },
    );
  }

  // --- UI Components ---

  Widget _buildGlassCard(BuildContext context, {required String title, required IconData icon, required Widget child, Widget? action, required bool isCompact}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isCompact ? 20.w : 20.0, isCompact ? 20.h : 16.0, isCompact ? 20.w : 20.0, isCompact ? 10.h : 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 18.0),
                      SizedBox(width: 10.w),
                      Flexible(
                        child: Text(
                          title, 
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  SizedBox(width: 12.w),
                  action,
                ],
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(isCompact ? 16.r : 12.0), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, bool isCompact, {bool isLast = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 10.0),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: Colors.white38)),
          SizedBox(width: 16.w),
          Flexible(
            child: Text(
              value, 
              textAlign: TextAlign.end,
              style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(BuildContext context, String label, String value, String unit, bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: Colors.white38)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: value, style: AppTextStyles.h3.adaptive(context)),
                TextSpan(text: ' $unit', style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.crimson)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile({required BuildContext context, required String label, required String exercise, required String value, bool isHot = false, required bool isCompact}) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      padding: EdgeInsets.all(isCompact ? 16.r : 12.0),
      decoration: BoxDecoration(
        gradient: isHot 
          ? LinearGradient(colors: [AppColors.crimson.withValues(alpha: 0.2), Colors.transparent])
          : null,
        color: isHot ? null : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: isHot ? Border.all(color: AppColors.crimson.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: isHot ? AppColors.crimson : Colors.white38)),
                Text(exercise, style: AppTextStyles.labelMedium.adaptive(context)),
              ],
            ),
          ),
          Text(value, style: AppTextStyles.h3.adaptive(context).copyWith(color: isHot ? AppColors.crimson : Colors.white)),
        ],
      ),
    );
  }
}
