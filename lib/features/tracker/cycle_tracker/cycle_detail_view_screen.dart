import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/create_cycle_screen.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'model/workout.dart';

class CycleDetailViewScreen extends StatelessWidget {
  final String cycleId;
  final String cycleName;
  final bool isModifiable;

  const CycleDetailViewScreen({
    super.key,
    required this.cycleId,
    required this.cycleName,
    required this.isModifiable,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final cycle = provider.cycles.firstWhere((c) => c.id == cycleId);
        final cycleWorkouts = cycle.workouts;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 600;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? 24.h : 24.0, 
                      horizontal: isCompact ? 24.w : 24.0
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded, 
                              color: AppColors.white,
                              size: isCompact ? null : 20.0,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              cycleName.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.h2.adaptive(context).copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isModifiable)
                            IconButton(
                              icon: Icon(
                                Icons.edit_note_rounded, 
                                color: AppColors.white,
                                size: isCompact ? null : 24.0,
                              ),
                              onPressed: () async {
                                final cycle = provider.cycles.firstWhere((c) => c.id == cycleId);
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateCycleScreen(existingCycle: cycle),
                                  ),
                                );
                                if (result == true && context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              },
                            )
                          else
                            const Opacity(
                              opacity: 0,
                              child: IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded),
                                onPressed: null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Scrollable content area
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        vertical: isCompact ? 24.h : 24.0, 
                        horizontal: isCompact ? 24.w : 24.0
                      ),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (cycle.description.isNotEmpty) ...[
                          Text(
                            cycle.description.toUpperCase(),
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                              letterSpacing: 1,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isCompact ? 24.h : 24.0),
                        ],
                        _buildInfoTile(context, "STRUCTURE", "${cycleWorkouts.length} SESSIONS", isCompact),
                        SizedBox(height: isCompact ? 24.h : 24.0),
                        _buildSectionHeader(context, "WORKOUT ARCHITECTURE", isCompact),
                        SizedBox(height: isCompact ? 16.h : 16.0),
                        ...cycleWorkouts.map((workout) => _buildWorkoutSummaryCard(context, workout, provider, isCompact)),
                      ],
                    ),
                  ),

                  // Fixed Action Area at the bottom
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? 24.h : 24.0, 
                      horizontal: isCompact ? 24.w : 24.0
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!cycle.isDefault) ...[
                          _buildShareButton(context, provider, isCompact),
                          SizedBox(height: isCompact ? 16.h : 16.0),
                        ],
                        _buildActivateButton(context, provider, isCompact),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isCompact) {
    return Row(
      children: [
        Container(
          width: 2.5,
          height: 12.0,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(2.0),
          ),
        ),
        const SizedBox(width: 6.0),
        Text(
          title,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildShareButton(BuildContext context, CycleProvider provider, bool isCompact) {
    return Consumer<AuthProvider>(
      builder: (context, authProv, _) {
        final bool isPro = authProv.isPro;
        final Color themeColor = isPro ? Colors.blueAccent : AppColors.crimson;

        return GestureDetector(
          onTap: () async {
            if (!isPro) {
              context.push(AppRoutes.proUpgrade);
              return;
            }
            final userName = authProv.displayName;
            final link = await provider.generateShareableLink(cycleId, userName);
            
            if (link != null) {
              await Share.share(
                "CHECK OUT THIS HIT TRAINING CYCLE SHARED BY $userName IN RUGGED:\n\n$link",
                subject: "TRAINING CYCLE SHARED BY $userName",
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isCompact ? 18.h : 16.0),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              border: Border.all(color: themeColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isPro ? Icons.ios_share_rounded : Icons.lock_rounded, color: themeColor, size: isCompact ? 20.r : 20.0),
                SizedBox(width: isCompact ? 12.w : 12.0),
                Text(
                  isPro ? "SHARE CYCLE" : "GO PRO TO SHARE ROUTINE",
                  style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                    color: themeColor,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivateButton(BuildContext context, CycleProvider provider, bool isCompact) {
    return GestureDetector(
      onTap: () async {
        final active = provider.activeCycle;
        bool activated = false;

        if (active != null) {
          if (!active.isReadyToFinish) {
            // Warning for incomplete cycle
            final confirm = await EliteConfirmDialog.show(
              context,
              title: "INCOMPLETE CYCLE",
              message: "YOUR CURRENT CYCLE '${active.name.toUpperCase()}' IS NOT YET COMPLETE. ACTIVATING '${cycleName.toUpperCase()}' WILL MOVE THE INCOMPLETE PROTOCOL TO YOUR HISTORY. PROCEED?",
              confirmText: "PROCEED",
            );
            activated = confirm ?? false;
          }
else {
            // Confirmation for finished cycle
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0)),
                title: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
                      decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha : 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.bolt_rounded, color: Colors.greenAccent, size: isCompact ? 28.r : 28.0),
                    ),
                    SizedBox(height: isCompact ? 16.h : 16.0),
                    Text(
                      "ACTIVATE PROTOCOL", 
                      style: AppTextStyles.h3.adaptive(context).copyWith(
                        letterSpacing: 1.2
                      ), 
                      textAlign: TextAlign.center
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "DO YOU WANT TO INITIALIZE THE '${cycleName.toUpperCase()}' TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                        color: AppColors.textSecondary, 
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 12.w : 12.0, 
                      0, 
                      isCompact ? 12.w : 12.0, 
                      isCompact ? 16.h : 16.0
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                              decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), border: Border.all(color: AppColors.white.withValues(alpha : 0.1))),
                              alignment: Alignment.center,
                              child: Text("CANCEL", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 12.w : 12.0),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                              decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha : 0.1), borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), border: Border.all(color: Colors.greenAccent.withValues(alpha : 0.5))),
                              alignment: Alignment.center,
                              child: Text("ACTIVATE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: Colors.greenAccent, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            activated = confirm ?? false;
          }
        } else {
          // Confirmation for no active cycle
          final confirm = await EliteConfirmDialog.show(
            context,
            title: "ACTIVATE PROTOCOL",
            message: "DO YOU WANT TO INITIALIZE THE '${cycleName.toUpperCase()}' TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
            confirmText: "ACTIVATE",
            confirmColor: Colors.greenAccent,
            icon: Icons.bolt_rounded,
          );
          activated = confirm ?? false;
        }

        if (activated) {
          await provider.activateCycle(cycleId);
          if (context.mounted) Navigator.pop(context, true);
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: isCompact ? 18.h : 16.0),
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.crimson.withValues(alpha: 0.3), 
              blurRadius: 20, 
              offset: const Offset(0, 10)
            ),
          ],
        ),
        child: Center(
          child: Text(
            "ACTIVATE THIS CYCLE",
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: AppColors.white, 
              fontWeight: FontWeight.w500, 
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6), 
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary,
          )),
          Text(value, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.white, 
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummaryCard(BuildContext context, Workout workout, CycleProvider provider, bool isCompact) {
    final workoutExercises = workout.exercises;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 16.0),
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workout.name, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.white, 
            fontWeight: FontWeight.w500,
          )),
          SizedBox(height: isCompact ? 12.h : 12.0),
          const Divider(color: Colors.white10),
          SizedBox(height: isCompact ? 8.h : 8.0),
          ...workoutExercises.map((exercise) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: isCompact ? 4.h : 4.0),
              child: Row(
                children: [
                  Icon(Icons.circle, size: isCompact ? 6.r : 6.0, color: AppColors.crimson),
                  SizedBox(width: isCompact ? 12.w : 12.0),
                  Text(
                    exercise.name,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary, 
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

