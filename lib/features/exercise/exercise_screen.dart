import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_search_bar.dart';
import 'exercise_detail_screen.dart';
import 'model/exercise_template.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/features/exercise/widgets/add_custom_exercise_sheet.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isCustomTab = false;
  String _searchQuery = "";

  // Filter States
  final Set<int> _selectedDemands = {};
  final Set<String> _selectedMuscles = {};
  bool _isAscending = true;

  // Split-Screen State
  String? _selectedExerciseId;
  String? _selectedExerciseName;
  int? _selectedIntensity;
  String? _selectedImagePath;
  String? _selectedAbout;
  double? _selectedAspectRatio;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _isCustomTab = _tabController.index == 1);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExerciseProvider>(
      builder: (context, provider, _) {
        final double deviceWidth = MediaQuery.of(context).size.width;
        final bool isTabletOrFoldable = deviceWidth >= 600;
        final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final bool isWideLandscape = isTabletOrFoldable && isLandscape;

        // ADAPTIVE PUSH ON ROTATION TO PORTRAIT
        if (!isWideLandscape && _selectedExerciseId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;

            final String exId = _selectedExerciseId!;
            final String exName = _selectedExerciseName!;
            final int intensity = _selectedIntensity!;
            final String imagePath = _selectedImagePath!;
            final String about = _selectedAbout!;
            final double? ratio = _selectedAspectRatio;

            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, anim1, anim2) => ExerciseDetailScreen(
                  exerciseId: exId,
                  exerciseName: exName,
                  intensity: intensity,
                  imagePath: imagePath,
                  about: about,
                  initialAspectRatio: ratio,
                ),
                transitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
                    child: child,
                  );
                },
              ),
            ).then((_) {
              if (!context.mounted) return;
              if (MediaQuery.of(context).orientation == Orientation.portrait) {
                setState(() => _selectedExerciseId = null);
              }
            });
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double paneWidth = constraints.maxWidth;
            final bool isCompact = paneWidth < 600 && !isLandscape && !isTabletOrFoldable;

            final double hPad = isTabletOrFoldable 
                ? (paneWidth - kMaxContentWidth).clamp(24.0, double.infinity) / 2 
                : 20.w;

            // --- HIGH INTENSITY PERFORMANCE OPTIMIZATION ---
            final filteredDefaults = _filterList(provider.defaultTemplates);
            final filteredCustom = _filterList(provider.customTemplates);

            Widget buildMainList(double currentHPad) {
              return Column(
                children: [
                  // Search Bar Area
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: currentHPad, 
                      vertical: isTabletOrFoldable ? 12.0 : 12.h
                    ),
                    child: AppSearchBar(
                      hintText: "Search exercises...",
                      maxLength: 30,
                      showAdd: _isCustomTab,
                      showFilter: true,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      onFilterTap: () => _showFilterOptions(context, isTabletOrFoldable),
                      onAddTap: () {
                        AdaptiveUtils.showAdaptiveSheet(
                          context: context,
                          sheetBuilder: (sheetContext, isSideSheet) => AddCustomExerciseSheet(isSideSheet: isSideSheet),
                        );
                      },
                    ),
                  ),

                  // Tab Bar
                  Container(
                    width: double.infinity,
                    height: isTabletOrFoldable ? 44.0 : 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.1),
                      border: Border(bottom: BorderSide(color: AppColors.white.withValues(alpha: 0.05))),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: (isCompact || isWideLandscape) ? double.infinity : kMaxContentWidth),
                        child: TabBar(
                          controller: _tabController,
                          padding: EdgeInsets.symmetric(horizontal: currentHPad),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          indicator: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.crimson, width: 2)),
                          ),
                          labelColor: AppColors.crimson,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                          tabs: const [
                            Tab(text: 'DEFAULT EXERCISES'),
                            Tab(text: 'MY EXERCISES'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Exercise Lists
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildExerciseList(filteredDefaults, currentHPad, isTabletOrFoldable, isWideLandscape),
                        _buildExerciseList(filteredCustom, currentHPad, isTabletOrFoldable, isWideLandscape),
                      ],
                    ),
                  ),
                ],
              );
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isWideLandscape
                  ? Row(
                      key: const ValueKey('exercise_landscape'),
                      children: [
                        // Master Pane (Left)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: AppColors.white.withValues(alpha: 0.05))),
                            ),
                            child: buildMainList(24.0),
                          ),
                        ),
                        // Detail Pane (Right)
                        Expanded(
                          child: Container(
                            color: AppColors.background,
                            child: _selectedExerciseId != null
                                ? ExerciseDetailScreen(
                                    key: Key("ex_detail_$_selectedExerciseId"),
                                    exerciseId: _selectedExerciseId!,
                                    exerciseName: _selectedExerciseName!,
                                    intensity: _selectedIntensity!,
                                    imagePath: _selectedImagePath!,
                                    about: _selectedAbout!,
                                    initialAspectRatio: _selectedAspectRatio,
                                    isEmbedded: true,
                                  )
                                : Center(
                                    child: Text(
                                      "SELECT AN EXERCISE TO VIEW DETAILS",
                                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    )
                  : buildMainList(hPad),
            );
          },
        );
      },
    );
  }

  Widget _buildExerciseList(List<ExerciseTemplate> exercises, double hPad, bool isTablet, bool isWideLandscape) {
    return EliteRefreshIndicator(
      onRefresh: () => context.read<ExerciseProvider>().forceRefresh(),
      color: AppColors.crimson,
      backgroundColor: AppColors.surface,
      child: exercises.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                SizedBox(
                  height: isTablet ? 250.0 : 400.h,
                  child: Center(
                    child: Text(
                      "No exercises found.",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              cacheExtent: 500, 
              padding: EdgeInsets.symmetric(
                horizontal: hPad, 
                vertical: isTablet ? 16.0 : 20.h
              ),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => SizedBox(height: isTablet ? 12.0 : 16.h),
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _buildVisualExerciseCard(exercise, isTablet, isWideLandscape, key: ValueKey(exercise.id));
              },
            ),
    );
  }

  Widget _buildVisualExerciseCard(ExerciseTemplate exercise, bool isTablet, bool isWideLandscape, {Key? key}) {
    if (!exercise.isDefault) {
      return Dismissible(
        key: key ?? ValueKey(exercise.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (dir) async => await _showDeleteConfirmation(exercise.name),
        onDismissed: (dir) {
          context.read<ExerciseProvider>().deleteTemplate(exercise.id);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: isTablet ? 24.0 : 24.w),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(isTablet ? 16.0 : 20.r),
          ),
          child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: isTablet ? 24.0 : 28.r),
        ),
        child: _buildBaseExerciseCard(exercise, isTablet, isWideLandscape),
      );
    }
    return _buildBaseExerciseCard(exercise, isTablet, isWideLandscape);
  }

  Future<bool?> _showDeleteConfirmation(String exerciseName) async {
    final cycleProv = context.read<CycleProvider>();
    final bool isInUse = cycleProv.isExerciseInUse(exerciseName);

    if (isInUse) {
      return await EliteConfirmDialog.show(
        context,
        title: "EXERCISE IN USE",
        message: "'${exerciseName.toUpperCase()}' IS CURRENTLY PART OF ONE OR MORE TRAINING CYCLES. REMOVING IT FROM THE LIBRARY WILL NOT DELETE IT FROM EXISTING LOGS, BUT YOU WON'T BE ABLE TO ADD IT TO NEW WORKOUTS.\n\nPROCEED WITH DELETION?",
        icon: Icons.warning_amber_rounded,
        confirmText: "DELETE ANYWAY",
      );
    }

    return await EliteConfirmDialog.show(
      context,
      title: "DELETE EXERCISE",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THE '${exerciseName.toUpperCase()}' TEMPLATE?",
      icon: Icons.delete_outline_rounded,
    );
  }

  Widget _buildBaseExerciseCard(ExerciseTemplate exercise, bool isTablet, bool isWideLandscape) {
    final bool isSelected = isWideLandscape && _selectedExerciseId == exercise.id;
    final Color cardBg = isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.surface;

    return _ExerciseCardItem(
      exercise: exercise,
      isTablet: isTablet,
      isWideLandscape: isWideLandscape,
      isSelected: isSelected,
      cardBg: cardBg,
      onTap: () {
        if (isWideLandscape) {
          setState(() {
            _selectedExerciseId = exercise.id;
            _selectedExerciseName = exercise.name;
            _selectedIntensity = exercise.intensity;
            _selectedImagePath = exercise.imageUrl ?? "";
            _selectedAbout = exercise.aboutTheMovement ?? "";
            _selectedAspectRatio = exercise.aspectRatio;
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseDetailScreen(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                intensity: exercise.intensity,
                imagePath: exercise.imageUrl ?? "",
                about: exercise.aboutTheMovement ?? "",
                initialAspectRatio: exercise.aspectRatio,
              ),
            ),
          );
        }
      },
    );
  }

  List<ExerciseTemplate> _filterList(List<ExerciseTemplate> original) {
    if (_searchQuery.isEmpty && _selectedDemands.isEmpty && _selectedMuscles.isEmpty && _isAscending) {
      return original;
    }
    
    var list = original.where((t) {
      final matchesSearch = _searchQuery.isEmpty || t.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDemand = _selectedDemands.isEmpty || _selectedDemands.contains(t.intensity);
      
      bool matchesMuscle = _selectedMuscles.isEmpty;
      if (!matchesMuscle && t.targetMuscles != null) {
        final targets = t.targetMuscles!.split(',').map((m) => m.trim().toUpperCase());
        matchesMuscle = _selectedMuscles.any((sm) => targets.contains(sm.toUpperCase()));
      }
      
      return matchesSearch && matchesDemand && matchesMuscle;
    }).toList();

    list.sort((a, b) => _isAscending 
        ? a.name.compareTo(b.name) 
        : b.name.compareTo(a.name));
    
    return list;
  }

  void _showFilterOptions(BuildContext context, bool isTablet) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
            final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

            return Align(
              alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
              child: SizedBox(
                width: sheetWidth,
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Container(
                      height: isSideSheet ? double.infinity : null,
                      padding: EdgeInsets.fromLTRB(
                        isTablet ? 24.0 : 24.r, 
                        isSideSheet ? 0 : (isTablet ? 12.0 : 12.r), 
                        isTablet ? 24.0 : 24.r, 
                        isTablet ? 24.0 : 24.r
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: isSideSheet 
                          ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                          : BorderRadius.vertical(top: Radius.circular(isTablet ? 24.0 : 32.r)),
                      ),
                      child: Column(
                        mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSideSheet) const SizedBox(height: 24.0),
                          if (!isSideSheet) _buildHandle(isTablet),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "FILTER EXERCISES", 
                                style: AppTextStyles.h3.adaptive(context)
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setModalState(() {
                                        _selectedDemands.clear();
                                        _selectedMuscles.clear();
                                        _isAscending = true;
                                      });
                                      setState(() {});
                                    },
                                    child: Text(
                                      "RESET", 
                                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                        color: AppColors.crimson,
                                        fontWeight: FontWeight.w500,
                                      )
                                    ),
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(sheetContext),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: isTablet ? 20.0 : 24.h),
                          
                          // Sort Order
                          Text(
                            "SORT ORDER", 
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary, 
                              fontWeight: FontWeight.w500,
                            )
                          ),
                          SizedBox(height: isTablet ? 10.0 : 12.h),
                          Row(
                            children: [
                              _buildFilterChip(
                                label: "A-Z",
                                isSelected: _isAscending,
                                isTablet: isTablet,
                                onTap: () {
                                  setModalState(() => _isAscending = true);
                                  setState(() {});
                                },
                              ),
                              SizedBox(width: isTablet ? 8.0 : 8.w),
                              _buildFilterChip(
                                label: "Z-A",
                                isSelected: !_isAscending,
                                isTablet: isTablet,
                                onTap: () {
                                  setModalState(() => _isAscending = false);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: isTablet ? 20.0 : 24.h),

                          // Metabolic Demand
                          Text(
                            "METABOLIC DEMAND", 
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary, 
                              fontWeight: FontWeight.w500,
                            )
                          ),
                          SizedBox(height: isTablet ? 10.0 : 12.h),
                          Wrap(
                            spacing: isTablet ? 8.0 : 8.w,
                            runSpacing: isTablet ? 8.0 : 8.h,
                            children: List.generate(5, (index) {
                              final demand = index + 1;
                              final isSelected = _selectedDemands.contains(demand);
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      _selectedDemands.remove(demand);
                                    } else {
                                      _selectedDemands.add(demand);
                                    }
                                  });
                                  setState(() {});
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 10.0 : 12.w, 
                                    vertical: isTablet ? 6.0 : 6.h
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(isTablet ? 8.0 : 8.r),
                                    border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(demand, (i) => Icon(
                                      Icons.local_fire_department_rounded,
                                      size: isTablet ? 12.0 : 14.r,
                                      color: isSelected ? Colors.white : AppColors.crimson,
                                    )),
                                  ),
                                ),
                              );
                            }),
                          ),
                          SizedBox(height: isTablet ? 20.0 : 24.h),

                          // Muscle Groups
                          Text(
                            "TARGET MUSCLES", 
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary, 
                              fontWeight: FontWeight.w500,
                            )
                          ),
                          SizedBox(height: isTablet ? 10.0 : 12.h),
                          Wrap(
                            spacing: isTablet ? 8.0 : 8.w,
                            runSpacing: isTablet ? 8.0 : 8.h,
                            children: [
                              'Chest', 'Back', 'Legs', 'Calf', 'Abdominals', 'Shoulder', 'Biceps', 'Triceps'
                            ].map((m) {
                              final isSelected = _selectedMuscles.contains(m);
                              return _buildFilterChip(
                                label: m.toUpperCase(),
                                isSelected: isSelected,
                                isTablet: isTablet,
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      _selectedMuscles.remove(m);
                                    } else {
                                      _selectedMuscles.add(m);
                                    }
                                  });
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          ),
                          SizedBox(height: isTablet ? 24.0 : 32.h),
                          
                          GestureDetector(
                            onTap: () => Navigator.pop(sheetContext),
                            child: Container(
                              height: isTablet ? 48.0 : 54.h,
                              width: double.infinity,
                              decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(isTablet ? 10.0 : 12.r)),
                              alignment: Alignment.center,
                              child: Text(
                                "APPLY FILTERS", 
                                style: AppTextStyles.buttonPrimary.adaptive(context)
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
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label, 
    required bool isSelected, 
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 14.0 : 16.w, 
          vertical: isTablet ? 6.0 : 8.h
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isTablet ? 8.0 : 8.r),
          border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isTablet) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: isTablet ? 20.0 : 24.h),
        width: isTablet ? 40.0 : 40.w,
        height: isTablet ? 4.0 : 4.h,
        decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }
}

class _ExerciseCardItem extends StatelessWidget {
  final ExerciseTemplate exercise;
  final bool isTablet;
  final bool isWideLandscape;
  final bool isSelected;
  final Color cardBg;
  final VoidCallback onTap;

  const _ExerciseCardItem({
    required this.exercise,
    required this.isTablet,
    required this.isWideLandscape,
    required this.isSelected,
    required this.cardBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: isTablet ? 90.0 : 100.h),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(isTablet ? 16.0 : 20.r),
          border: isSelected 
              ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5), width: 1.5)
              : Border.all(color: AppColors.white.withValues(alpha: 0.02)),
        ),
        padding: EdgeInsets.all(isTablet ? 16.0 : 20.r),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    exercise.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.adaptive(context).copyWith(
                      letterSpacing: 0.5, 
                      color: AppColors.white
                    ),
                  ),
                  if (exercise.sharedBy != null)
                    Padding(
                      padding: EdgeInsets.only(top: isTablet ? 4.0 : 4.h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_rounded, color: Colors.blueAccent, size: isTablet ? 10.0 : 10.r),
                            const SizedBox(width: 4.0),
                            Text(
                              "SHARED BY ${exercise.sharedBy!.toUpperCase()}",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: isTablet ? 8.0 : 8.h),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: exercise.type == ExerciseType.compound ? AppColors.crimson.withValues(alpha: 0.2) : AppColors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: exercise.type == ExerciseType.compound ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          exercise.type.name.toUpperCase(),
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: exercise.type == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          (exercise.targetMuscles ?? "").toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                            color: AppColors.textSecondary, 
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 6.0 : 8.h),
                  Row(
                    children: [
                      Text('DEMAND: ', style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      _buildFireRating(exercise.intensity, isTablet),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.white.withValues(alpha: 0.2), size: isTablet ? 14.0 : 16.r),
          ],
        ),
      ),
    );
  }

  Widget _buildFireRating(int score, bool isTablet) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          Icons.local_fire_department_rounded,
          size: isTablet ? 12.0 : 14.r,
          color: index < score 
              ? AppColors.crimson 
              : AppColors.white.withValues(alpha: 0.1),
        );
      }),
    );
  }
}
