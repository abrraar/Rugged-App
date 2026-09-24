import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/features/tracker/cycle_tracker/widgets/exercise_picker_sheet.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';
import 'model/exercise.dart';

class CreateCycleScreen extends StatefulWidget {
  final TrainingCycle? existingCycle;
  const CreateCycleScreen({super.key, this.existingCycle});

  @override
  State<CreateCycleScreen> createState() => _CreateCycleScreenState();
}

class _CreateCycleScreenState extends State<CreateCycleScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _workouts = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingCycle != null) {
      _nameController.text = widget.existingCycle!.name;
      _descriptionController.text = widget.existingCycle!.description;
      for (var w in widget.existingCycle!.workouts) {
        _workouts.add({
          "id": w.id,
          "name": w.name,
          "exercises": w.exercises.map((e) => e.name).toList(),
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addWorkout() {
    TextEditingController titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : 400),
              child: AlertDialog(
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
                        Icons.add_rounded,
                        color: AppColors.crimson,
                        size: isCompact ? 28.r : 28.0,
                      ),
                    ),
                    SizedBox(height: isCompact ? 16.h : 16.0),
                    Text(
                      "WORKOUT NAME",
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
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3.adaptive(context).copyWith(
                        color: AppColors.white, 
                      ),
                      decoration: InputDecoration(
                        hintText: "e.g. CHEST & BACK",
                        hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.textSecondary,
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.crimson, width: 2),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.crimson, width: 2),
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
                      isCompact ? 16.h : 16.0
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                                border: Border.all(color: AppColors.white.withValues(alpha : 0.1)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "CANCEL",
                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
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
                            onTap: () {
                              if (titleController.text.trim().isNotEmpty) {
                                final workoutName = titleController.text.trim().toUpperCase();
                                Navigator.pop(context);
                                setState(() {
                                  _workouts.add({
                                    "name": workoutName,
                                    "exercises": <String>[],
                                  });
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                              decoration: BoxDecoration(
                                color: AppColors.crimson.withValues(alpha : 0.1),
                                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                                border: Border.all(color: AppColors.crimson.withValues(alpha : 0.5)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "ADD",
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
              ),
            ),
          );
        }
      ),
    );
  }

  void _addExerciseToWorkout(Map<String, dynamic> workout) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => ExercisePickerSheet(
        isSideSheet: isSideSheet,
        onSelected: (name) {
          setState(() {
            workout['exercises'].add(name);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
          final bool isLargeScreen = MediaQuery.of(context).size.width >= 600 || constraints.maxWidth >= 600;
          final bool isSplitView = constraints.maxWidth >= 600 || (isLargeScreen && isLandscape);

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
                          'CREATE CUSTOM CYCLE',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2.adaptive(context).copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Opacity(
                        opacity: 0,
                        child: IconButton(
                          icon: Icon(Icons.info_outline_rounded),
                          onPressed: null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: isSplitView
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Pane: Cycle Identity
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: AppColors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24.0,
                                  horizontal: 24.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(context, "CYCLE IDENTITY", isCompact),
                                    SizedBox(height: isCompact ? 16.h : 16.0),
                                    _buildTextField(context, "CYCLE NAME", _nameController, isCompact: isCompact),
                                    SizedBox(height: isCompact ? 16.h : 16.0),
                                    _buildTextField(
                                      context,
                                      "DESCRIPTION (OPTIONAL)",
                                      _descriptionController,
                                      maxLines: 2,
                                      hint: "e.g. FOCUS ON PROGRESSIVE OVERLOAD AND RECOVERY",
                                      isCompact: isCompact,
                                    ),
                                    SizedBox(height: isCompact ? 32.h : 32.0),
                                    _buildSaveButton(isCompact),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Right Pane: Workout Architecture
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24.0,
                                horizontal: 24.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(context, "WORKOUT ARCHITECTURE", isCompact),
                                  SizedBox(height: isCompact ? 16.h : 16.0),
                                  ..._workouts.map((w) => _buildWorkoutFormCard(w, isCompact)),
                                  _buildAddWorkoutButton(isCompact),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          vertical: isCompact ? 24.h : 24.0, 
                          horizontal: isCompact ? 24.w : 24.0
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(context, "CYCLE IDENTITY", isCompact),
                            SizedBox(height: isCompact ? 16.h : 16.0),
                            _buildTextField(context, "CYCLE NAME", _nameController, isCompact: isCompact),
                            SizedBox(height: isCompact ? 16.h : 16.0),
                            _buildTextField(
                              context,
                              "DESCRIPTION (OPTIONAL)",
                              _descriptionController,
                              maxLines: 2,
                              hint: "e.g. FOCUS ON PROGRESSIVE OVERLOAD AND RECOVERY",
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 32.h : 32.0),
                            _buildSectionHeader(context, "WORKOUT ARCHITECTURE", isCompact),
                            SizedBox(height: isCompact ? 16.h : 16.0),
                            ..._workouts.map((w) => _buildWorkoutFormCard(w, isCompact)),
                            _buildAddWorkoutButton(isCompact),
                            SizedBox(height: isCompact ? 40.h : 40.0),
                            _buildSaveButton(isCompact),
                          ],
                        ),
                      ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildWorkoutFormCard(Map<String, dynamic> workout, bool isCompact) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 16.0),
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(workout['name'], style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: Colors.white, 
                fontWeight: FontWeight.w500,
              ))),
              IconButton(
                onPressed: () => setState(() => _workouts.remove(workout)), 
                icon: Icon(Icons.delete_outline, color: AppColors.crimson, size: isCompact ? 20.r : 20.0)
              ),
            ],
          ),
          ...List.generate(workout['exercises'].length, (i) => Padding(
            padding: EdgeInsets.only(top: isCompact ? 8.h : 8.0),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: AppColors.crimson),
                SizedBox(width: isCompact ? 12.w : 12.0),
                Expanded(child: Text(workout['exercises'][i], style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary,
                ))),
                IconButton(
                  onPressed: () => setState(() => workout['exercises'].removeAt(i)),
                  icon: Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: isCompact ? 14.r : 14.0),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )),
          SizedBox(height: isCompact ? 12.h : 12.0),
          GestureDetector(
            onTap: () => _addExerciseToWorkout(workout),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: isCompact ? 8.h : 8.0),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.crimson.withValues(alpha : 0.3), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.crimson, size: isCompact ? 14.r : 14.0),
                    SizedBox(width: isCompact ? 8.w : 8.0),
                    Text("ADD EXERCISE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.crimson, 
                    )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddWorkoutButton(bool isCompact) {
    return GestureDetector(
      onTap: _addWorkout,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 16.0),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.white.withValues(alpha : 0.1), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        ),
        child: const Center(child: Icon(Icons.add, color: AppColors.textSecondary)),
      ),
    );
  }

  bool get _isCycleValid {
    if (_nameController.text.trim().isEmpty) return false;
    if (_workouts.isEmpty) return false;
    // Check if every workout has at least one exercise
    return _workouts.every((w) => (w['exercises'] as List).isNotEmpty);
  }

  String get _validationText {
    if (_nameController.text.trim().isEmpty) return "ENTER CYCLE NAME";
    if (_workouts.isEmpty) return "ADD A WORKOUT";
    bool allWorkoutsHaveExercises = _workouts.every((w) => (w['exercises'] as List).isNotEmpty);
    if (!allWorkoutsHaveExercises) return "ADD EXERCISES TO WORKOUTS";
    return "";
  }

  Widget _buildSaveButton(bool isCompact) {
    final bool isValid = _isCycleValid;
    final String valText = _validationText;

    return Column(
      children: [
        GestureDetector(
          onTap: isValid ? () => _handleSave(shouldInitialize: false) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isCompact ? 50.h : 50.0,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              border: Border.all(
                color: isValid ? AppColors.white.withValues(alpha : 0.1) : AppColors.white.withValues(alpha : 0.03),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              isValid ? "SAVE TO LIBRARY" : valText,
              style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
                color: isValid ? AppColors.white : AppColors.textSecondary.withValues(alpha : 0.3),
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12.h : 12.0),
        GestureDetector(
          onTap: isValid ? () => _handleSave(shouldInitialize: true) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isCompact ? 54.h : 54.0,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isValid ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha : 0.1),
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              boxShadow: isValid ? [
                BoxShadow(
                  color: AppColors.crimson.withValues(alpha : 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            alignment: Alignment.center,
            child: Text(
              isValid ? "SAVE AND INITIALIZE" : valText,
              style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
                color: isValid ? Colors.white : AppColors.textSecondary.withValues(alpha : 0.3),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave({required bool shouldInitialize}) async {
    if (_nameController.text.isEmpty || _workouts.isEmpty) {
      EliteSnackbar.show(context, "Please provide a name and at least one workout.", isError: true);
      return;
    }

    final provider = context.read<CycleProvider>();

    final active = provider.activeCycle;

    // If initializing, check if we need to replace an existing cycle
    if (shouldInitialize && active != null) {
      if (widget.existingCycle != null && active.id == widget.existingCycle!.id) {
        // We are editing the active cycle and want to re-initialize? 
        // Actually, normally editing a template shouldn't affect the active cycle unless explicitly activated.
      } else if (!active.isReadyToFinish) {
        // Warning for incomplete cycle
        final confirm = await EliteConfirmDialog.show(
          context,
          title: "INCOMPLETE CYCLE",
          message: "YOUR CURRENT CYCLE '${active.name.toUpperCase()}' IS NOT YET COMPLETE. ACTIVATING THIS NEW ONE WILL MOVE THE INCOMPLETE PROTOCOL TO YOUR HISTORY. PROCEED?",
          confirmText: "PROCEED",
        );
        if (confirm != true) return;
      } else {
        // Confirmation for finished cycle
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha : 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.bolt_rounded, color: Colors.greenAccent, size: 28),
                ),
                SizedBox(height: 16.h),
                Text("ACTIVATE PROTOCOL", style: AppTextStyles.h3.adaptive(context).copyWith(letterSpacing: 1.2), textAlign: TextAlign.center),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "DO YOU WANT TO INITIALIZE THIS NEW TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withValues(alpha : 0.1))),
                          alignment: Alignment.center,
                          child: Text("CANCEL", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha : 0.1), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.greenAccent.withValues(alpha : 0.5))),
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
        if (confirm != true) return;
      }
    } else if (shouldInitialize) {
      // Confirmation for no active cycle
      final confirm = await EliteConfirmDialog.show(
        context,
        title: "ACTIVATE PROTOCOL",
        message: "DO YOU WANT TO INITIALIZE THIS NEW TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
        confirmText: "ACTIVATE",
        confirmColor: Colors.greenAccent,
        icon: Icons.bolt_rounded,
      );
      if (confirm != true) return;
    }

    final String templateId = widget.existingCycle?.id ?? const Uuid().v4();
    final template = TrainingCycle(
      id: templateId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      status: widget.existingCycle?.status ?? CycleStatus.template,
      isDefault: widget.existingCycle?.isDefault ?? false,
      workouts: List.generate(_workouts.length, (i) {
        final wData = _workouts[i];
        final workoutId = wData['id'] ?? const Uuid().v4();
        return Workout(
          id: workoutId,
          cycleId: templateId,
          name: wData['name'],
          order: i,
          status: WorkoutStatus.pending,
          exercises: List.generate(wData['exercises'].length, (j) {
            return Exercise(
              workoutId: workoutId,
              name: wData['exercises'][j],
              order: j,
            );
          }),
        );
      }),
    );

    if (widget.existingCycle != null) {
      // Delete old cycle first or use an update method if available
      // addCycle actually uses insertCycle with replace if we have it
      // Actually addCycle in provider just does list.add and localRepo.insertCycle
      // I should probably delete the old one or make sure addCycle handles updates correctly.
      // In CycleProvider, addCycle adds to the list: _cycles.add(localCycle);
      // If we are editing, we should replace it.
      await provider.deleteCycle(widget.existingCycle!.id);
    }
    
    await provider.addCycle(template);

    if (shouldInitialize) {
      // Activate the newly saved template
      await provider.activateCycle(template.id);
    }

    if (mounted) {
      Navigator.pop(context, true);
      EliteSnackbar.show(
        context, 
        shouldInitialize
            ? "Cycle '${template.name}' Initialized & Saved!"
            : "Cycle '${template.name}' saved to Library"
      );
    }
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

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, {int? maxLines, String? hint, required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary, 
        )),
        SizedBox(height: isCompact ? 8.h : 8.0),
        TextField(
          controller: controller,
          maxLines: maxLines ?? 1,
          onChanged: (val) {
            if (maxLines == 2) {
              final lines = val.split('\n');
              if (lines.length > 2) {
                // Prevent adding more lines
                controller.text = lines.sublist(0, 2).join('\n');
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              }
            }
            setState(() {});
          },
          style: AppTextStyles.bodyMedium.adaptive(context).copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha : 0.3), 
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), 
              borderSide: BorderSide.none
            ),
          ),
        ),
      ],
    );
  }
}
