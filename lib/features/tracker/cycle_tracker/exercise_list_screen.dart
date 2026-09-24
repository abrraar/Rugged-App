import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/features/tracker/cycle_tracker/cycle_exercise_detail_screen.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:rugged/features/tracker/cycle_tracker/widgets/exercise_picker_sheet.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/core/ads/ad_service.dart';
import 'model/exercise.dart';
import 'model/workout.dart';

class ExerciseListScreen extends StatefulWidget {
  final String workoutId;
  final String workoutName;
  final Function(String id, String name)? onExerciseSelected;
  final VoidCallback? onBack;
  final bool isEmbedded;
  final String? selectedExerciseId;

  const ExerciseListScreen({
    super.key, 
    required this.workoutId, 
    required this.workoutName,
    this.onExerciseSelected,
    this.onBack,
    this.isEmbedded = false,
    this.selectedExerciseId,
  });

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  final TextEditingController _workoutNoteController = TextEditingController();
  Timer? _debounce;
  bool _isInitialLoad = true;
  bool? _wasCompletedOnEntry;
  final Set<String> _expandedExerciseIds = {}; // Track expanded exercise cards

  @override
  void initState() {
    super.initState();
    _workoutNoteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _workoutNoteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (_isInitialLoad) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), _autoSaveNote);
  }

  Future<void> _autoSaveNote() async {
    final provider = context.read<CycleProvider>();
    await provider.updateWorkoutNote(widget.workoutId, _workoutNoteController.text.trim());
    debugPrint("Auto-saved Workout Note");
  }

  void _onReorder(int oldIndex, int newIndex, List<Exercise> exercises) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = exercises.removeAt(oldIndex);
      exercises.insert(newIndex, item);
      context.read<CycleProvider>().updateExerciseOrder(widget.workoutId, exercises);
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
            ),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withValues(alpha : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "EXERCISE CONTROLS",
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _instructionRow(
                  Icons.drag_handle,
                  "Hold and drag cards to reorder your workout sequence.",
                  isCompact,
                ),
                SizedBox(height: isCompact ? 16.h : 12.0),
                _instructionRow(
                  Icons.swipe_down_rounded,
                  "Pull down to sync cloud data (Pro feature).",
                  isCompact,
                ),
                SizedBox(height: isCompact ? 16.h : 12.0),
                _instructionRow(
                  Icons.swipe_left_alt_rounded,
                  "Swipe left on any exercise to remove it.",
                  isCompact,
                ),
                SizedBox(height: isCompact ? 16.h : 12.0),
                _instructionRow(
                  Icons.bolt_rounded,
                  "Progression is tracked globally across all cycles.",
                  isCompact,
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha : 0.1),
                            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                            border: Border.all(color: AppColors.crimson.withValues(alpha : 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "DISMISS",
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.crimson,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _instructionRow(IconData icon, String text, bool isCompact) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 18.0),
        SizedBox(width: isCompact ? 12.w : 12.0),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _addNewExercise() {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => ExercisePickerSheet(
        isSideSheet: isSideSheet,
        onSelected: (name) async {
          final provider = context.read<CycleProvider>();
          final currentExercises = provider.exercises.where((e) => e.workoutId == widget.workoutId).toList();
          
          final newExercise = Exercise(
            workoutId: widget.workoutId,
            name: name,
            order: currentExercises.length,
          );
          
          await provider.addExercise(newExercise);
        },
      ),
    );
  }

  void _editWorkoutHeaderName(String currentName) {
    TextEditingController titleController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0)),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
                  decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha : 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.edit_rounded, color: AppColors.crimson, size: isCompact ? 28.r : 24.0),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text("RENAME WORKOUT", style: AppTextStyles.h3.adaptive(context).copyWith(letterSpacing: 1.2), textAlign: TextAlign.center),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: AppTextStyles.h3.adaptive(context).copyWith(color: AppColors.white),
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "ENTER WORKOUT NAME",
                    hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson, width: 2)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson, width: 2)),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                        onTap: () async {
                          if (titleController.text.isNotEmpty) {
                            await context.read<CycleProvider>().updateWorkoutName(widget.workoutId, titleController.text);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha : 0.1), borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), border: Border.all(color: AppColors.crimson.withValues(alpha : 0.5))),
                          alignment: Alignment.center,
                          child: Text("SAVE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.crimson, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final exercises = provider.exercises.where((e) => e.workoutId == widget.workoutId).toList();
        String currentWorkoutName = widget.workoutName;
        try {
          final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
          currentWorkoutName = workout.name;
          _wasCompletedOnEntry ??= workout.status == WorkoutStatus.completed;
          if (_isInitialLoad) {
            _workoutNoteController.text = workout.note ?? "";
            _isInitialLoad = false;
          }
        } catch (_) {}

        final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final bool isLargeScreen = MediaQuery.of(context).size.width >= 600;
        final bool isWideLandscape = isLargeScreen && isLandscape;

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              // ELITE AD TRIGGER: Show ad ONLY if workout was actively completed during this live session
              try {
                final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
                final isCompletedNow = workout.status == WorkoutStatus.completed;
                if (isCompletedNow && _wasCompletedOnEntry == false) {
                  debugPrint("ExerciseListScreen: Live Workout Freshly Completed. Triggering Custom Native Interstitial Ad on Pop.");
                  if (!context.mounted) return;
                  AdService().showCustomNativeInterstitial(context);
                } else {
                  debugPrint("ExerciseListScreen: Exiting workout review (Was already completed or incomplete). Skipping ad.");
                }
              } catch (_) {}

              // Ensure selection is cleared in provider when popping in portrait
              final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
              final bool isLargeScreen = MediaQuery.of(context).size.width >= 600;
              final bool isWideLandscape = isLargeScreen && isLandscape;

              if (!isWideLandscape && !widget.isEmbedded) {
                provider.setWorkoutSelection(null, null);
              }
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: null,
            floatingActionButton: SizedBox(
            height: isLargeScreen ? 44.0 : null,
            child: FloatingActionButton.extended(
              onPressed: _addNewExercise,
              backgroundColor: AppColors.crimson,
              icon: Icon(Icons.add, color: AppColors.white, size: isLargeScreen ? 20.0 : null),
              label: Text(
                "EXERCISE",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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
                  if (!context.mounted) return;
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                });
              }

              return Column(
                children: [
                  // Header
                  EliteSettingsAppBar(
                    title: currentWorkoutName,
                    isCompact: isCompact,
                    showBackButton: !widget.isEmbedded || widget.onBack != null,
                    onBackPressed: widget.onBack ?? ((isWideLandscape || widget.isEmbedded) ? null : () {
                      // Clear workout selection when navigating back in portrait
                      if (!isWideLandscape && !widget.isEmbedded) {
                        provider.setWorkoutSelection(null, null);
                      }
                      Navigator.pop(context);
                    }),
                  ),

                  // Content
                  Expanded(
                    child: EliteRefreshIndicator(
                      onRefresh: () => provider.forceRefresh(),
                      color: AppColors.crimson,
                      backgroundColor: AppColors.surface,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 24.w : (widget.isEmbedded ? 16.0 : 24.0)
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(provider, isCompact),

                            if (exercises.isEmpty)
                              _buildEmptyState(isCompact)
                            else
                              ReorderableListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: exercises.length,
                                onReorder: (oldIdx, newIdx) => _onReorder(oldIdx, newIdx, exercises),
                                proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
                                itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
                                  key: Key(exercises[index].id),
                                  index: index,
                                  child: _buildDismissibleExerciseCard(index, exercises[index], provider, isCompact),
                                ),
                              ),

                            _buildWorkoutCommentSection(isCompact),
                            SizedBox(height: isCompact ? 100.h : 100.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          ),
        ));
      },
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 20.0),
      padding: EdgeInsets.all(isCompact ? 32.r : 24.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha : 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
            decoration: BoxDecoration(
              color: AppColors.crimson.withValues(alpha : 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.reorder_rounded,
              color: AppColors.crimson.withValues(alpha : 0.6),
              size: isCompact ? 40.r : 36.0,
            ),
          ),
          SizedBox(height: isCompact ? 24.h : 20.0),
          Text(
            "NULL DATA",
            style: AppTextStyles.h3.adaptive(context).copyWith(
              color: AppColors.white,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: isCompact ? 12.h : 10.0),
          Text(
            "THIS WORKOUT HAS NO DEFINED EXERCISE SEQUENCES.",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          SizedBox(height: isCompact ? 16.h : 16.0),
          Container(
            height: 1,
            width: isCompact ? 40.w : 40.0,
            color: AppColors.crimson.withValues(alpha : 0.3),
          ),
          SizedBox(height: isCompact ? 16.h : 16.0),
          Text(
            "SELECT 'ADD EXERCISE' BELOW TO CONSTRUCT YOUR TARGETED HIT MOVEMENTS FOR THIS SESSION.",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha : 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCommentSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: AppColors.white.withValues(alpha : 0.1), height: isCompact ? 32.h : 32.0),
        _buildSectionHeader("WORKOUT OBSERVATIONS", isCompact),
        SizedBox(height: isCompact ? 12.h : 12.0),
        TextField(
          controller: _workoutNoteController,
          minLines: 3,
          maxLines: null,
          style: AppTextStyles.bodyMedium.adaptive(context).copyWith(
            color: AppColors.white,
          ),
          decoration: InputDecoration(
            hintText: "NOTES ON WORKOUT...",
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
        ),
        SizedBox(height: isCompact ? 8.h : 8.0),
        Center(
          child: Text(
            "AUTOSAVES AS YOU TYPE",
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha : 0.3),
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectWorkoutDate(BuildContext context, CycleProvider provider) async {
    final range = provider.getWorkoutDateRange(widget.workoutId);
    final firstDate = range['min'] ?? DateTime(2000, 1, 1);
    final lastDate = range['max'] ?? DateTime.now();

    // Check if the window is closed (e.g. neighbors are on consecutive days)
    if (firstDate.isAfter(lastDate)) {
      if (mounted) {
        EliteSnackbar.show(
          context,
          "NO AVAILABLE DATE: SURROUNDING WORKOUTS ARE TOO CLOSE IN TIME.",
          isError: true
        );
      }
      return;
    }

    // Find current workout date for initial selection
    DateTime initialDate = DateTime.now();
    try {
      final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
      if (workout.completedAt != null) {
        initialDate = workout.completedAt!;
      }
    } catch (_) {}

    // Ensure initial date is within bounds
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: "SELECT LOG DATE",
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.crimson,
                onPrimary: Colors.white,
                surface: AppColors.surface,
                onSurface: Colors.white,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: AppColors.crimson),
              ), dialogTheme: DialogThemeData(backgroundColor: AppColors.background),
            ),
            child: child!,
          ),
        ),
      ),
    );

    if (picked != null) {
      await provider.updateWorkoutDate(widget.workoutId, picked);
    }
  }

  void _removeWorkoutDate(CycleProvider provider) async {
    debugPrint("ExerciseListScreen: Attempting to remove date for ${widget.workoutId}");
    final confirm = await EliteConfirmDialog.show(
      context,
      title: "REMOVE DATE",
      message: "ARE YOU SURE YOU WANT TO REMOVE THE LOG DATE FOR THIS SESSION?",
      confirmText: "REMOVE",
    );

    debugPrint("ExerciseListScreen: Confirm result: $confirm");
    if (confirm == true) {
      await provider.updateWorkoutDate(widget.workoutId, null);
      debugPrint("ExerciseListScreen: updateWorkoutDate(null) called");
    }
  }

  Widget _buildHeader(CycleProvider provider, bool isCompact) {
    String currentWorkoutName = widget.workoutName;
    DateTime? completedAt;
    try {
      final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
      currentWorkoutName = workout.name;
      completedAt = workout.completedAt;
    } catch (_) {}

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionHeader("EXERCISE SEQUENCE", isCompact),
              const Spacer(),
              IconButton(
                onPressed: () => _editWorkoutHeaderName(currentWorkoutName),
                icon: Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                  size: isCompact ? 22.r : 20.0,
                ),
              ),
              IconButton(
                onPressed: _showInstructions,
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSecondary,
                  size: isCompact ? 24.r : 22.0,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8.h : 8.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Date Picker Button
              GestureDetector(
                onTap: () => _selectWorkoutDate(context, provider),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16.w : 16.0,
                    vertical: isCompact ? 10.h : 8.0
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(isCompact ? 10.r : 8.0),
                      right: completedAt == null ? Radius.circular(isCompact ? 10.r : 8.0) : Radius.zero,
                    ),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completedAt != null ? Icons.calendar_today_rounded : Icons.edit_calendar_rounded,
                        color: completedAt != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.5),
                        size: isCompact ? 16.r : 16.0,
                      ),
                      SizedBox(width: isCompact ? 10.w : 10.0),
                      Text(
                        completedAt != null
                            ? DateFormat('EEEE, MMM dd, yyyy').format(completedAt).toUpperCase()
                            : "ASSIGN DATE TO LOG",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: completedAt != null ? AppColors.white : AppColors.textSecondary.withValues(alpha: 0.5),
                          fontWeight: completedAt != null ? FontWeight.w500 : FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Separate Clear Date Button (only visible if date exists)
              if (completedAt != null)
                GestureDetector(
                  onTap: () => _removeWorkoutDate(provider),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12.w : 12.0,
                      vertical: isCompact ? 10.h : 8.0
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(isCompact ? 10.r : 8.0)),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isCompact ? 16.r : 16.0),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isCompact) {
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

  Widget _buildDismissibleExerciseCard(int index, Exercise exercise, CycleProvider provider, bool isCompact) {
    final bool isExpanded = _expandedExerciseIds.contains(exercise.id);
    String? currentCycleId;
    try {
      final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
      currentCycleId = workout.cycleId;
    } catch (_) {}

    final progression = provider.calculateExerciseProgression(exercise.name, targetCycleId: currentCycleId, exerciseId: exercise.id);
    final strength = progression['strength']!;
    final volume = progression['volume']!;
    final bool hasProgression = strength != 0 || volume != 0;

              final bool isSelected = !isCompact && widget.selectedExerciseId == exercise.id;

    return Dismissible(
      key: Key("${exercise.id}_dismiss"),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await EliteConfirmDialog.show(
          context,
          title: "REMOVE EXERCISE",
          message: "ARE YOU SURE YOU WANT TO REMOVE '${exercise.name}' FROM THIS WORKOUT?",
          confirmText: "REMOVE",
        );
      },
      onDismissed: (direction) {
        provider.deleteExercise(exercise.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isCompact ? 24.w : 24.0),
        margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: isCompact ? 28.r : 28.0),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.surfaceLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
          border: isSelected ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5), width: 1.5) : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha : 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    widget.onExerciseSelected?.call(exercise.id, exercise.name);
                    if (!widget.isEmbedded) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CycleExerciseDetailScreen(
                            exerciseId: exercise.id,
                            exerciseName: exercise.name,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Index, Title, Muscles, Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: isCompact ? 24.r : 24.0,
                                    height: isCompact ? 24.r : 24.0,
                                    margin: EdgeInsets.only(right: isCompact ? 12.w : 12.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.crimson, width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "${index + 1}",
                                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      exercise.name.toUpperCase(),
                                      style: AppTextStyles.h3.adaptive(context).copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (exercise.targetMuscles != null) ...[
                                SizedBox(height: isCompact ? 8.h : 8.0),
                                Text(
                                  exercise.targetMuscles!.toUpperCase(),
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                    color: isSelected ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary.withValues(alpha : 0.4),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                              _buildExerciseStatusBadge(exercise, provider, isCompact),
                            ],
                          ),
                        ),
                        // Right Column: Strength Data
                        if (hasProgression && strength != 0) ...[
                          SizedBox(width: isCompact ? 16.w : 16.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "STRENGTH",
                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                  color: isSelected ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary.withValues(alpha : 0.4),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                "${strength > 0 ? '+' : ''}${(strength * 100).toStringAsFixed(1)}%",
                                style: AppTextStyles.h2.adaptive(context).copyWith(
                                  color: strength > 0 ? AppColors.success : Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(width: isCompact ? 12.w : 12.0),
                        Icon(Icons.arrow_forward_ios, color: isSelected ? AppColors.white.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha : 0.3), size: isCompact ? 14.r : 14.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Expansion Logic for Volume
            if (hasProgression && volume != 0) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0),
                child: Divider(color: AppColors.white.withValues(alpha : 0.05), height: 1),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedExerciseIds.remove(exercise.id);
                  } else {
                    _expandedExerciseIds.add(exercise.id);
                  }
                }),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isExpanded ? "COLLAPSE DATA" : "SHOW PERFORMANCE DATA",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.textSecondary.withValues(alpha : 0.4),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: isCompact ? 8.w : 8.0),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary.withValues(alpha : 0.4),
                          size: isCompact ? 16.r : 16.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Container(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 24.w : 24.0,
                          0,
                          isCompact ? 24.w : 24.0,
                          isCompact ? 24.h : 20.0
                        ),
                        child: Container(
                          padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withValues(alpha : 0.3),
                            borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "VOLUME CHANGE",
                                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 8.h : 8.0),
                                  Text(
                                    "${volume * 100 > 0 ? '+' : ''}${(volume * 100).toStringAsFixed(1)}%",
                                    style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                                      color: volume > 0 ? AppColors.success : AppColors.crimson,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseStatusBadge(Exercise exercise, CycleProvider provider, bool isCompact) {
    final exLogs = provider.logs.where((l) {
      if (l.exerciseId != exercise.id) return false;
      final workout = provider.getWorkoutForExercise(l.exerciseId);
      return workout != null && workout.completedAt != null;
    }).toList();
    exLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    bool isCompleted = false;
    if (exLogs.isNotEmpty) {
      final l = exLogs.first;
      final hasBaseLoad = l.weightKg > 0 || l.weightLbs > 0;
      final hasIntensifier = l.positiveReps > 0 || l.staticHoldSeconds > 0 || l.negativeReps > 0 || l.forcedReps > 0;
      if (hasBaseLoad && hasIntensifier) {
        isCompleted = true;
      }
    }

    if (!isCompleted) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: isCompact ? 12.h : 12.0),
      child: IntrinsicWidth(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10.w : 10.0,
            vertical: isCompact ? 4.h : 4.0
          ),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha : 0.1),
            borderRadius: BorderRadius.circular(isCompact ? 4.r : 4.0),
            border: Border.all(color: AppColors.success.withValues(alpha : 0.3)),
          ),
          child: Text(
            "COMPLETED",
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

}
