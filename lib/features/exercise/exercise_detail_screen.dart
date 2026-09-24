import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/features/exercise/model/exercise_template.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/exercise_log.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';
import 'package:rugged/features/exercise/widgets/exercise_analytical_graph.dart';
import 'package:rugged/core/ads/locked_analytics_overlay.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/exercise/widgets/expandable_about_text.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String id;
  final String name;
  final String muscles;
  final String imagePath;
  final String about;
  final int intensity;
  final bool isEmbedded;
  final double? initialAspectRatio;

  const ExerciseDetailScreen({
    super.key,
    String? id,
    String? exerciseId,
    String? name,
    String? exerciseName,
    this.muscles = '',
    this.imagePath = '',
    this.about = '',
    this.intensity = 1,
    this.isEmbedded = false,
    this.initialAspectRatio,
  })  : id = id ?? exerciseId ?? '',
        name = name ?? exerciseName ?? '';

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final List<String> _allMuscles = [
    'Chest', 'Triceps', 'Back', 'Biceps', 'Legs', 'Calf', 'Abdominals', 'Shoulder'
  ];

  @override
  Widget build(BuildContext context) {
    final cycleProv = Provider.of<CycleProvider>(context);
    final exProvider = Provider.of<ExerciseProvider>(context);

    final template = exProvider.templates.firstWhere(
      (t) => t.id == widget.id || t.name.toUpperCase() == widget.name.toUpperCase(),
      orElse: () => ExerciseTemplate(
        id: widget.id,
        name: widget.name,
        targetMuscles: widget.muscles,
        aboutTheMovement: widget.about,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: !widget.isEmbedded,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double paneWidth = constraints.maxWidth;
            final double deviceWidth = MediaQuery.of(context).size.width;

            final bool isTabletOrFoldable = deviceWidth >= 600;

            final double hPad = isTabletOrFoldable
                ? (paneWidth - kMaxContentWidth).clamp(24.0, double.infinity) / 2
                : 20.w;

            final cleanNameForLogs = template.name.trim().toUpperCase();
            final relevantLogs = cycleProv.logs.where((log) {
              try {
                final exerciseDef = cycleProv.exercises.firstWhere((e) => e.id == log.exerciseId);
                if (exerciseDef.name.toUpperCase() != cleanNameForLogs) return false;
                final workout = cycleProv.getWorkoutForExercise(log.exerciseId);
                return workout != null && workout.completedAt != null;
              } catch (e) {
                return false;
              }
            }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

            return EliteRefreshIndicator(
              onRefresh: () async {
                await exProvider.forceRefresh();
              },
              color: AppColors.crimson,
              backgroundColor: AppColors.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildHeaderAppBar(context, template, exProvider, hPad, isTabletOrFoldable),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPad, 
                        vertical: isTabletOrFoldable ? 16.0 : 20.h
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildExerciseOverviewCard(context, template, isTabletOrFoldable),
                          SizedBox(height: isTabletOrFoldable ? 24.0 : 30.h),
                          _buildProgressGraphSection(context, relevantLogs, isTabletOrFoldable),
                          SizedBox(height: isTabletOrFoldable ? 24.0 : 30.h),
                          _buildHistoryLogs(context, relevantLogs, isTabletOrFoldable),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderAppBar(BuildContext context, ExerciseTemplate template, ExerciseProvider exProvider, double hPad, bool isTablet) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: widget.isEmbedded 
          ? null 
          : IconButton(
              icon: Container(
                padding: EdgeInsets.all(isTablet ? 8.0 : 8.r),
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: isTablet ? 16.0 : 18.r),
              ),
              onPressed: () => Navigator.pop(context),
            ),
      title: Text(
        template.name.toUpperCase(),
        style: AppTextStyles.h3.adaptive(context).copyWith(
          color: Colors.white,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: true,
      actions: [
        if (!template.isDefault) ...[
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer<AuthProvider>(
              builder: (context, authProv, _) {
                final bool isPro = authProv.isPro;
                return IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(isTablet ? 8.0 : 8.r),
                    decoration: BoxDecoration(
                      color: isPro ? AppColors.surface : AppColors.crimson.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: isPro ? null : Border.all(color: AppColors.crimson.withValues(alpha: 0.4)),
                    ),
                    child: Icon(
                      isPro ? Icons.ios_share_rounded : Icons.lock_rounded, 
                      color: isPro ? Colors.white : AppColors.crimson, 
                      size: isTablet ? 16.0 : 18.r
                    ),
                  ),
                  onPressed: () async {
                    if (!isPro) {
                      context.push(AppRoutes.proUpgrade);
                      return;
                    }
                    final userName = authProv.displayName;
                    final link = await exProvider.generateShareableLink(template, userName);
                    if (link != null) {
                      await Share.share(
                        "CHECK OUT THIS EXERCISE SHARED BY $userName IN RUGGED:\n\n$link",
                        subject: "EXERCISE SHARED BY $userName",
                      );
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: isTablet ? 16.0 : 12.w),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(isTablet ? 8.0 : 8.r),
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: Icon(Icons.edit_rounded, color: Colors.white, size: isTablet ? 16.0 : 18.r),
              ),
              onPressed: () => _showGlobalEditSheet(template, exProvider, isTablet),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExerciseOverviewCard(BuildContext context, ExerciseTemplate template, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT',
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isTablet ? 10.0 : 15.h),
        // Target Muscle & Type Badges
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 20.0 : 20.r),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: template.type == ExerciseType.compound 
                          ? AppColors.crimson.withValues(alpha: 0.2)
                          : AppColors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: template.type == ExerciseType.compound 
                            ? AppColors.crimson.withValues(alpha: 0.3)
                            : AppColors.white.withValues(alpha: 0.1)
                      ),
                    ),
                    child: Text(
                      template.type.name.toUpperCase(),
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: template.type == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'DEMAND: ',
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500
                        )
                      ),
                      _buildFireRating(template.intensity, isTablet),
                    ],
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 16.0 : 16.h),
              Text(
                'TARGET MUSCLES',
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                )
              ),
              SizedBox(height: 6.0),
              Text(
                (template.targetMuscles ?? "").toUpperCase(),
                style: AppTextStyles.h3.adaptive(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 16.0 : 20.h),
        // Execution & Form Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 20.0 : 20.r),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXECUTION & FORM GUIDE',
                style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                  color: AppColors.crimson,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                )
              ),
              SizedBox(height: 12.0),
              Opacity(
                opacity: (template.aboutTheMovement ?? "").isNotEmpty ? 1.0 : 0.4,
                child: ExpandableAboutText(
                  text: (template.aboutTheMovement ?? "").isNotEmpty 
                      ? template.aboutTheMovement!
                      : "NO COACHING NOTES HAVE BEEN ADDED FOR THIS EXERCISE. YOU CAN ADD THEM BY EDITING THE EXERCISE DETAILS.",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFireRating(int score, bool isTablet) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          Icons.local_fire_department_rounded,
          size: isTablet ? 14.0 : 14.r,
          color: index < score 
              ? AppColors.crimson 
              : AppColors.white.withValues(alpha: 0.1),
        );
      }),
    );
  }

  void _showGlobalEditSheet(ExerciseTemplate template, ExerciseProvider exProvider, bool isTablet) {
    final nameController = TextEditingController(text: template.name);
    final aboutController = TextEditingController(text: template.aboutTheMovement);
    final Set<String> selectedMuscles = (template.targetMuscles ?? "").split(', ').where((s) => s.isNotEmpty).toSet();

    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : 600.0;

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  ExerciseType calculatedType = selectedMuscles.length > 1 ? ExerciseType.compound : ExerciseType.isolation;
                  int calculatedIntensity = 1;
                  if (selectedMuscles.isEmpty) {
                    calculatedIntensity = 1;
                  } else if (selectedMuscles.length == 1) {
                    calculatedIntensity = 2;
                  } else if (selectedMuscles.length == 2) {
                    calculatedIntensity = 3;
                  } else if (selectedMuscles.length <= 4) {
                    calculatedIntensity = 4;
                  } else {
                    calculatedIntensity = 5;
                  }

                  bool isReady = selectedMuscles.isNotEmpty && nameController.text.trim().isNotEmpty;
                  String buttonText = nameController.text.isEmpty ? "ENTER EXERCISE NAME" : (selectedMuscles.isEmpty ? "SELECT TARGET MUSCLES" : "SAVE CHANGES");

                  return Container(
                    height: isSideSheet ? double.infinity : null,
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: isSideSheet 
                        ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                        : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    ),
                    child: Column(
                      mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        if (isSideSheet) SizedBox(height: 24.0),
                        if (!isSideSheet)
                          Padding(
                            padding: EdgeInsets.only(
                              top: isSheetCompact ? 12.h : 12.0, 
                              bottom: isSheetCompact ? 8.h : 8.0
                            ),
                            child: Center(
                              child: Container(
                                width: isSheetCompact ? 40.w : 40.0,
                                height: isSheetCompact ? 4.h : 4.0,
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withValues(alpha: 0.2), 
                                  borderRadius: BorderRadius.circular(2.r)
                                ),
                              ),
                            ),
                          ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              isSheetCompact ? 24.r : 24.0, 
                              0, 
                              isSheetCompact ? 24.r : 24.0, 
                              isSheetCompact ? 24.r : 24.0
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "EDIT EXERCISE", 
                                      style: AppTextStyles.h3.adaptive(context)
                                    ),
                                    if (isSideSheet)
                                      IconButton(
                                        icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                        onPressed: () => Navigator.pop(sheetContext),
                                      ),
                                  ],
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                _buildEditTextField(
                                  "EXERCISE NAME", 
                                  nameController, 
                                  "e.g. Hammer Curls",
                                  isCompact: isSheetCompact,
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                _buildEditTextField(
                                  "EXECUTION & FORM GUIDE", 
                                  aboutController, 
                                  "Describe the proper form...", 
                                  maxLines: 3,
                                  isCompact: isSheetCompact,
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                Text(
                                  "TARGET MUSCLES", 
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                    color: AppColors.textSecondary, 
                                    fontWeight: FontWeight.w500,
                                  )
                                ),
                                SizedBox(height: isSheetCompact ? 12.h : 10.0),
                                Wrap(
                                  spacing: isSheetCompact ? 8.w : 8.0,
                                  runSpacing: isSheetCompact ? 8.h : 8.0,
                                  children: _allMuscles.map((m) {
                                    bool isSelected = selectedMuscles.contains(m);
                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          if (isSelected) {
                                            selectedMuscles.remove(m);
                                          } else {
                                            selectedMuscles.add(m);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSheetCompact ? 12.w : 10.0, 
                                          vertical: isSheetCompact ? 6.h : 6.0
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(isSheetCompact ? 8.r : 8.0),
                                          border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05)),
                                        ),
                                        child: Text(
                                          m.toUpperCase(), 
                                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                            color: isSelected ? Colors.white : AppColors.textSecondary, 
                                            fontWeight: FontWeight.w500,
                                          )
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                Container(
                                  padding: EdgeInsets.all(isSheetCompact ? 16.r : 16.0),
                                  decoration: BoxDecoration(
                                    color: AppColors.background.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 12.0),
                                    border: Border.all(color: AppColors.white.withValues(alpha: 0.03)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "TYPE", 
                                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                              color: AppColors.textSecondary, 
                                              fontWeight: FontWeight.w500,
                                            )
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isSheetCompact ? 8.w : 8.0, 
                                              vertical: isSheetCompact ? 2.h : 2.0
                                            ),
                                            decoration: BoxDecoration(
                                              color: calculatedType == ExerciseType.compound ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(isSheetCompact ? 4.r : 4.0),
                                            ),
                                            child: Text(
                                              calculatedType.name.toUpperCase(),
                                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                                color: calculatedType == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: isSheetCompact ? 12.h : 10.0),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "DEMAND", 
                                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                              color: AppColors.textSecondary, 
                                              fontWeight: FontWeight.w500,
                                            )
                                          ),
                                          _buildFireRatingModalSheet(calculatedIntensity, isSheetCompact),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isSheetCompact ? 32.h : 24.0),
                                GestureDetector(
                                  onTap: isReady ? () async {
                                    final oldName = template.name;
                                    final newName = nameController.text.trim().toUpperCase();
                                    final newMuscles = selectedMuscles.join(', ');
                                    final updated = template.copyWith(
                                      name: newName,
                                      targetMuscles: newMuscles,
                                      type: calculatedType,
                                      intensity: calculatedIntensity,
                                      aboutTheMovement: aboutController.text.trim(),
                                    );
                                    Navigator.pop(sheetContext);
                                    if (oldName.trim().toUpperCase() != newName) {
                                      context.read<CycleProvider>().renameExerciseGlobally(oldName, newName);
                                    }
                                    await exProvider.addTemplate(updated);
                                  } : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: isSheetCompact ? 54.h : 48.0,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isReady ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 12.0),
                                      boxShadow: isReady ? [
                                        BoxShadow(color: AppColors.crimson.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                                      ] : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      buttonText,
                                      style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                                        color: isReady ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.5),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFireRatingModalSheet(int score, bool isCompact) {
    return Row(
      children: List.generate(5, (index) => Icon(
        Icons.local_fire_department_rounded,
        size: isCompact ? 16.r : 16.0,
        color: index < score ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05),
      )),
    );
  }

  Widget _buildEditTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary, 
            fontWeight: FontWeight.w500,
          )
        ),
        SizedBox(height: isCompact ? 8.h : 6.0),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTextStyles.bodyMedium.adaptive(context).copyWith(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2)),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 14.h : 12.0),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressGraphSection(BuildContext context, List<ExerciseLog> logs, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PROGRESS ANALYTICS', style: AppTextStyles.labelSmall.adaptive(context).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w500)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Text(
                "DATA TRENDS",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.crimson, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 10.0 : 15.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isTablet ? 12.0 : 24.h),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: logs.isEmpty 
            ? SizedBox(
                height: isTablet ? 120.0 : 200.h,
                child: Center(child: Text("NO PERFORMANCE DATA RECORDED YET", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)))),
              )
            : LockedAnalyticsOverlay(
                unlockKey: 'exercise_${widget.id}',
                height: isTablet ? 240.0 : 220.h,
                child: ExerciseAnalyticalGraph(
                  logs: logs.reversed.toList(),
                  onPointSelected: (idx) {},
                  isTablet: isTablet,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHistoryLogs(BuildContext context, List<ExerciseLog> logs, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT SESSIONS', style: AppTextStyles.labelSmall.adaptive(context).copyWith(letterSpacing: 1.5)),
        SizedBox(height: isTablet ? 10.0 : 15.h),
        if (logs.isEmpty)
           Padding(
             padding: EdgeInsets.symmetric(vertical: isTablet ? 12.0 : 20.h),
             child: Center(child: Text("NO RECENT SESSIONS FOUND", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3)))),
           )
        else
          ...logs.take(5).map((log) {
            String diffText = "";
            final index = logs.indexOf(log);
            if (index < logs.length - 1) {
              final prev = logs[index + 1];
              final wDiff = log.weightKg - prev.weightKg;
              final rDiff = log.positiveReps - prev.positiveReps;
              if (wDiff > 0) {
                diffText = "+${wDiff.toStringAsFixed(1)}KG LOAD INCREASE";
              } else if (rDiff > 0) {
                diffText = "+$rDiff REPS INCREASE";
              } else if (wDiff == 0 && rDiff == 0) {
                diffText = "MAINTAINED PERFORMANCE";
              } else {
                diffText = "PERFORMANCE DECREASE";
              }
            } else {
              diffText = "BASELINE SESSION";
            }
            return _buildLogEntry(context, log, diffText, isTablet);
          }),
      ],
    );
  }

  Widget _buildLogEntry(BuildContext context, ExerciseLog log, String note, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 8.0 : 12.h),
      padding: EdgeInsets.all(isTablet ? 12.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM dd').format(log.timestamp).toUpperCase(), style: AppTextStyles.labelMedium.adaptive(context)),
                  Text(note, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.crimson, fontWeight: FontWeight.w500)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${double.parse(log.weightKg.toStringAsFixed(3)).toString()} KG', style: AppTextStyles.h3.adaptive(context)),
                  Text('${log.positiveReps} POS REPS', style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          if (log.negativeReps > 0 || log.staticHoldSeconds > 0 || log.forcedReps > 0) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 8.0 : 12.h),
              child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (log.negativeReps > 0) _miniSpec(context, log.negativeReps.toString(), "NEG", Colors.tealAccent, isTablet),
                if (log.staticHoldSeconds > 0) _miniSpec(context, "${log.staticHoldSeconds}S", "STATIC", Colors.orangeAccent, isTablet),
                if (log.forcedReps > 0) _miniSpec(context, log.forcedReps.toString(), "FORCED", Colors.purpleAccent, isTablet),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _miniSpec(BuildContext context, String val, String label, Color color, bool isTablet) {
    return Column(
      children: [
        Text(val, style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: color, fontWeight: FontWeight.w500)),
        Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, fontSize: isTablet ? 10.0 : 10.sp)),
      ],
    );
  }
}
