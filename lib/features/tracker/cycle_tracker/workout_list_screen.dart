import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/features/tracker/cycle_tracker/exercise_list_screen.dart';
import 'package:rugged/features/tracker/cycle_tracker/cycle_exercise_detail_screen.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';

class WorkoutListScreen extends StatefulWidget {
  final String cycleId;
  final String cycleName;

  const WorkoutListScreen({
    super.key,
    required this.cycleId,
    required this.cycleName,
  });

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  final TextEditingController _cycleNoteController = TextEditingController();
  final TextEditingController _templateNameController = TextEditingController();
  final TextEditingController _templateDescriptionController =
      TextEditingController();
  Timer? _debounce;
  bool _isInitialLoad = true;
  final Set<String> _expandedWorkoutIds = {};

  // Track orientation state for navigation recovery
  bool _wasWideLandscape = false;
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    // Clear any previous selection to ensure a fresh state for this cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CycleProvider>().clearSelection();
      }
    });
    _cycleNoteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cycleNoteController.dispose();
    _templateNameController.dispose();
    _templateDescriptionController.dispose();
    super.dispose();
  }

  void _showSaveTemplateDialog() {
    final provider = context.read<CycleProvider>();
    String currentDesc = "";
    try {
      final cycle = provider.cycles.firstWhere((c) => c.id == widget.cycleId);
      currentDesc = cycle.description;
    } catch (_) {}

    _templateNameController.text = widget.cycleName;
    _templateDescriptionController.text = currentDesc;

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
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.save_as_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "SAVE AS TEMPLATE",
                  style: AppTextStyles.h3
                      .adaptive(context)
                      .copyWith(letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "NAME",
                      style: AppTextStyles.labelSmall
                          .adaptive(context)
                          .copyWith(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                    ),
                    TextField(
                      controller: _templateNameController,
                      autofocus: true,
                      style: AppTextStyles.h3
                          .adaptive(context)
                          .copyWith(color: AppColors.white),
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "ENTER TEMPLATE NAME",
                        hintStyle: AppTextStyles.labelSmall
                            .adaptive(context)
                            .copyWith(color: AppColors.textSecondary),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.crimson,
                            width: 2,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.crimson,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 24.h : 20.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DESCRIPTION",
                      style: AppTextStyles.labelSmall
                          .adaptive(context)
                          .copyWith(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                    ),
                    TextField(
                      controller: _templateDescriptionController,
                      maxLines: 2,
                      style: AppTextStyles.labelSmall
                          .adaptive(context)
                          .copyWith(color: AppColors.white),
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      onChanged: (val) {
                        final lines = val.split('\n');
                        if (lines.length > 2) {
                          _templateDescriptionController.text = lines
                              .sublist(0, 2)
                              .join('\n');
                          _templateDescriptionController
                              .selection = TextSelection.fromPosition(
                            TextPosition(
                              offset:
                                  _templateDescriptionController.text.length,
                            ),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "ENTER DESCRIPTION (OPTIONAL)",
                        hintStyle: AppTextStyles.labelSmall
                            .adaptive(context)
                            .copyWith(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.crimson),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 12.w : 12.0,
                  0,
                  isCompact ? 12.w : 12.0,
                  isCompact ? 16.h : 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12.h : 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              isCompact ? 12.r : 10.0,
                            ),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "CANCEL",
                            style: AppTextStyles.labelSmall
                                .adaptive(context)
                                .copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          if (_templateNameController.text.trim().isNotEmpty) {
                            await context
                                .read<CycleProvider>()
                                .saveCycleAsTemplate(
                                  widget.cycleId,
                                  _templateNameController.text.trim(),
                                  _templateDescriptionController.text.trim(),
                                );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12.h : 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              isCompact ? 12.r : 10.0,
                            ),
                            border: Border.all(
                              color: AppColors.crimson.withValues(alpha: 0.5),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "SAVE",
                            style: AppTextStyles.labelSmall
                                .adaptive(context)
                                .copyWith(
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

  void _editCycleName(String currentName) {
    TextEditingController titleController = TextEditingController(
      text: currentName,
    );
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
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "RENAME CYCLE",
                  style: AppTextStyles.h3
                      .adaptive(context)
                      .copyWith(letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: AppTextStyles.h3
                      .adaptive(context)
                      .copyWith(color: AppColors.white),
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "ENTER CYCLE NAME",
                    hintStyle: AppTextStyles.labelSmall
                        .adaptive(context)
                        .copyWith(color: AppColors.textSecondary),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.crimson,
                        width: 2,
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.crimson,
                        width: 2,
                      ),
                    ),
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
                  isCompact ? 16.h : 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12.h : 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              isCompact ? 12.r : 10.0,
                            ),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "CANCEL",
                            style: AppTextStyles.labelSmall
                                .adaptive(context)
                                .copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          if (titleController.text.isNotEmpty) {
                            await context.read<CycleProvider>().updateCycleName(
                              widget.cycleId,
                              titleController.text,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12.h : 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              isCompact ? 12.r : 10.0,
                            ),
                            border: Border.all(
                              color: AppColors.crimson.withValues(alpha: 0.5),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "SAVE",
                            style: AppTextStyles.labelSmall
                                .adaptive(context)
                                .copyWith(
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

  void _onNoteChanged() {
    if (_isInitialLoad) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), _autoSaveNote);
  }

  Future<void> _autoSaveNote() async {
    final provider = context.read<CycleProvider>();
    await provider.updateCycleNote(
      widget.cycleId,
      _cycleNoteController.text.trim(),
    );
    debugPrint("Auto-saved Cycle Note");
  }

  void _onReorder(
    int oldIndex,
    int newIndex,
    List<Workout> pendingWorkouts,
    List<Workout> allWorkouts,
  ) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = pendingWorkouts.removeAt(oldIndex);
      pendingWorkouts.insert(newIndex, item);

      // Update full list
      final completedItems = allWorkouts
          .where((w) => w.status == WorkoutStatus.completed || w.completedAt != null)
          .toList();
      final updatedList = [...completedItems, ...pendingWorkouts];
      context.read<CycleProvider>().updateWorkoutOrder(
        widget.cycleId,
        updatedList,
      );
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
                    color: AppColors.crimson.withValues(alpha: 0.1),
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
                  "WORKOUT CONTROLS",
                  style: AppTextStyles.h3
                      .adaptive(context)
                      .copyWith(letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _instructionRow(
                  Icons.event_available_rounded,
                  "Workouts with assigned dates or completed status are locked in place.",
                  isCompact,
                ),
                SizedBox(height: isCompact ? 16.h : 12.0),
                _instructionRow(
                  Icons.drag_handle,
                  "Hold and drag undated pending workouts to reorder.",
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
                  "Swipe left on any workout to delete it.",
                  isCompact,
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 12.w : 12.0,
                  0,
                  isCompact ? 12.w : 12.0,
                  isCompact ? 16.h : 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12.h : 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              isCompact ? 12.r : 10.0,
                            ),
                            border: Border.all(
                              color: AppColors.crimson.withValues(alpha: 0.5),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "DISMISS",
                            style: AppTextStyles.labelSmall
                                .adaptive(context)
                                .copyWith(
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
            style: AppTextStyles.labelSmall
                .adaptive(context)
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  void _addNewWorkout() {
    TextEditingController titleController = TextEditingController();
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
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "NEW WORKOUT",
                  style: AppTextStyles.h3
                      .adaptive(context)
                      .copyWith(letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: AppTextStyles.h3
                      .adaptive(context)
                      .copyWith(color: AppColors.white),
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "ENTER WORKOUT TITLE",
                    hintStyle: AppTextStyles.labelSmall
                        .adaptive(context)
                        .copyWith(color: AppColors.textSecondary),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.crimson,
                        width: 2,
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.crimson,
                        width: 2,
                      ),
                    ),
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
                  isCompact ? 16.h : 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12.h : 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              isCompact ? 12.r : 10.0,
                            ),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "CANCEL",
                            style: AppTextStyles.labelSmall
                                .adaptive(context)
                                .copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (context, setBtnState) {
                          bool isSubmitting = false;
                          return GestureDetector(
                            onTap: () {
                              if (isSubmitting) return;
                              if (titleController.text.trim().isNotEmpty) {
                                isSubmitting = true;
                                final workoutName = titleController.text
                                    .trim()
                                    .toUpperCase();

                                // 1. Immediately pop dialog so prompt disappears INSTANTLY (0ms)
                                Navigator.pop(context);

                                // 2. Add workout (optimistic memory update + background persistence)
                                final provider = context.read<CycleProvider>();
                                final allWorkouts = provider.workouts
                                    .where((w) => w.cycleId == widget.cycleId)
                                    .toList();

                                final newWorkout = Workout(
                                  cycleId: widget.cycleId,
                                  name: workoutName,
                                  order: allWorkouts.length,
                                );

                                provider.addWorkout(newWorkout);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: isCompact ? 12.h : 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.crimson.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 12.r : 10.0,
                                ),
                                border: Border.all(
                                  color: AppColors.crimson.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "CREATE",
                                style: AppTextStyles.labelSmall
                                    .adaptive(context)
                                    .copyWith(
                                      color: AppColors.crimson,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          );
                        },
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

  Widget _buildMasterWorkoutList(
    CycleProvider provider,
    List<Workout> allWorkoutsFlat,
    List<Workout> completedWorkouts,
    List<Workout> pendingWorkouts,
    bool isCompact,
    bool isWideLandscape,
    CycleStatus currentCycleStatus,
    List<Workout> nestedWorkouts,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            provider,
            isCompact,
            isWideLandscape: isWideLandscape,
            currentCycleStatus: currentCycleStatus,
          ),

          if (allWorkoutsFlat.isEmpty)
            _buildEmptyState(isCompact)
          else ...[
            // Completed
            ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completedWorkouts.length,
              itemBuilder: (context, index) => _buildDismissibleWorkoutCard(
                index,
                completedWorkouts[index],
                provider,
                isCompact,
                isWideLandscape: isWideLandscape,
                isSelected:
                    isWideLandscape &&
                    !isCompact &&
                    provider.selectedWorkoutId == completedWorkouts[index].id,
                onSelected: () => provider.setWorkoutSelection(
                  completedWorkouts[index].id,
                  completedWorkouts[index].name,
                ),
              ),
            ),

            // Pending
            ReorderableListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingWorkouts.length,
              onReorder: (oldIdx, newIdx) =>
                  _onReorder(oldIdx, newIdx, pendingWorkouts, allWorkoutsFlat),
              proxyDecorator: (child, index, animation) =>
                  Material(color: Colors.transparent, child: child),
              itemBuilder: (context, index) =>
                  ReorderableDelayedDragStartListener(
                    key: Key(pendingWorkouts[index].id),
                    index: index,
                    child: _buildDismissibleWorkoutCard(
                      completedWorkouts.length + index,
                      pendingWorkouts[index],
                      provider,
                      isCompact,
                      isWideLandscape: isWideLandscape,
                      isSelected:
                          isWideLandscape &&
                          !isCompact &&
                          provider.selectedWorkoutId ==
                              pendingWorkouts[index].id,
                      onSelected: () => provider.setWorkoutSelection(
                        pendingWorkouts[index].id,
                        pendingWorkouts[index].name,
                      ),
                    ),
                  ),
            ),
          ],

          _buildBottomCommentSection(isCompact),
          SizedBox(height: isCompact ? 32.h : 32.0),
          _buildTemplateAction(provider, isCompact),
          _buildShareAction(provider, isCompact),
          if (currentCycleStatus == CycleStatus.active)
            Padding(
              padding: EdgeInsets.only(top: isCompact ? 16.h : 16.0),
              child: _buildFinishCycleButton(
                nestedWorkouts,
                provider,
                isCompact,
              ),
            ),
          SizedBox(height: isCompact ? 100.h : 100.0),
        ],
      ),
    );
  }

  Widget _buildDetailPane(CycleProvider provider, bool isCompact) {
    // Stage 3: Exercise Detail on Right, Exercise List on Left
    if (provider.selectedExerciseId != null) {
      return CycleExerciseDetailScreen(
        key: Key("detail_${provider.selectedExerciseId}"),
        exerciseId: provider.selectedExerciseId!,
        exerciseName: provider.selectedExerciseName!,
        isEmbedded: true,
      );
    }

    // Stage 2: Exercise List on Right, Workout List on Left
    if (provider.selectedWorkoutId != null) {
      return ExerciseListScreen(
        key: Key("list_${provider.selectedWorkoutId}"),
        workoutId: provider.selectedWorkoutId!,
        workoutName: provider.selectedWorkoutName!,
        isEmbedded: true,
        onExerciseSelected: (id, name) =>
            provider.setExerciseSelection(id, name),
      );
    }

    // Stage 1: Placeholder
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          "SELECT A WORKOUT TO VIEW EXERCISES",
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall
              .adaptive(context)
              .copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                letterSpacing: 2,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final allWorkoutsFlat = provider.workouts
            .where((w) => w.cycleId == widget.cycleId)
            .toList();
        final completedWorkouts = allWorkoutsFlat
            .where((w) => w.status == WorkoutStatus.completed || w.completedAt != null)
            .toList();
        final pendingWorkouts = allWorkoutsFlat
            .where((w) => w.status != WorkoutStatus.completed && w.completedAt == null)
            .toList();

        final bool isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final bool isLargeScreen = MediaQuery.of(context).size.width >= 600;
        final bool isCompact = MediaQuery.of(context).size.width < 600;
        final bool isWideLandscape = isLargeScreen && isLandscape;

        CycleStatus currentCycleStatus = CycleStatus.template;
        List<Workout> nestedWorkouts = [];
        String currentCycleName = widget.cycleName;
        try {
          final cycle = provider.cycles.firstWhere(
            (c) => c.id == widget.cycleId,
          );
          currentCycleStatus = cycle.status;
          nestedWorkouts = cycle.workouts;
          currentCycleName = cycle.name;

          if (_isInitialLoad) {
            _cycleNoteController.text = cycle.note ?? "";
            _isInitialLoad = false;
          }
        } catch (_) {}

        // Adaptive FAB styling
        final bool isTabletOrWide = isLargeScreen && !isCompact;

        final bool hasFab =
            currentCycleStatus != CycleStatus.template &&
            provider.selectedExerciseId == null;

        final Widget workoutFab = hasFab
            ? SizedBox(
                height: isTabletOrWide ? 44.0 : null,
                child: FloatingActionButton.extended(
                  heroTag: "workout_fab",
                  onPressed: _addNewWorkout,
                  backgroundColor: AppColors.crimson,
                  icon: Icon(
                    Icons.add,
                    color: AppColors.white,
                    size: isTabletOrWide ? 20.0 : null,
                  ),
                  label: Text(
                    "WORKOUT",
                    style: AppTextStyles.labelSmall
                        .adaptive(context)
                        .copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              )
            : const SizedBox.shrink();

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              provider.clearSelection();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: null,
            floatingActionButton: isWideLandscape
                ? null
                : (hasFab ? workoutFab : null),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600;
                final bool isCurrent =
                    ModalRoute.of(context)?.isCurrent ?? false;

                if (_isFirstBuild) {
                  _wasWideLandscape = isWideLandscape;
                  _isFirstBuild = false;
                }

                // 1. ADAPTIVE PUSH (Orientation Recovery: Landscape -> Portrait)
                if (!isWideLandscape && _wasWideLandscape) {
                  if (provider.selectedWorkoutId != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || !isCurrent) return;

                      final String woId = provider.selectedWorkoutId!;
                      final String woName = provider.selectedWorkoutName!;
                      final String? exId = provider.selectedExerciseId;
                      final String? exName = provider.selectedExerciseName;

                      // Hand-off the navigation to the Navigator
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, anim1, anim2) =>
                              ExerciseListScreen(
                                workoutId: woId,
                                workoutName: woName,
                                selectedExerciseId: exId,
                                onExerciseSelected: (id, name) =>
                                    provider.setExerciseSelection(id, name),
                              ),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );

                      if (exId != null) {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, anim1, anim2) =>
                                CycleExerciseDetailScreen(
                                  exerciseId: exId,
                                  exerciseName: exName!,
                                ),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      }
                      // Selection is preserved in provider so rotation back to landscape works
                    });
                  }
                }

                // 2. AUTO-CLEANUP (Stale Selection Management in Portrait)
                // We remove the auto-cleanup here because selection is now a persistent source of truth.
                // Instead, we will handle clearing selection when the user pops screens in Portrait.

                // Update tracker for next build
                _wasWideLandscape = isWideLandscape;

                return Column(
                  children: [
                    // Content
                    Expanded(
                      child: isWideLandscape
                          ? Row(
                              children: [
                                // Master Pane (Left) - Takes Entire "Screen" Look
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: AppColors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: provider.selectedExerciseId != null
                                        ? ExerciseListScreen(
                                            key: Key(
                                              "master_list_${provider.selectedWorkoutId}",
                                            ),
                                            workoutId:
                                                provider.selectedWorkoutId!,
                                            workoutName:
                                                provider.selectedWorkoutName!,
                                            isEmbedded: true,
                                            // Mark as embedded to prevent auto-pop
                                            selectedExerciseId:
                                                provider.selectedExerciseId,
                                            onBack: () =>
                                                provider.setExerciseSelection(
                                                  null,
                                                  null,
                                                ),
                                            onExerciseSelected: (id, name) =>
                                                provider.setExerciseSelection(
                                                  id,
                                                  name,
                                                ),
                                          )
                                        : Scaffold(
                                            backgroundColor: Colors.transparent,
                                            floatingActionButton: workoutFab,
                                            body: Column(
                                              children: [
                                                // Top-level Header for Cycle (on the left screen)
                                                EliteSettingsAppBar(
                                                  title: currentCycleName,
                                                  isCompact: false,
                                                  showBackButton: true,
                                                ),
                                                Expanded(
                                                  child:
                                                      _buildMasterWorkoutList(
                                                        provider,
                                                        allWorkoutsFlat,
                                                        completedWorkouts,
                                                        pendingWorkouts,
                                                        false,
                                                        // isCompact
                                                        isWideLandscape,
                                                        currentCycleStatus,
                                                        nestedWorkouts,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),

                                // Detail Pane (Right) - Takes Entire "Screen" Look
                                Expanded(
                                  child: Container(
                                    color: AppColors.background,
                                    child: provider.selectedExerciseId != null
                                        ? CycleExerciseDetailScreen(
                                            key: Key(
                                              "detail_${provider.selectedExerciseId}",
                                            ),
                                            exerciseId:
                                                provider.selectedExerciseId!,
                                            exerciseName:
                                                provider.selectedExerciseName!,
                                            isEmbedded:
                                                true, // Hide back button in detail pane
                                          )
                                        : provider.selectedWorkoutId != null
                                        ? ExerciseListScreen(
                                            key: Key(
                                              "list_${provider.selectedWorkoutId}",
                                            ),
                                            workoutId:
                                                provider.selectedWorkoutId!,
                                            workoutName:
                                                provider.selectedWorkoutName!,
                                            isEmbedded: true,
                                            // Hide back button in detail pane
                                            selectedExerciseId:
                                                provider.selectedExerciseId,
                                            onExerciseSelected: (id, name) =>
                                                provider.setExerciseSelection(
                                                  id,
                                                  name,
                                                ),
                                          )
                                        : _buildDetailPane(
                                            provider,
                                            false,
                                          ), // Stage 1 placeholder
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                // Mobile Header
                                EliteSettingsAppBar(
                                  title: currentCycleName,
                                  isCompact: isCompact,
                                  showBackButton: true,
                                ),
                                Expanded(
                                  child: EliteRefreshIndicator(
                                    onRefresh: () => provider.forceRefresh(),
                                    color: AppColors.crimson,
                                    backgroundColor: AppColors.surface,
                                    child: _buildMasterWorkoutList(
                                      provider,
                                      allWorkoutsFlat,
                                      completedWorkouts,
                                      pendingWorkouts,
                                      isCompact,
                                      isWideLandscape,
                                      currentCycleStatus,
                                      nestedWorkouts,
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
          ),
        );
      },
    );
  }

  Widget _buildTemplateAction(CycleProvider provider, bool isCompact) {
    bool isDefault = false;
    try {
      final cycle = provider.cycles.firstWhere((c) => c.id == widget.cycleId);
      isDefault = cycle.isDefault;
    } catch (_) {}

    if (isDefault) {
      return Container(
        height: isCompact ? 56.h : 54.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.03)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.save_as_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              size: isCompact ? 18.r : 18.0,
            ),
            SizedBox(width: isCompact ? 12.w : 12.0),
            Text(
              "SYSTEM DEFAULT – SAVING DISABLED",
              style: AppTextStyles.labelSmall
                  .adaptive(context)
                  .copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
            ),
          ],
        ),
      );
    }

    final matchingTemplate = provider.findMatchingTemplate(widget.cycleId);

    return matchingTemplate != null
        ? Container(
            height: isCompact ? 56.h : 54.0,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 16.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.03),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.save_as_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  size: isCompact ? 18.r : 18.0,
                ),
                SizedBox(width: isCompact ? 12.w : 12.0),
                Expanded(
                  child: Text(
                    "MATCHES TEMPLATE: $matchingTemplate",
                    style: AppTextStyles.labelSmall
                        .adaptive(context)
                        .copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : GestureDetector(
            onTap: _showSaveTemplateDialog,
            child: Container(
              height: isCompact ? 56.h : 54.0,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: Border.all(
                  color: AppColors.crimson.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.save_as_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 20.r : 20.0,
                  ),
                  SizedBox(width: isCompact ? 12.w : 12.0),
                  Text(
                    "SAVE AS TEMPLATE",
                    style: AppTextStyles.labelMedium
                        .adaptive(context)
                        .copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildShareAction(CycleProvider provider, bool isCompact) {
    bool isDefault = false;
    try {
      final cycle = provider.cycles.firstWhere((c) => c.id == widget.cycleId);
      isDefault = cycle.isDefault;
    } catch (_) {}

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 8.h : 8.0),
      child: isDefault
          ? Container(
              height: isCompact ? 56.h : 54.0,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.03),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.ios_share_rounded,
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    size: isCompact ? 18.r : 18.0,
                  ),
                  SizedBox(width: isCompact ? 12.w : 12.0),
                  Text(
                    "SYSTEM DEFAULT – SHARING DISABLED",
                    style: AppTextStyles.labelSmall
                        .adaptive(context)
                        .copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                  ),
                ],
              ),
            )
          : Consumer<AuthProvider>(
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

                    final link = await provider.generateShareableLink(
                      widget.cycleId,
                      userName,
                    );

                    if (link != null) {
                      await Share.share(
                        "CHECK OUT THIS HIT TRAINING CYCLE SHARED BY $userName IN RUGGED:\n\n$link",
                        subject: "TRAINING CYCLE SHARED BY $userName",
                      );
                    }
                  },
                  child: Container(
                    height: isCompact ? 56.h : 54.0,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPro ? Icons.ios_share_rounded : Icons.lock_rounded,
                          color: themeColor,
                          size: isCompact ? 20.r : 20.0,
                        ),
                        SizedBox(width: isCompact ? 12.w : 12.0),
                        Text(
                          isPro ? "SHARE CYCLE" : "GO PRO TO SHARE CYCLE",
                          style: AppTextStyles.labelMedium
                              .adaptive(context)
                              .copyWith(
                                color: themeColor,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ));
  }

  Widget _buildFinishCycleButton(
    List<Workout> allWorkouts,
    CycleProvider provider,
    bool isCompact,
  ) {
    if (allWorkouts.isEmpty) return const SizedBox.shrink();

    final bool allComplete =
        allWorkouts.isNotEmpty &&
        allWorkouts.every((w) => w.status == WorkoutStatus.completed);

    return GestureDetector(
      onTap: allComplete
          ? () async {
              final confirm = await EliteConfirmDialog.show(
                context,
                title: "FINISH TRAINING CYCLE?",
                message:
                    "CONGRATULATIONS. ALL SESSIONS COMPLETED. WOULD YOU LIKE TO ARCHIVE THIS CYCLE TO HISTORY?",
                confirmText: "ARCHIVE",
                icon: Icons.check_circle_rounded,
                confirmColor: Colors.greenAccent,
              );

              if (confirm == true) {
                await provider.finishCycle(widget.cycleId);
                if (mounted) Navigator.pop(context);
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: isCompact ? 56.h : 54.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: allComplete
              ? Colors.greenAccent.withValues(alpha: 0.1)
              : AppColors.surfaceLight.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(
            color: allComplete
                ? Colors.greenAccent
                : AppColors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: allComplete
                  ? Colors.greenAccent
                  : AppColors.textSecondary.withValues(alpha: 0.1),
              size: isCompact ? 20.r : 20.0,
            ),
            SizedBox(width: isCompact ? 12.w : 12.0),
            Text(
              allComplete ? "FINISH CYCLE" : "WORKOUTS REMAINING",
              style: AppTextStyles.labelMedium
                  .adaptive(context)
                  .copyWith(
                    color: allComplete
                        ? Colors.greenAccent
                        : AppColors.textSecondary.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
            ),
          ],
        ),
      ),
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
            color: Colors.black.withValues(alpha: 0.2),
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
              color: AppColors.crimson.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.layers_clear_rounded,
              color: AppColors.crimson.withValues(alpha: 0.6),
              size: isCompact ? 40.r : 36.0,
            ),
          ),
          SizedBox(height: isCompact ? 24.h : 20.0),
          Text(
            "SYSTEM IDLE",
            style: AppTextStyles.h3
                .adaptive(context)
                .copyWith(color: AppColors.white, letterSpacing: 4),
          ),
          SizedBox(height: isCompact ? 12.h : 10.0),
          Text(
            "NO WORKOUT ARCHITECTURE DETECTED IN THIS CYCLE.",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall
                .adaptive(context)
                .copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
          ),
          SizedBox(height: isCompact ? 16.h : 16.0),
          Container(
            height: 1,
            width: isCompact ? 40.w : 40.0,
            color: AppColors.crimson.withValues(alpha: 0.3),
          ),
          SizedBox(height: isCompact ? 16.h : 16.0),
          Text(
            "INITIALIZE YOUR ROUTINE BY ADDING A NEW WORKOUT SESSION USING THE ACTION BUTTON BELOW.",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall
                .adaptive(context)
                .copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    CycleProvider provider,
    bool isCompact, {
    bool isWideLandscape = false,
    CycleStatus? currentCycleStatus,
  }) {
    String currentCycleName = widget.cycleName;
    try {
      final cycle = provider.cycles.firstWhere((c) => c.id == widget.cycleId);
      currentCycleName = cycle.name;
    } catch (_) {}

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
      child: Row(
        children: [
          _buildSectionHeader("WORKOUT LIST", isCompact),
          const Spacer(),
          IconButton(
            onPressed: () => _editCycleName(currentCycleName),
            icon: Icon(
              Icons.edit_rounded,
              color: AppColors.textSecondary,
              size: isCompact ? 22.r : 20.0,
            ),
            tooltip: "Rename Cycle",
          ),
          IconButton(
            onPressed: _showInstructions,
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.textSecondary,
              size: isCompact ? 24.r : 22.0,
            ),
            tooltip: "Instructions",
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
          style: AppTextStyles.labelSmall
              .adaptive(context)
              .copyWith(color: AppColors.textSecondary.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  Widget _buildDismissibleWorkoutCard(
    int index,
    Workout workout,
    CycleProvider provider,
    bool isCompact, {
    bool isWideLandscape = false,
    bool isSelected = false,
    VoidCallback? onSelected,
  }) {
    final bool isExpanded = _expandedWorkoutIds.contains(workout.id);
    final progression = provider.calculateWorkoutProgression(
      workout,
      targetCycleId: widget.cycleId,
    );
    final strength = progression['strength']!;
    final volumeChange = progression['volume']!;

    final List<Map<String, dynamic>> exerciseVolumes = workout.exercises
        .map((e) {
          final logs = provider.logs
              .where((l) => l.exerciseId == e.id)
              .toList();
          double volKg = 0;
          for (var l in logs) {
            volKg += l.weightKg * l.positiveReps;
          }
          return {'name': e.name, 'volume': volKg / 1000.0};
        })
        .where((element) => (element['volume'] as double) > 0)
        .toList();

    final double totalWorkoutVolume = exerciseVolumes.fold(
      0,
      (sum, item) => sum + (item['volume'] as double),
    );
    final bool hasPerformanceData =
        strength != 0 || volumeChange != 0 || totalWorkoutVolume > 0;

    return Dismissible(
      key: Key("${workout.id}_dismiss"),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompactDialog = constraints.maxWidth < 600;
              return AlertDialog(
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    isCompactDialog ? 28.r : 20.0,
                  ),
                ),
                title: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompactDialog ? 12.r : 12.0),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.crimson,
                        size: isCompactDialog ? 28.r : 24.0,
                      ),
                    ),
                    SizedBox(height: isCompactDialog ? 16.h : 16.0),
                    Text(
                      "CONFIRM DELETION",
                      style: AppTextStyles.h3
                          .adaptive(context)
                          .copyWith(letterSpacing: 1.2),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ARE YOU SURE YOU WANT TO DELETE '${workout.name}'?",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall
                          .adaptive(context)
                          .copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompactDialog ? 12.w : 12.0,
                      0,
                      isCompactDialog ? 12.w : 12.0,
                      isCompactDialog ? 16.h : 16.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, false),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: isCompactDialog ? 12.h : 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  isCompactDialog ? 12.r : 10.0,
                                ),
                                border: Border.all(
                                  color: AppColors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "CANCEL",
                                style: AppTextStyles.labelSmall
                                    .adaptive(context)
                                    .copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isCompactDialog ? 12.w : 12.0),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, true),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: isCompactDialog ? 12.h : 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.crimson.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  isCompactDialog ? 12.r : 10.0,
                                ),
                                border: Border.all(
                                  color: AppColors.crimson.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "DELETE",
                                style: AppTextStyles.labelSmall
                                    .adaptive(context)
                                    .copyWith(
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
      },
      onDismissed: (direction) {
        provider.deleteWorkout(workout.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isCompact ? 24.w : 24.0),
        margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
          size: isCompact ? 28.r : 28.0,
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.crimson.withValues(alpha: 0.1)
              : AppColors.surfaceLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
          border: isSelected
              ? Border.all(
                  color: AppColors.crimson.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
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
                    onSelected?.call(); // Sync state in provider
                    if (!isWideLandscape) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseListScreen(
                            workoutId: workout.id,
                            workoutName: workout.name,
                            selectedExerciseId: provider.selectedExerciseId,
                            onExerciseSelected: (id, name) =>
                                provider.setExerciseSelection(id, name),
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
                        // Left Column: Index, Title, Subtitle, Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: isCompact ? 24.r : 24.0,
                                    height: isCompact ? 24.r : 24.0,
                                    margin: EdgeInsets.only(
                                      right: isCompact ? 12.w : 12.0,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.crimson,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "${index + 1}",
                                      style: AppTextStyles.labelSmall
                                          .adaptive(context)
                                          .copyWith(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      workout.name,
                                      style: AppTextStyles.h3
                                          .adaptive(context)
                                          .copyWith(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 8.h : 8.0),
                              Text(
                                workout.completedAt != null
                                    ? DateFormat('MMM dd, yyyy')
                                          .format(workout.completedAt!)
                                          .toUpperCase()
                                    : "PENDING",
                                style: AppTextStyles.labelSmall
                                    .adaptive(context)
                                    .copyWith(
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.4,
                                      ),
                                      letterSpacing: 1,
                                    ),
                              ),
                              if (workout.status == WorkoutStatus.completed)
                                _buildStatusBadge(isCompact),
                            ],
                          ),
                        ),
                        // Right Column: Strength Data
                        if (strength != 0) ...[
                          SizedBox(width: isCompact ? 16.w : 16.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "STRENGTH",
                                style: AppTextStyles.labelSmall
                                    .adaptive(context)
                                    .copyWith(
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              Text(
                                "${strength > 0 ? '+' : ''}${(strength * 100).toStringAsFixed(1)}%",
                                style: AppTextStyles.h2
                                    .adaptive(context)
                                    .copyWith(
                                      color: strength > 0
                                          ? AppColors.success
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(width: isCompact ? 12.w : 12.0),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          size: isCompact ? 14.r : 14.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Expansion Logic for Volume
            if (hasPerformanceData) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 24.w : 24.0,
                ),
                child: Divider(
                  color: AppColors.white.withValues(alpha: 0.05),
                  height: 1,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedWorkoutIds.remove(workout.id);
                  } else {
                    _expandedWorkoutIds.add(workout.id);
                  }
                }),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: isCompact ? 12.h : 12.0,
                  ),
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isExpanded ? "COLLAPSE DATA" : "SHOW PERFORMANCE DATA",
                        style: AppTextStyles.labelSmall
                            .adaptive(context)
                            .copyWith(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.4,
                              ),
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
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
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
                          isCompact ? 24.h : 20.0,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(
                              isCompact ? 16.r : 12.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (volumeChange != 0) ...[
                                Text(
                                  "VOLUME CHANGE",
                                  style: AppTextStyles.labelSmall
                                      .adaptive(context)
                                      .copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                ),
                                SizedBox(height: isCompact ? 8.h : 8.0),
                                Text(
                                  "${volumeChange > 0 ? '+' : ''}${(volumeChange * 100).toStringAsFixed(1)}%",
                                  style: AppTextStyles.labelMedium
                                      .adaptive(context)
                                      .copyWith(
                                        color: volumeChange > 0
                                            ? AppColors.success
                                            : AppColors.crimson,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                SizedBox(height: isCompact ? 16.h : 16.0),
                                Divider(
                                  color: AppColors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                ),
                                SizedBox(height: isCompact ? 16.h : 16.0),
                              ],

                              if (exerciseVolumes.isNotEmpty) ...[
                                Text(
                                  "EXERCISE BREAKDOWN",
                                  style: AppTextStyles.labelSmall
                                      .adaptive(context)
                                      .copyWith(
                                        color: AppColors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                ),
                                SizedBox(height: isCompact ? 12.h : 12.0),
                                ...exerciseVolumes.map(
                                  (ev) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: isCompact ? 8.h : 8.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ev['name'].toString().toUpperCase(),
                                            style: AppTextStyles.labelSmall
                                                .adaptive(context)
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          "${(ev['volume'] as double) >= 1 ? (ev['volume'] as double).toStringAsFixed(2) : (ev['volume'] as double).toStringAsFixed(3)} T",
                                          style: AppTextStyles.labelSmall
                                              .adaptive(context)
                                              .copyWith(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: isCompact ? 12.h : 12.0),
                                Divider(
                                  color: AppColors.white.withValues(alpha: 0.1),
                                ),
                                SizedBox(height: isCompact ? 12.h : 12.0),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "TOTAL WORKOUT TONNAGE",
                                      style: AppTextStyles.labelSmall
                                          .adaptive(context)
                                          .copyWith(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1,
                                          ),
                                    ),
                                    Text(
                                      "${totalWorkoutVolume >= 1 ? totalWorkoutVolume.toStringAsFixed(2) : totalWorkoutVolume.toStringAsFixed(3)} T",
                                      style: AppTextStyles.labelMedium
                                          .adaptive(context)
                                          .copyWith(
                                            color: AppColors.crimson,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
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

  Widget _buildStatusBadge(bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(top: isCompact ? 12.h : 12.0),
      child: IntrinsicWidth(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10.w : 10.0,
            vertical: isCompact ? 4.h : 4.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(isCompact ? 4.r : 4.0),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Text(
            "COMPLETED",
            style: AppTextStyles.labelSmall
                .adaptive(context)
                .copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCommentSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: AppColors.white.withValues(alpha: 0.1),
          height: isCompact ? 32.h : 32.0,
        ),
        _buildSectionHeader("CYCLE OBSERVATIONS", isCompact),
        SizedBox(height: isCompact ? 12.h : 12.0),
        TextField(
          controller: _cycleNoteController,
          minLines: 3,
          maxLines: null,
          style: AppTextStyles.bodyMedium
              .adaptive(context)
              .copyWith(color: AppColors.white),
          decoration: InputDecoration(
            hintText: "NOTES ON CYCLE...",
            hintStyle: AppTextStyles.labelSmall
                .adaptive(context)
                .copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              borderSide: BorderSide(
                color: AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              borderSide: BorderSide(
                color: AppColors.border,
              ),
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
            style: AppTextStyles.labelSmall
                .adaptive(context)
                .copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  letterSpacing: 1.5,
                ),
          ),
        ),
      ],
    );
  }
}
