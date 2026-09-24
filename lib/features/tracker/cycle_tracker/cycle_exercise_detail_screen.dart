import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:provider/provider.dart';
import 'model/exercise.dart';
import 'model/exercise_log.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';

class CycleExerciseDetailScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final bool isEmbedded;

  const CycleExerciseDetailScreen({
    super.key, 
    required this.exerciseId, 
    required this.exerciseName,
    this.isEmbedded = false,
  });

  @override
  State<CycleExerciseDetailScreen> createState() =>
      _CycleExerciseDetailScreenState();
}

class _CycleExerciseDetailScreenState extends State<CycleExerciseDetailScreen> {
  final Map<String, bool> _activeIntensifiers = {
    "POSITIVE REPS": false,
    "STATIC HOLD": false,
    "NEGATIVE REPS": false,
    "FORCED REPS": false,
  };

  final _weightController = TextEditingController();
  final _posRepsController = TextEditingController();
  final _staticSecsController = TextEditingController();
  final _negRepsController = TextEditingController();
  final _forcedRepsController = TextEditingController();
  final _commentController = TextEditingController();

  Timer? _debounce;
  ExerciseLog? _currentSessionLog;
  bool _isInitialLoad = true;
  WeightUnit? _lastUnit;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _weightController.addListener(_onFieldChanged);
    _posRepsController.addListener(_onFieldChanged);
    _staticSecsController.addListener(_onFieldChanged);
    _negRepsController.addListener(_onFieldChanged);
    _forcedRepsController.addListener(_onFieldChanged);
    _commentController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_isInitialLoad) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!mounted) return;
    final displayWeight = double.tryParse(_weightController.text) ?? 0;
    final posReps = int.tryParse(_posRepsController.text) ?? 0;
    final staticSecs = int.tryParse(_staticSecsController.text) ?? 0;
    final negReps = int.tryParse(_negRepsController.text) ?? 0;
    final forcedReps = int.tryParse(_forcedRepsController.text) ?? 0;

    final bool hasIntensifier = posReps > 0 || staticSecs > 0 || negReps > 0 || forcedReps > 0;
    final bool isSetValid = displayWeight > 0 && hasIntensifier;
    
    if (!isSetValid) {
      if (_currentSessionLog != null) {
        debugPrint("CycleExerciseDetailScreen: Set invalid, removing log...");
        final provider = context.read<CycleProvider>();
        await provider.deleteExerciseLog(_currentSessionLog!.id);
        _currentSessionLog = null;
      }
      return;
    }

    final provider = context.read<CycleProvider>();
    final dualWeights = provider.calculateDualWeights(displayWeight);
    
    final log = ExerciseLog(
      id: _currentSessionLog?.id, 
      exerciseId: widget.exerciseId,
      weightKg: dualWeights['kg']!,
      weightLbs: dualWeights['lbs']!,
      positiveReps: posReps,
      staticHoldSeconds: staticSecs,
      negativeReps: negReps,
      forcedReps: forcedReps,
      comment: _commentController.text.trim(),
      timestamp: _currentSessionLog?.timestamp ?? DateTime.now(),
    );

    _currentSessionLog = log;
    await provider.upsertExerciseLog(log);
    debugPrint("CycleExerciseDetailScreen: Log triggered for Supabase (Weight: $displayWeight)");
  }

  void _toggleIntensifier(String key) {
    setState(() {
      _activeIntensifiers[key] = !_activeIntensifiers[key]!;
    });
    _onFieldChanged();
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _autoSave(); // Final save attempt on exit
    }
    _weightController.dispose();
    _posRepsController.dispose();
    _staticSecsController.dispose();
    _negRepsController.dispose();
    _forcedRepsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final sessionLogs = provider.logs.where((l) {
          if (l.exerciseId != widget.exerciseId) return false;
          final workout = provider.getWorkoutForExercise(l.exerciseId);
          return workout != null && workout.completedAt != null;
        }).toList();

        final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final bool isLargeScreen = MediaQuery.of(context).size.width >= 600;
        final bool isWideLandscape = isLargeScreen && isLandscape;

        // --- REACTIVE UI REFRESH ON UNIT CHANGE ---
        if (_lastUnit != null && _lastUnit != provider.settings.weightUnit) {
          // Force re-load controllers from the raw database columns of the current log
          _isInitialLoad = true;
        }
        _lastUnit = provider.settings.weightUnit;
        
        // Discover all exercise instances of this name across cycles/workouts for logical history
        final List<Exercise> exerciseInstances = [];
        final sortedCycles = provider.cycles.where((c) => c.status != CycleStatus.template).toList()
          ..sort((a, b) {
            if (a.status == CycleStatus.finished && b.status == CycleStatus.finished) {
              return (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0));
            }
            if (a.status == CycleStatus.active) return 1;
            if (b.status == CycleStatus.active) return -1;
            return 0;
          });

        for (var cycle in sortedCycles) {
          final sortedWorkouts = List<Workout>.from(cycle.workouts)..sort((a, b) => a.order.compareTo(b.order));
          for (var workout in sortedWorkouts) {
            final sortedExercises = List<Exercise>.from(workout.exercises)..sort((a, b) => a.order.compareTo(b.order));
            for (var ex in sortedExercises) {
              if (ex.name.trim().toUpperCase() == widget.exerciseName.trim().toUpperCase()) {
                exerciseInstances.add(ex);
              }
            }
          }
        }

        bool isCycleFinished = false;
        try {
          final currentEx = provider.exercises.firstWhere((e) => e.id == widget.exerciseId);
          final currentWo = provider.workouts.firstWhere((w) => w.id == currentEx.workoutId);
          final currentCy = provider.cycles.firstWhere((c) => c.id == currentWo.cycleId);
          isCycleFinished = currentCy.status == CycleStatus.finished;
        } catch (e) {
          debugPrint("CycleExerciseDetailScreen: Error checking read-only: $e");
        }

        if (_isInitialLoad) {
          if (isCycleFinished) {
            if (sessionLogs.isNotEmpty) {
              _currentSessionLog = sessionLogs.first;
              final displayWeight = provider.getWeightForDisplay(_currentSessionLog!);
              _weightController.text = displayWeight > 0 ? double.parse(displayWeight.toStringAsFixed(3)).toString() : "";
              _posRepsController.text = _currentSessionLog!.positiveReps > 0 ? _currentSessionLog!.positiveReps.toString() : "";
              _staticSecsController.text = _currentSessionLog!.staticHoldSeconds > 0 ? _currentSessionLog!.staticHoldSeconds.toString() : "";
              _negRepsController.text = _currentSessionLog!.negativeReps > 0 ? _currentSessionLog!.negativeReps.toString() : "";
              _forcedRepsController.text = _currentSessionLog!.forcedReps > 0 ? _currentSessionLog!.forcedReps.toString() : "";
              _commentController.text = _currentSessionLog!.comment ?? "";

              _activeIntensifiers["POSITIVE REPS"] = _currentSessionLog!.positiveReps > 0;
              if (_currentSessionLog!.staticHoldSeconds > 0) _activeIntensifiers["STATIC HOLD"] = true;
              if (_currentSessionLog!.negativeReps > 0) _activeIntensifiers["NEGATIVE REPS"] = true;
              if (_currentSessionLog!.forcedReps > 0) _activeIntensifiers["FORCED REPS"] = true;
            }
          } else {
            // LOAD LATEST LOG FOR ACTIVE CYCLE (RESTORE PERSISTENCE)
            if (sessionLogs.isNotEmpty) {
              sessionLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              _currentSessionLog = sessionLogs.first;
              final displayWeight = provider.getWeightForDisplay(_currentSessionLog!);
              _weightController.text = displayWeight > 0 ? double.parse(displayWeight.toStringAsFixed(3)).toString() : "";
              _posRepsController.text = _currentSessionLog!.positiveReps > 0 ? _currentSessionLog!.positiveReps.toString() : "";
              _staticSecsController.text = _currentSessionLog!.staticHoldSeconds > 0 ? _currentSessionLog!.staticHoldSeconds.toString() : "";
              _negRepsController.text = _currentSessionLog!.negativeReps > 0 ? _currentSessionLog!.negativeReps.toString() : "";
              _forcedRepsController.text = _currentSessionLog!.forcedReps > 0 ? _currentSessionLog!.forcedReps.toString() : "";
              _commentController.text = _currentSessionLog!.comment ?? "";

              _activeIntensifiers["POSITIVE REPS"] = _currentSessionLog!.positiveReps > 0;
              if (_currentSessionLog!.staticHoldSeconds > 0) _activeIntensifiers["STATIC HOLD"] = true;
              if (_currentSessionLog!.negativeReps > 0) _activeIntensifiers["NEGATIVE REPS"] = true;
              if (_currentSessionLog!.forcedReps > 0) _activeIntensifiers["FORCED REPS"] = true;
            }
          }
          _isInitialLoad = false;
        }

        // Determine "Previous Record" by looking back in the logical hierarchy
        final myIdx = exerciseInstances.indexWhere((e) => e.id == widget.exerciseId);
        ExerciseLog? displayLastLog;
        if (myIdx > 0) {
          for (int i = myIdx - 1; i >= 0; i--) {
            final prevExId = exerciseInstances[i].id;
            final prevLogs = provider.logs.where((l) {
              if (l.exerciseId != prevExId) return false;
              final workout = provider.getWorkoutForExercise(l.exerciseId);
              return workout != null && workout.completedAt != null;
            }).toList();
            if (prevLogs.isNotEmpty) {
              prevLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              displayLastLog = prevLogs.first;
              break;
            }
          }
        }

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              // Ensure selection is cleared in provider when popping in portrait
              final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
              final bool isLargeScreen = MediaQuery.of(context).size.width >= 600;
              final bool isWideLandscape = isLargeScreen && isLandscape;

              if (!isWideLandscape && !widget.isEmbedded) {
                provider.setExerciseSelection(null, null);
              }
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: null,
            body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 600 && !isLandscape;

              // AUTO-POP ON ROTATION TO LANDSCAPE
              // If we are in full-screen mode on a large device and rotate to landscape,
              // pop this screen to reveal the split-view in WorkoutListScreen.
              // ONLY pop if we are the CURRENT top screen and taking up full width.
              final bool isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
              if (isCurrent && isWideLandscape && !widget.isEmbedded && constraints.maxWidth > 600) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                });
              }

              return Column(
                children: [
                  EliteSettingsAppBar(
                    title: widget.exerciseName,
                    isCompact: isCompact,
                    showBackButton: !widget.isEmbedded,
                    onBackPressed: (isWideLandscape || widget.isEmbedded) ? null : () {
                      // Clear exercise selection when navigating back in portrait
                      if (!isWideLandscape && !widget.isEmbedded) {
                        provider.setExerciseSelection(null, null);
                      }
                      Navigator.pop(context);
                    },
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 24.w : (widget.isEmbedded ? 16.0 : 24.0)
                      ),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isCompact ? 12.h : 12.0),
                          _buildPreviousRecordCard(displayLastLog, isCompact),
                          if (displayLastLog != null) _buildProgressionAnalysis(displayLastLog, isCompact),

                          SizedBox(height: isCompact ? 16.h : 16.0),
                          _buildSectionHeader(context, "BASE LOAD", isCompact),
                          _buildWeightInput(isCompact),

                          SizedBox(height: isCompact ? 32.h : 32.0),
                          _buildSectionHeader(context, "INTENSIFIER SELECTION", isCompact),
                          _buildIntensifierGrid(isCompact),

                          SizedBox(height: isCompact ? 32.h : 32.0),
                          _buildSectionHeader(context, "ACTIVE METRICS", isCompact),
                          _buildDynamicInputs(isCompact),

                          SizedBox(height: isCompact ? 32.h : 32.0),
                          _buildSectionHeader(context, "OBSERVATIONS & FEEDBACK", isCompact),
                          _buildCommentBox(isCompact),

                          _buildAutoSaveIndicator(isCompact),
                          SizedBox(height: isCompact ? 40.h : 40.0),
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

  // Removed _buildHistoryControls as it's no longer needed

  Widget _buildAutoSaveIndicator(bool isCompact) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isCompact ? 24.h : 24.0),
        child: Text(
          "DATA AUTOSAVES AS YOU TYPE",
          style: AppTextStyles.labelMedium.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousRecordCard(ExerciseLog? lastLog, bool isCompact) {
    final provider = context.read<CycleProvider>();
    if (lastLog == null) {
      return Container(
        padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.history, color: AppColors.crimson, size: isCompact ? 24.r : 24.0),
            SizedBox(width: isCompact ? 16.w : 16.0),
            Text(
              "NO RECORD AVAILABLE",
              style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                color: AppColors.white,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    List<String> metrics = [];
    if (lastLog.weightKg > 0 || lastLog.weightLbs > 0) {
      final displayWeight = provider.getWeightForDisplay(lastLog);
      final unit = provider.settings.weightUnit == WeightUnit.kgs ? "KGS" : "LBS";
      final String formattedWeight = double.parse(displayWeight.toStringAsFixed(3)).toString();
      metrics.add("$formattedWeight $unit");
    }

    if (lastLog.positiveReps > 0) metrics.add("${lastLog.positiveReps} POS");
    if (lastLog.staticHoldSeconds > 0) metrics.add("${lastLog.staticHoldSeconds}s STATIC");
    if (lastLog.negativeReps > 0) metrics.add("${lastLog.negativeReps} NEG");
    if (lastLog.forcedReps > 0) metrics.add("${lastLog.forcedReps} FORCED");

    final double volumeKg = lastLog.weightKg * lastLog.positiveReps;
    final double tonnage = volumeKg / 1000.0;

    return Container(
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: AppColors.crimson, size: isCompact ? 24.r : 24.0),
          SizedBox(width: isCompact ? 16.w : 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PREVIOUS RECORD",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isCompact ? 4.h : 4.0),
                if (metrics.isNotEmpty)
                  Text(
                    metrics.join(' • '),
                    style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (volumeKg > 0)
                  Padding(
                    padding: EdgeInsets.only(top: isCompact ? 8.h : 8.0),
                    child: Text(
                      "TOTAL TONNAGE: ${tonnage >= 1 ? tonnage.toStringAsFixed(2) : tonnage.toStringAsFixed(3)} T",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionAnalysis(ExerciseLog lastLog, bool isCompact) {
    final provider = context.read<CycleProvider>();
    double? currentWeight = double.tryParse(_weightController.text);
    int? currentReps = int.tryParse(_posRepsController.text);

    double strengthChange = 0.0;
    double volumeChange = 0.0;
    double loadDiff = 0.0;
    int repDiff = 0;
    bool hasAnalysis = false;

    if (currentWeight != null && currentWeight > 0 && currentReps != null && currentReps > 0 && (lastLog.weightKg > 0 || lastLog.weightLbs > 0) && lastLog.positiveReps > 0) {
      final dualWeights = provider.calculateDualWeights(currentWeight);
      final currentKg = dualWeights['kg']!;

      final double current1RM = currentKg / (1.0278 - (0.0278 * currentReps));
      final double last1RM = lastLog.weightKg / (1.0278 - (0.0278 * lastLog.positiveReps));
      strengthChange = ((current1RM / last1RM) - 1) * 100;

      final double currentVol = currentKg * currentReps;
      final double lastVol = lastLog.weightKg * lastLog.positiveReps;
      volumeChange = ((currentVol / lastVol) - 1) * 100;

      loadDiff = currentWeight - provider.getWeightForDisplay(lastLog);
      repDiff = currentReps - lastLog.positiveReps;

      hasAnalysis = true;
    }

    if (!hasAnalysis) {
      return Padding(
        padding: EdgeInsets.only(top: isCompact ? 24.h : 20.0),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.textSecondary.withValues(alpha: 0.3), size: isCompact ? 28.r : 28.0),
              SizedBox(width: isCompact ? 16.w : 16.0),
              Expanded(
                child: Text(
                  "ENTER BASE LOAD AND REPS TO ANALYZE PROGRESSION",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: isCompact ? 28.h : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, "HIT PROGRESSION ANALYSIS", isCompact),

          Row(
            children: [
              _buildAnalysisCard(
                label: "STRENGTH GAIN",
                value: strengthChange,
                isPercentage: true,
                color: strengthChange >= 0 ? AppColors.success : AppColors.crimson,
                icon: strengthChange >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                isCompact: isCompact,
              ),
              SizedBox(width: isCompact ? 16.w : 16.0),
              _buildAnalysisCard(
                label: "TONNAGE CHANGE",
                value: volumeChange,
                isPercentage: true,
                color: volumeChange >= 0 ? AppColors.success : AppColors.crimson,
                icon: volumeChange >= 0 ? Icons.stacked_line_chart_rounded : Icons.show_chart_rounded,
                isVolume: true,
                isCompact: isCompact,
              ),
            ],
          ),

          SizedBox(height: isCompact ? 16.h : 16.0),

          Container(
            padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _buildCompactMetric("LOAD DELTA", loadDiff, provider.settings.weightUnit == WeightUnit.kgs ? "KGS" : "LBS", isCompact),
                Container(
                  width: 1,
                  height: isCompact ? 32.h : 30.0,
                  color: AppColors.white.withValues(alpha: 0.1),
                  margin: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 16.0)
                ),
                _buildCompactMetric("REP DELTA", repDiff.toDouble(), "REPS", isCompact),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard({
    required String label,
    required double value,
    required bool isPercentage,
    required Color color,
    required IconData icon,
    bool isVolume = false,
    required bool isCompact,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, color: color, size: isCompact ? 16.r : 16.0),
              ],
            ),
            SizedBox(height: isCompact ? 12.h : 12.0),
            Text(
              "${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)}${isPercentage ? "%" : ""}",
              style: AppTextStyles.h2.adaptive(context).copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetric(String label, double value, String unit, bool isCompact) {
    // Use a small epsilon to handle floating point errors from conversion
    final bool isPositive = value > 0.01;
    final bool isNegative = value < -0.01;
    final Color color = isPositive
        ? AppColors.success
        : (isNegative ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.5));

    return Expanded(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: isCompact ? 4.h : 4.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "${isPositive ? "+" : ""}${value.abs() < 0.001 ? "0.0" : double.parse(value.abs().toStringAsFixed(3)).toString()}",
                    style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: isCompact ? 6.w : 6.0),
                  Text(
                    unit,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBox(bool isCompact) {
    return TextField(
      controller: _commentController,
      enabled: true,
      minLines: 3,
      maxLines: null,
      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
        color: AppColors.white,
      ),
      decoration: InputDecoration(
        hintText: "NOTES ON EXERCISE...",
        hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          borderSide: const BorderSide(color: AppColors.crimson),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 12.h : 12.0),
      child: Row(
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
      ),
    );
  }

  Widget _buildWeightInput(bool isCompact) {
    final provider = context.watch<CycleProvider>();
    final bool hasValue = _weightController.text.trim().isNotEmpty;

    return TextField(
      controller: _weightController,
      enabled: true,
      onChanged: (_) => setState(() {}),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
      ],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTextStyles.h1.adaptive(context).copyWith(
        color: AppColors.white,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.6),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16.w : 16.0,
          vertical: isCompact ? 12.h : 12.0,
        ),
        suffixText: provider.settings.weightUnit == WeightUnit.kgs ? "KGS" : "LBS",
        suffixStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(
          color: hasValue ? AppColors.crimson : AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          borderSide: BorderSide(color: hasValue ? AppColors.crimson : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          borderSide: BorderSide(color: hasValue ? AppColors.crimson : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildIntensifierGrid(bool isCompact) {
    return Wrap(
      spacing: isCompact ? 10.w : 10.0,
      runSpacing: isCompact ? 10.h : 10.0,
      children: _activeIntensifiers.keys.map((String key) {
        bool isActive = _activeIntensifiers[key]!;
        return GestureDetector(
          onTap: () => _toggleIntensifier(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16.w : 16.0,
              vertical: isCompact ? 12.h : 10.0
            ),
            decoration: BoxDecoration(
              color: isActive ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
              border: Border.all(color: isActive ? AppColors.crimson : AppColors.border),
            ),
            child: Text(key, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: isActive ? AppColors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDynamicInputs(bool isCompact) {
    final bool anyActive = _activeIntensifiers.values.any((v) => v);
    if (!anyActive) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
        child: Text(
          "NO METRICS SELECTED. TOGGLE INTENSIFIERS ABOVE TO TRACK DATA.",
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_activeIntensifiers["POSITIVE REPS"]!) _buildMetricField("POSITIVE REPS", _posRepsController, "REPS", isCompact),
        if (_activeIntensifiers["STATIC HOLD"]!) _buildMetricField("STATIC HOLD", _staticSecsController, "SECONDS", isCompact),
        if (_activeIntensifiers["NEGATIVE REPS"]!) _buildMetricField("NEGATIVE REPS", _negRepsController, "REPS", isCompact),
        if (_activeIntensifiers["FORCED REPS"]!) _buildMetricField("FORCED REPS", _forcedRepsController, "REPS", isCompact),
      ],
    );
  }

  Widget _buildMetricField(String label, TextEditingController controller, String unit, bool isCompact) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        bool hasValue = controller.text.isNotEmpty;
        return Padding(
          padding: EdgeInsets.only(bottom: isCompact ? 12.h : 12.0),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(label, style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                color: hasValue ? AppColors.white : AppColors.textSecondary,
              ))),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: true,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.h2.adaptive(context).copyWith(
                    color: hasValue ? AppColors.white : AppColors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                  decoration: InputDecoration(
                    hintText: "0",
                    hintStyle: AppTextStyles.h2.adaptive(context).copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                      fontWeight: FontWeight.w500,
                    ),
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(left: isCompact ? 8.w : 8.0),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(unit, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: hasValue ? AppColors.crimson : AppColors.white.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w500,
                        )),
                      ]),
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8.h : 8.0),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: hasValue ? AppColors.white.withValues(alpha: 0.5) : Colors.white10)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.white, width: 2)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
