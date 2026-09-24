import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/exercise/model/exercise_template.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';

class AddCustomExerciseSheet extends StatefulWidget {
  final bool isSideSheet;
  const AddCustomExerciseSheet({super.key, this.isSideSheet = false});

  @override
  State<AddCustomExerciseSheet> createState() => _AddCustomExerciseSheetState();
}

class _AddCustomExerciseSheetState extends State<AddCustomExerciseSheet> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final List<String> _muscles = [
    'Chest', 'Back', 'Legs', 'Calf', 'Abdominals', 'Shoulder', 'Biceps', 'Triceps'
  ];
  final Set<String> _selectedMuscles = {};

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _toggleMuscle(String muscle) {
    setState(() {
      if (_selectedMuscles.contains(muscle)) {
        _selectedMuscles.remove(muscle);
      } else {
        _selectedMuscles.add(muscle);
      }
    });
  }

  // --- AUTOMATED LOGIC ---
  
  ExerciseType get _calculatedType => 
      _selectedMuscles.length > 1 ? ExerciseType.compound : ExerciseType.isolation;

  int get _calculatedIntensity {
    if (_selectedMuscles.isEmpty) return 1;
    if (_selectedMuscles.length == 1) return 2;
    if (_selectedMuscles.length == 2) return 3;
    if (_selectedMuscles.length <= 4) return 4;
    return 5;
  }

  String get _buttonText {
    if (_nameController.text.isEmpty) return "ENTER EXERCISE NAME";
    if (_selectedMuscles.isEmpty) return "SELECT TARGET MUSCLES";
    return "SAVE EXERCISE";
  }

  bool get _isReady => _nameController.text.isNotEmpty && _selectedMuscles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
        final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 600.0);

        return Center(
          child: SizedBox(
            width: sheetWidth,
            child: Container(
              height: widget.isSideSheet ? double.infinity : null,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: widget.isSideSheet 
                  ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                  : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
              ),
              child: Column(
                mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (!widget.isSideSheet)
                    Padding(
                      padding: EdgeInsets.only(
                        top: isCompact ? 12.h : 12.0, 
                        bottom: isCompact ? 8.h : 8.0
                      ),
                      child: _buildHandle(isCompact),
                    ),
                  if (widget.isSideSheet) SizedBox(height: 24.0),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 24.r : 24.0, 
                        0, 
                        isCompact ? 24.r : 24.0, 
                        isCompact ? 24.r : 24.0
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "NEW EXERCISE", 
                                style: AppTextStyles.h3.adaptive(context)
                              ),
                              if (widget.isSideSheet)
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildTextField("EXERCISE NAME", _nameController, "e.g. Hammer Curls", isCompact: isCompact),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildTextField("ABOUT THE MOVEMENT (OPTIONAL)", _aboutController, "Describe the proper form...", maxLines: 3, isCompact: isCompact),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          Text(
                            "TARGET MUSCLES", 
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary, 
                              fontWeight: FontWeight.w500,
                            )
                          ),
                          SizedBox(height: isCompact ? 12.h : 10.0),
                          Wrap(
                            spacing: isCompact ? 8.w : 8.0,
                            runSpacing: isCompact ? 8.h : 8.0,
                            children: _muscles.map((m) {
                              bool isSelected = _selectedMuscles.contains(m);
                              return GestureDetector(
                                onTap: () => _toggleMuscle(m),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 12.w : 10.0, 
                                    vertical: isCompact ? 6.h : 6.0
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0),
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
                          
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildAutoMetricsDisplay(isCompact),
                          
                          SizedBox(height: isCompact ? 32.h : 24.0),
                          _buildSaveButton(isCompact),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutoMetricsDisplay(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16.r : 12.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
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
                  horizontal: isCompact ? 8.w : 6.0, 
                  vertical: isCompact ? 2.h : 2.0
                ),
                decoration: BoxDecoration(
                  color: _calculatedType == ExerciseType.compound ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(isCompact ? 4.r : 4.0),
                ),
                child: Text(
                  _calculatedType.name.toUpperCase(),
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: _calculatedType == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12.h : 8.0),
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
              _buildFireRating(_calculatedIntensity, isCompact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFireRating(int score, bool isCompact) {
    return Row(
      children: List.generate(5, (index) => Icon(
        Icons.local_fire_department_rounded,
        size: isCompact ? 16.r : 16.0,
        color: index < score ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05),
      )),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, required bool isCompact}) {
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
          style: AppTextStyles.inputText.adaptive(context).copyWith(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputText.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2)),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 12.0, vertical: isCompact ? 14.h : 10.0),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isCompact) {
    return GestureDetector(
      onTap: _isReady ? _saveExercise : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? 54.h : 44.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isReady ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          boxShadow: _isReady ? [
            BoxShadow(color: AppColors.crimson.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          _buttonText,
          style: AppTextStyles.labelMedium.adaptive(context).copyWith(
            color: _isReady ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isCompact) {
    return Center(
      child: Container(
        width: isCompact ? 40.w : 40.0,
        height: isCompact ? 4.h : 4.0,
        decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }

  void _saveExercise() async {
    final template = ExerciseTemplate(
      name: _nameController.text.trim(),
      targetMuscles: _selectedMuscles.join(', '),
      type: _calculatedType,
      intensity: _calculatedIntensity,
      isDefault: false,
      aboutTheMovement: _aboutController.text.trim().isEmpty ? null : _aboutController.text.trim(),
    );

    final provider = context.read<ExerciseProvider>();
    Navigator.pop(context);
    await provider.addTemplate(template);
  }
}
