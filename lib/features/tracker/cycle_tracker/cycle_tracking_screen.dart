import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/features/tracker/cycle_tracker/create_cycle_screen.dart';
import 'package:rugged/features/tracker/cycle_tracker/cycle_detail_view_screen.dart';
import 'package:rugged/features/main_wrapper.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_filter.dart';
import 'package:rugged/features/tracker/cycle_tracker/workout_list_screen.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/exercise_log.dart';
import 'package:rugged/features/tracker/cycle_tracker/widgets/cycle_analytical_widget.dart';
import 'package:rugged/core/ads/locked_analytics_overlay.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';

class CycleTrackingScreen extends StatefulWidget {
  final int initialTabIndex;
  const CycleTrackingScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CycleTrackingScreen> createState() => _CycleTrackingScreenState();
}
class _CycleTrackingScreenState extends State<CycleTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDefaultExpanded = false;
  bool _isCustomExpanded = false;
  CycleFilter _historyFilter = CycleFilter();
  final Set<String> _expandedCycleIds = {};
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "cycle";
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    super.dispose();
  }

  void _showSystemInstructions() {
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
                  "CYCLE CONTROLS",
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
                _instructionRow(Icons.bolt_rounded, "Swipe right on library routines to activate them.", isCompact),
                SizedBox(height: isCompact ? 16.h : 12.0),
                _instructionRow(Icons.swipe_down_rounded, "Pull down on any list to sync data across devices (Pro feature).", isCompact),
                SizedBox(height: isCompact ? 16.h : 12.0),
                _instructionRow(Icons.delete_forever_rounded, "Swipe left on custom cycles to delete them.", isCompact),
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
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
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
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showActivateCycleConfirmation(String cycleName) async {
    return showDialog<bool>(
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
                    color: Colors.greenAccent.withValues(alpha : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: Colors.greenAccent,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "ACTIVATE PROTOCOL",
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
                Text(
                  "DO YOU WANT TO INITIALIZE THE '$cycleName' TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
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
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
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
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: isCompact ? null : 12.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha : 0.1),
                            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha : 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "ACTIVATE",
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                              color: Colors.greenAccent,
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

  Future<bool?> _showActivateIncompleteCycleWarning(String currentName, String newName) async {
    return showDialog<bool>(
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
                    Icons.warning_amber_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "INCOMPLETE CYCLE",
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "YOUR CURRENT CYCLE '${currentName.toUpperCase()}' IS NOT YET COMPLETE. ACTIVATING '${newName.toUpperCase()}' WILL MOVE THE INCOMPLETE PROTOCOL TO YOUR LOGS. PROCEED?",
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
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
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
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
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
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha : 0.1),
                            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                            border: Border.all(color: AppColors.crimson.withValues(alpha : 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "ACTIVATE",
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
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

  Future<bool?> _showDeleteCycleConfirmation(String cycleName) async {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE CYCLE",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THE '$cycleName' PROTOCOL FROM YOUR LOGS?",
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < kMobileBreakpoint;
        final double hPad = !isCompact
            ? (width - kMaxContentWidth).clamp(24.0, double.infinity) / 2
            : 8.w;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 24.h : 20.0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.white,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  context.go(AppRoutes.tracker);
                                }
                              },
                            ),
                            Expanded(
                              child: Text(
                                'HIT TRACKER',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h2.adaptive(context).copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.textSecondary,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: _showSystemInstructions,
                            ),
                          ],
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.crimson,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelColor: AppColors.textSecondary,
                      labelColor: AppColors.crimson,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: "LOGS"),
                        Tab(text: "TRENDS"),
                        Tab(text: "LIBRARY"),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRecordsTab(isCompact),
                    _buildTrendsTab(isCompact),
                    _buildLibraryTab(isCompact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordsTab(bool isCompact) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final activeCycle = provider.activeCycle;
        final history = provider.cycleHistory;

        return EliteRefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 700;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- LEFT COLUMN: ACTIVE CYCLE ---
                    Expanded(
                      child: ListView(
                        primary: false,
                        padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader("ACTIVE CYCLE", isCompact),
                              // Spacer to match the filter icon's height on the right
                              SizedBox(
                                width: isCompact ? 20.r : 18.0,
                                height: isCompact ? 20.r : 18.0,
                              ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          if (activeCycle != null)
                            _buildRecordsSlidableCard(
                              cycle: activeCycle,
                              status: "IN PROGRESS",
                              progression: provider.calculateCycleProgression(activeCycle.id),
                              totalVolume: _calculateTotalCycleVolume(activeCycle, provider.logs),
                              startDate: _getCycleStartDate(activeCycle),
                              endDate: _getCycleEndDate(activeCycle),
                              isCompact: isCompact,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WorkoutListScreen(cycleId: activeCycle.id, cycleName: activeCycle.name),
                                  ),
                                );
                              },
                            )
                          else
                            _buildEmptyActiveState(isCompact),
                        ],
                      ),
                    ),
                    VerticalDivider(color: AppColors.white.withValues(alpha : 0.05), width: 1),
                    // --- RIGHT COLUMN: CYCLE LOGS ---
                    Expanded(
                      child: ListView(
                        primary: false,
                        padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader("CYCLE LOGS", isCompact),
                              IconButton(
                                onPressed: _openFilterSheet,
                                icon: Icon(
                                  _historyFilter.isInitial
                                      ? Icons.filter_list_rounded
                                      : Icons.filter_list_off_rounded,
                                  color: _historyFilter.isInitial ? AppColors.crimson : Colors.orangeAccent,
                                  size: isCompact ? 20.r : 18.0,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "Filter Logs",
                              ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          ..._buildHistoryList(provider, history, isCompact),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // --- MOBILE: SINGLE COLUMN ---
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                children: [
                  _buildSectionHeader("ACTIVE CYCLE", isCompact),
                  SizedBox(height: isCompact ? 16.h : 12.0),
                  if (activeCycle != null)
                    _buildRecordsSlidableCard(
                      cycle: activeCycle,
                      status: "IN PROGRESS",
                      progression: provider.calculateCycleProgression(activeCycle.id),
                      totalVolume: _calculateTotalCycleVolume(activeCycle, provider.logs),
                      startDate: _getCycleStartDate(activeCycle),
                      endDate: _getCycleEndDate(activeCycle),
                      isCompact: isCompact,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WorkoutListScreen(cycleId: activeCycle.id, cycleName: activeCycle.name),
                          ),
                        );
                      },
                    )
                  else
                    _buildEmptyActiveState(isCompact),
                  SizedBox(height: isCompact ? 32.h : 24.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("CYCLE LOGS", isCompact),
                      IconButton(
                        onPressed: _openFilterSheet,
                        icon: Icon(
                          _historyFilter.isInitial
                              ? Icons.filter_list_rounded
                              : Icons.filter_list_off_rounded,
                          color: _historyFilter.isInitial ? AppColors.crimson : Colors.orangeAccent,
                          size: isCompact ? 20.r : 18.0,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "Filter Logs",
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 16.h : 12.0),
                  ..._buildHistoryList(provider, history, isCompact),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildHistoryList(CycleProvider provider, List<TrainingCycle> history, bool isCompact) {
    if (history.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 16.0),
          child: Center(
            child: Text(
              "NO COMPLETED CYCLES",
              style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                color: AppColors.textSecondary.withValues(alpha : 0.4),
              ),
            ),
          ),
        )
      ];
    }

    final filteredHistory = history.where((cycle) {
      if (_historyFilter.selectedCycleNames.isNotEmpty &&
          !_historyFilter.selectedCycleNames.contains(cycle.name)) {
        return false;
      }
      final startDate = _getCycleStartDate(cycle);
      if (_historyFilter.dateRange != null) {
        if (startDate == null) return false;
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final filterStart = DateTime(_historyFilter.dateRange!.start.year, _historyFilter.dateRange!.start.month, _historyFilter.dateRange!.start.day);
        final filterEnd = DateTime(_historyFilter.dateRange!.end.year, _historyFilter.dateRange!.end.month, _historyFilter.dateRange!.end.day);
        if (start.isBefore(filterStart) || start.isAfter(filterEnd)) return false;
      }
      if (_historyFilter.year != null && (startDate == null || startDate.year != _historyFilter.year)) return false;
      if (_historyFilter.month != null && (startDate == null || startDate.month != _historyFilter.month)) return false;
      if (_historyFilter.minStrength != null || _historyFilter.maxStrength != null ||
          _historyFilter.minVolume != null || _historyFilter.maxVolume != null) {
        final prog = provider.calculateCycleProgression(cycle.id);
        final totalVol = _calculateTotalCycleVolume(cycle, provider.logs);
        if (_historyFilter.minStrength != null && (prog['strength'] ?? 0) * 100 < _historyFilter.minStrength!) return false;
        if (_historyFilter.maxStrength != null && (prog['strength'] ?? 0) * 100 > _historyFilter.maxStrength!) return false;
        if (_historyFilter.minVolume != null && totalVol < _historyFilter.minVolume!) return false;
        if (_historyFilter.maxVolume != null && totalVol > _historyFilter.maxVolume!) return false;
      }
      return true;
    }).toList();

    final sortedHistory = List<TrainingCycle>.from(filteredHistory);
    sortedHistory.sort((a, b) {
      final dateA = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _historyFilter.isDescending ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    if (sortedHistory.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 40.h : 32.0),
          child: Center(
            child: Text(
              "NO CYCLES MATCHING FILTERS",
              style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                color: AppColors.textSecondary.withValues(alpha : 0.4),
              ),
            ),
          ),
        )
      ];
    }

    return sortedHistory.map((cycle) {
      final totalWorkouts = cycle.workouts.length;
      final completedWorkouts = cycle.workouts.where((w) => w.status == WorkoutStatus.completed).length;
      final bool isActuallyFinished = totalWorkouts > 0 && completedWorkouts == totalWorkouts;

      return _buildRecordsSlidableCard(
        cycle: cycle,
        status: isActuallyFinished ? "FINISHED" : "INCOMPLETE",
        progression: provider.calculateCycleProgression(cycle.id),
        totalVolume: _calculateTotalCycleVolume(cycle, provider.logs),
        startDate: _getCycleStartDate(cycle),
        endDate: _getCycleEndDate(cycle),
        isCompact: isCompact,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WorkoutListScreen(cycleId: cycle.id, cycleName: cycle.name)),
          );
        },
      );
    }).toList();
  }

  Widget _buildEmptyActiveState(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.radio_button_off, color: AppColors.textSecondary, size: isCompact ? 40.r : 32.0),
          SizedBox(height: isCompact ? 16.h : 12.0),
          Text(
            "NO ACTIVE CYCLE DETECTED",
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6.0),
          Text(
            "SYSTEM REQUIRES AN ACTIVE ROUTINE TO TRACK PROGRESSION.",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: isCompact ? 20.h : 16.0),
          GestureDetector(
            onTap: () => _tabController.animateTo(2),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 16.0, vertical: isCompact ? 12.h : 10.0),
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha : 0.1),
                borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
                border: Border.all(color: AppColors.crimson),
              ),
              child: Text(
                "GO TO LIBRARY",
                style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(bool isCompact) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final List<TrainingCycle> cycles = provider.cycles.where((c) => c.status == CycleStatus.finished).toList();
        
        if (cycles.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Text(
                      "COMPLETE CYCLES TO VIEW TRENDS",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.textSecondary.withValues(alpha : 0.3),
                letterSpacing: 1,
              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        }

        final sortedCycles = List<TrainingCycle>.from(cycles)
          ..sort((a, b) => (a.startedAt ?? DateTime.now()).compareTo(b.startedAt ?? DateTime.now()));
        
        final List<DateTime> sortedDates = sortedCycles.map((c) => _getCycleEndDate(c) ?? c.startedAt ?? DateTime.now()).toList();

        final Map<String, List<double?>> aggregatedData = {
          "strength": sortedCycles.map((c) => _calculateCycleAbsoluteStrength(c, provider.logs)).toList(),
          "volume": sortedCycles.map((c) => _calculateTotalCycleVolume(c, provider.logs)).toList(),
        };

        final double width = MediaQuery.sizeOf(context).width;
        final bool isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
        final bool isTabletOrFoldable = width >= 600;
        final bool isWideLandscape = isTabletOrFoldable && isLandscape;

        Widget buildTrendAndOverlayContent() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CycleAnalyticalGraph(
                dates: sortedDates,
                data: aggregatedData,
                visibleMetrics: provider.visibleMetrics,
                onPointSelected: (idx) {},
                isCompact: isCompact,
              ),
              SizedBox(height: isCompact ? 32.h : 24.0),
              _buildSectionHeader("METRIC OVERLAY", isCompact),
              SizedBox(height: isCompact ? 16.h : 12.0),
              Wrap(
                spacing: isCompact ? 10.w : 10.0,
                runSpacing: isCompact ? 10.h : 10.0,
                children: [
                  _buildMetricToggle("STRENGTH", "strength", AppColors.crimson, provider, isCompact),
                  _buildMetricToggle("VOLUME", "volume", Colors.orangeAccent, provider, isCompact),
                ],
              ),
            ],
          );
        }

        Widget buildComparisonContent() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("DATA COMPARISON", isCompact),
              SizedBox(height: isCompact ? 16.h : 12.0),
              CycleComparisonWidget(
                idx1: _comparisonIdx1,
                idx2: _comparisonIdx2,
                dates: sortedDates,
                data: aggregatedData,
                isCompact: isCompact,
                onPointAChanged: (val) => setState(() => _comparisonIdx1 = val),
                onPointBChanged: (val) => setState(() => _comparisonIdx2 = val),
              ),
            ],
          );
        }

        return EliteRefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: LockedAnalyticsOverlay(
            unlockKey: 'cycle_trend_analytics',
            isCompact: isCompact,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
              child: isWideLandscape 
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: buildTrendAndOverlayContent(),
                        ),
                        SizedBox(width: 32.0),
                        Expanded(
                          flex: 4,
                          child: buildComparisonContent(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildTrendAndOverlayContent(),
                        SizedBox(height: isCompact ? 40.h : 32.0),
                        buildComparisonContent(),
                        SizedBox(height: isCompact ? 40.h : 32.0),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricToggle(String label, String key, Color color, CycleProvider provider, bool isCompact) {
    final bool isActive = provider.visibleMetrics.contains(key);
    return GestureDetector(
      onTap: () {
        final current = Set<String>.from(provider.visibleMetrics);
        if (isActive) {
          current.remove(key);
        } else {
          current.add(key);
        }
        provider.setVisibleMetrics(current);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 12.0, vertical: isCompact ? 10.h : 8.0),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha : 0.1) : AppColors.surfaceLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isCompact ? 8.r : 6.0,
              height: isCompact ? 8.r : 6.0,
              decoration: BoxDecoration(
                color: isActive ? color : AppColors.textSecondary.withValues(alpha : 0.3),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: isCompact ? 10.w : 8.0),
            Text(
              label,
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: isActive ? AppColors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryTab(bool isCompact) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final templates = provider.libraryTemplates;
        final defaultTemplates = templates.where((t) => t.isDefault).toList();
        final customTemplates = templates.where((t) => !t.isDefault).toList();

        return EliteRefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 700;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                        children: [
                          _buildSectionHeader("RUGGED DEFAULTS", isCompact),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          ...defaultTemplates.map((t) => _buildLibrarySlidableCard(cycle: t, status: "DEFAULT", isDefaultTemplate: true, isCompact: isCompact, onTap: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CycleDetailViewScreen(cycleId: t.id, cycleName: t.name, isModifiable: false))); if (result == true && mounted) _tabController.animateTo(0); })),
                        ],
                      ),
                    ),
                    VerticalDivider(color: AppColors.white.withValues(alpha : 0.05), width: 1),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                        children: [
                          _buildSectionHeader("CUSTOM CYCLES", isCompact),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          _buildAddCycleButton(isCompact),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          ...customTemplates.map((t) => _buildLibrarySlidableCard(
                                cycle: t,
                                status: "CUSTOM",
                                isDefaultTemplate: false,
                                isCompact: isCompact,
                                onTap: () async {
                                  final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => CycleDetailViewScreen(
                                              cycleId: t.id,
                                              cycleName: t.name,
                                              isModifiable: true)));
                                  if (result == true && mounted) _tabController.animateTo(0);
                                },
                              )),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final visibleDefault = _isDefaultExpanded ? defaultTemplates : defaultTemplates.take(2).toList();
              final visibleCustom = _isCustomExpanded ? customTemplates : customTemplates.take(2).toList();

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.fastOutSlowIn,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildSectionHeader("RUGGED DEFAULTS", isCompact), if (defaultTemplates.length > 2) _buildShowMoreToggle(isExpanded: _isDefaultExpanded, isCompact: isCompact, onTap: () => setState(() => _isDefaultExpanded = !_isDefaultExpanded))]),
                        SizedBox(height: isCompact ? 16.h : 12.0),
                        ...visibleDefault.map((t) => _buildLibrarySlidableCard(cycle: t, status: "DEFAULT", isDefaultTemplate: true, isCompact: isCompact, onTap: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CycleDetailViewScreen(cycleId: t.id, cycleName: t.name, isModifiable: false))); if (result == true && mounted) _tabController.animateTo(0); })),
                      ],
                    ),
                  ),
                  SizedBox(height: isCompact ? 32.h : 24.0),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.fastOutSlowIn,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildSectionHeader("CUSTOM CYCLES", isCompact), if (customTemplates.length > 2) _buildShowMoreToggle(isExpanded: _isCustomExpanded, isCompact: isCompact, onTap: () => setState(() => _isCustomExpanded = !_isCustomExpanded))]),
                        SizedBox(height: isCompact ? 16.h : 12.0),
                        _buildAddCycleButton(isCompact),
                        SizedBox(height: isCompact ? 16.h : 12.0),
                        ...visibleCustom.map((t) => _buildLibrarySlidableCard(
                              cycle: t,
                              status: "CUSTOM",
                              isDefaultTemplate: false,
                              isCompact: isCompact,
                              onTap: () async {
                                final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => CycleDetailViewScreen(
                                            cycleId: t.id,
                                            cycleName: t.name,
                                            isModifiable: true)));
                                if (result == true && mounted) _tabController.animateTo(0);
                              },
                            )),
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

  Widget _buildShowMoreToggle({required bool isExpanded, required VoidCallback onTap, required bool isCompact}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isExpanded ? "SHOW LESS" : "SHOW MORE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha : 0.4), fontWeight: FontWeight.w500, letterSpacing: 1.5)),
          SizedBox(width: isCompact ? 4.w : 4.0),
          Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary.withValues(alpha : 0.4), size: isCompact ? 16.r : 14.0),
        ],
      ),
    );
  }

  Widget _buildLibrarySlidableCard({required TrainingCycle cycle, required String status, required bool isDefaultTemplate, VoidCallback? onTap, required bool isCompact}) {
    return Dismissible(
      key: Key(cycle.id + status),
      direction: isDefaultTemplate ? DismissDirection.endToStart : DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd && !isDefaultTemplate) return await _showDeleteCycleConfirmation(cycle.name);
        if (dir == DismissDirection.endToStart) {
          final provider = context.read<CycleProvider>();
          final active = provider.activeCycle;
          
          bool activated = false;
          if (active != null) {
            if (!active.isReadyToFinish) {
              final result = await _showActivateIncompleteCycleWarning(active.name, cycle.name);
              activated = result ?? false;
            } else {
              final result = await _showActivateCycleConfirmation(cycle.name);
              activated = result ?? false;
            }
          } else {
            final result = await _showActivateCycleConfirmation(cycle.name);
            activated = result ?? false;
          }

          if (activated) { 
            await provider.activateCycle(cycle.id); 
            if (mounted) { 
              EliteSnackbar.show(context, "Cycle '${cycle.name}' Activated"); 
              _tabController.animateTo(0); 
            } 
          }
          return false;
        }
        return false;
      },
      onDismissed: (dir) { if (dir == DismissDirection.startToEnd) context.read<CycleProvider>().deleteCycle(cycle.id); },
      background: !isDefaultTemplate ? Container(alignment: Alignment.centerLeft, padding: EdgeInsets.only(left: isCompact ? 24.w : 20.0), margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0)), child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: isCompact ? 28.r : 24.0)) : const SizedBox.shrink(),
      secondaryBackground: Container(alignment: Alignment.centerRight, padding: EdgeInsets.only(right: isCompact ? 24.w : 20.0), margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0)), child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: isCompact ? 28.r : 24.0)),
      child: _buildStandardCycleCard(cycle: cycle, status: status, onTap: onTap, isCompact: isCompact),
    );
  }

  Widget _buildRecordsSlidableCard({required TrainingCycle cycle, required String status, Map<String, double>? progression, double? totalVolume, DateTime? startDate, DateTime? endDate, VoidCallback? onTap, required bool isCompact}) {
    return Dismissible(
      key: Key(cycle.id + status),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (dir) async => await _showDeleteCycleConfirmation(cycle.name),
      onDismissed: (dir) { context.read<CycleProvider>().deleteCycle(cycle.id); },
      background: Container(alignment: Alignment.centerLeft, padding: EdgeInsets.only(left: isCompact ? 24.w : 20.0), margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0)), child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: isCompact ? 28.r : 24.0)),
      child: _buildStandardCycleCard(cycle: cycle, status: status, progression: progression, totalVolume: totalVolume, startDate: startDate, endDate: endDate, onTap: onTap, isCompact: isCompact),
    );
  }

  Widget _buildStandardCycleCard({required TrainingCycle cycle, required String status, Map<String, double>? progression, double? totalVolume, DateTime? startDate, DateTime? endDate, VoidCallback? onTap, required bool isCompact}) {
    final bool isExpanded = _expandedCycleIds.contains(cycle.id);
    final bool isActive = status == "ACTIVE" || status == "IN PROGRESS";
    final bool isFinished = status == "FINISHED";
    final bool isIncomplete = status.toUpperCase() == "INCOMPLETE";
    final double strength = progression?['strength'] ?? 0.0;
    final double volumeProg = progression?['volume'] ?? 0.0;
    final bool hasProgression = strength != 0 || volumeProg != 0;
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
      decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha : 0.2), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [if (isActive) Container(width: isCompact ? 8.r : 8.0, height: isCompact ? 8.r : 8.0, margin: EdgeInsets.only(right: isCompact ? 12.w : 10.0), decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle)), Expanded(child: Text(cycle.name.toUpperCase(), style: AppTextStyles.h3.adaptive(context).copyWith(letterSpacing: 1.2, color: AppColors.white, fontWeight: FontWeight.w500)))]),
                            SizedBox(height: isCompact ? 8.h : 6.0),
                            Text(
                              cycle.description.toUpperCase(),
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary.withValues(alpha : 0.4),
                                letterSpacing: 1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (cycle.sharedBy != null) ...[
                              SizedBox(height: isCompact ? 10.h : 6.0),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: isCompact ? 10.w : 8.0, vertical: isCompact ? 6.h : 4.0),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha : 0.1),
                                  borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
                                  border: Border.all(color: Colors.blueAccent.withValues(alpha : 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.share_rounded, color: Colors.blueAccent, size: isCompact ? 14.r : 10.0),
                                    SizedBox(width: isCompact ? 6.w : 4.0),
                                    Text(
                                      "SHARED BY ${cycle.sharedBy!.toUpperCase()}",
                                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: isCompact ? 16.h : 12.0),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 10.0, vertical: isCompact ? 6.h : 4.0),
                                  decoration: BoxDecoration(
                                    color: (isActive ? AppColors.crimson : isFinished ? AppColors.success : isIncomplete ? Colors.orangeAccent : AppColors.surfaceLight).withValues(alpha : 0.1),
                                    borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
                                    border: Border.all(color: (isActive ? AppColors.crimson : isFinished ? AppColors.success : isIncomplete ? Colors.orangeAccent : AppColors.white.withValues(alpha : 0.1)).withValues(alpha : 0.3)),
                                  ),
                                  child: Text(
                                    status,
                                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                      color: isActive ? AppColors.crimson : isFinished ? AppColors.success : isIncomplete ? Colors.orangeAccent : AppColors.white,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (hasProgression && strength != 0) ...[
                        SizedBox(width: isCompact ? 16.w : 12.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center, 
                          children: [
                            Text(
                              "STRENGTH", 
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary.withValues(alpha : 0.3), 
                                fontWeight: FontWeight.w500, 
                                letterSpacing: 1
                              )
                            ), 
                            Text(
                              "${strength > 0 ? '+' : ''}${(strength * 100).toStringAsFixed(1)}%", 
                              style: AppTextStyles.h2.adaptive(context).copyWith(
                                color: strength > 0 ? AppColors.success : Colors.redAccent, 
                                fontWeight: FontWeight.w500,
                              )
                            )
                          ]
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasProgression || (totalVolume != null && totalVolume > 0) || startDate != null) ...[
            Padding(padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 20.0), child: Divider(color: AppColors.white.withValues(alpha : 0.05), height: 1)),
            GestureDetector(onTap: () => setState(() { if (isExpanded) {
              _expandedCycleIds.remove(cycle.id);
            } else {
              _expandedCycleIds.add(cycle.id);
            } }), child: Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 10.0), color: Colors.transparent, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(isExpanded ? "COLLAPSE DATA" : "SHOW PERFORMANCE DATA", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha : 0.4), letterSpacing: 2, fontWeight: FontWeight.w500)), SizedBox(width: isCompact ? 8.w : 6.0), AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 300), child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary.withValues(alpha : 0.4), size: isCompact ? 16.r : 14.0))]))),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              alignment: Alignment.topCenter,
              child: isExpanded ? Container(padding: EdgeInsets.fromLTRB(isCompact ? 24.w : 20.0, 0, isCompact ? 24.w : 20.0, isCompact ? 24.h : 20.0), child: Container(padding: EdgeInsets.all(isCompact ? 20.r : 16.0), decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha : 0.3), borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (volumeProg != 0) ...[Text("TONNAGE CHANGE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white, fontWeight: FontWeight.w500, letterSpacing: 1)), SizedBox(height: isCompact ? 8.h : 6.0), Text("${volumeProg > 0 ? '+' : ''}${(volumeProg * 100).toStringAsFixed(1)}%", style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: volumeProg > 0 ? AppColors.success : AppColors.crimson, fontWeight: FontWeight.w500)), if (totalVolume != null && totalVolume > 0) SizedBox(height: isCompact ? 12.h : 10.0)], if (totalVolume != null && totalVolume > 0) ...[Text("TOTAL TONNAGE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white, fontWeight: FontWeight.w500, letterSpacing: 1)), SizedBox(height: isCompact ? 4.h : 2.0), Text("${totalVolume >= 1 ? totalVolume.toStringAsFixed(2) : totalVolume.toStringAsFixed(3)} T", style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.white.withValues(alpha : 0.9), fontWeight: FontWeight.w500))]]) , if (startDate != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [_dateRow(context, "STARTED", startDate, isCompact), SizedBox(height: isCompact ? 8.h : 6.0), _dateRow(context, "ENDED", endDate ?? startDate, isCompact)])]))) : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddCycleButton(bool isCompact) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCycleScreen()));
        if (result == true && mounted) _tabController.animateTo(0);
      },
      child: Container(
        height: isCompact ? 56.h : 48.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.crimson.withValues(alpha : 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(color: AppColors.crimson, width: 1.5),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: AppColors.crimson, size: isCompact ? 20.r : 18.0),
              SizedBox(width: isCompact ? 8.w : 6.0),
              Text(
                'CREATE CUSTOM CYCLE',
                style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateRow(BuildContext context, String label, DateTime date, bool isCompact) { return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha : 0.4), fontWeight: FontWeight.w500, letterSpacing: 0.5)), Text(DateFormat('MMM dd, yyyy').format(date).toUpperCase(), style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white, fontWeight: FontWeight.w500))]); }
  DateTime? _getCycleStartDate(TrainingCycle cycle) { final completed = cycle.workouts.where((w) => w.status == WorkoutStatus.completed && w.completedAt != null).toList(); if (completed.isEmpty) return null; completed.sort((a, b) => a.completedAt!.compareTo(b.completedAt!)); return completed.first.completedAt; }
  DateTime? _getCycleEndDate(TrainingCycle cycle) { final completed = cycle.workouts.where((w) => w.status == WorkoutStatus.completed && w.completedAt != null).toList(); if (completed.isEmpty) return null; completed.sort((a, b) => a.completedAt!.compareTo(b.completedAt!)); return completed.last.completedAt; }
  double _calculateTotalCycleVolume(TrainingCycle cycle, List<ExerciseLog> logs) { double totalKg = 0; final exerciseIds = cycle.workouts.expand((w) => w.exercises.map((e) => e.id)).toSet(); final cycleLogs = logs.where((l) => exerciseIds.contains(l.exerciseId)).toList(); for (var log in cycleLogs) { totalKg += log.weightKg * log.positiveReps; } return totalKg / 1000.0; }

  double _calculateCycleAbsoluteStrength(TrainingCycle cycle, List<ExerciseLog> logs) {
    double totalStrength = 0;
    int count = 0;
    for (var workout in cycle.workouts) {
      for (var exercise in workout.exercises) {
        final exLogs = logs.where((l) => l.exerciseId == exercise.id).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (exLogs.isNotEmpty) {
          final l = exLogs.first;
          if (l.weightKg > 0 && l.positiveReps > 0) {
            totalStrength += l.weightKg / (1.0278 - (0.0278 * l.positiveReps));
            count++;
          }
        }
      }
    }
    return count > 0 ? totalStrength : 0.0;
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

  void _openFilterSheet() {
    final provider = context.read<CycleProvider>();
    final history = provider.cycleHistory;
    final uniqueNames = history.map((c) => c.name).toSet().toList()..sort();
    final uniqueYears = history.map((c) => _getCycleStartDate(c)?.year).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => _CycleFilterSheet(
        isSideSheet: isSideSheet,
        initialFilter: _historyFilter, 
        uniqueNames: uniqueNames, 
        uniqueYears: uniqueYears, 
        onApply: (newFilter) { setState(() { _historyFilter = newFilter; }); }
      ),
    );
  }
}

enum _DateFilterType { all, range, monthYear }

class _CycleFilterSheet extends StatefulWidget {
  final CycleFilter initialFilter;
  final List<String> uniqueNames;
  final List<int> uniqueYears;
  final Function(CycleFilter) onApply;
  final bool isSideSheet;

  const _CycleFilterSheet({required this.initialFilter, required this.uniqueNames, required this.uniqueYears, required this.onApply, this.isSideSheet = false});
  @override
  State<_CycleFilterSheet> createState() => _CycleFilterSheetState();
}

class _CycleFilterSheetState extends State<_CycleFilterSheet> {
  late CycleFilter _currentFilter;
  _DateFilterType _dateFilterType = _DateFilterType.all;
  final TextEditingController _minStrengthController = TextEditingController();
  final TextEditingController _maxStrengthController = TextEditingController();
  final TextEditingController _minVolumeController = TextEditingController();
  final TextEditingController _maxVolumeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    if (_currentFilter.dateRange != null) { _dateFilterType = _DateFilterType.range; } 
    else if (_currentFilter.year != null) { _dateFilterType = _DateFilterType.monthYear; }
    _minStrengthController.text = _currentFilter.minStrength?.toString() ?? "";
    _maxStrengthController.text = _currentFilter.maxStrength?.toString() ?? "";
    _minVolumeController.text = _currentFilter.minVolume?.toString() ?? "";
    _maxVolumeController.text = _currentFilter.maxVolume?.toString() ?? "";
  }

  @override
  void dispose() {
    _minStrengthController.dispose();
    _maxStrengthController.dispose();
    _minVolumeController.dispose();
    _maxVolumeController.dispose();
    super.dispose();
  }

  void _updateFilter(CycleFilter newFilter) { setState(() { _currentFilter = newFilter; }); }

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
              padding: EdgeInsets.fromLTRB(
                isCompact ? 24.w : 24.0, 
                widget.isSideSheet ? 0 : 8.0, 
                isCompact ? 24.w : 24.0, 
                MediaQuery.of(context).viewInsets.bottom + (isCompact ? 24.h : 24.0)
              ),
              decoration: BoxDecoration(
                color: AppColors.surface, 
                borderRadius: widget.isSideSheet 
                  ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                  : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)), 
                border: Border.all(color: AppColors.white.withValues(alpha : 0.05))
              ),
              child: Column(
                mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isSideSheet) SizedBox(height: isCompact ? 24.h : 24.0),
                  if (!widget.isSideSheet) _buildHandle(isCompact),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      Text("LOG FILTERS", style: AppTextStyles.h3.adaptive(context).copyWith(color: AppColors.white)), 
                      Row(
                        children: [
                          TextButton(onPressed: () { setState(() { _currentFilter = CycleFilter(); _dateFilterType = _DateFilterType.all; _minStrengthController.clear(); _maxStrengthController.clear(); _minVolumeController.clear(); _maxVolumeController.clear(); }); }, child: Text("RESET", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.crimson, fontWeight: FontWeight.w500))),
                          if (widget.isSideSheet)
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                        ],
                      )
                    ]
                  ),
                  SizedBox(height: isCompact ? 24.h : 20.0),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel("SORT ORDER", isCompact),
                          Row(children: [_buildToggleButton(label: "NEWEST FIRST", isSelected: _currentFilter.isDescending, onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: true)), isCompact: isCompact), SizedBox(width: isCompact ? 12.w : 12.0), _buildToggleButton(label: "OLDEST FIRST", isSelected: !_currentFilter.isDescending, onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: false)), isCompact: isCompact)]),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionLabel("DATE FILTER", isCompact),
                          Row(children: [_buildToggleButton(label: "ALL", isSelected: _dateFilterType == _DateFilterType.all, onTap: () { setState(() => _dateFilterType = _DateFilterType.all); _updateFilter(_currentFilter.copyWith(dateRange: null, year: null, month: null)); }, isCompact: isCompact), SizedBox(width: isCompact ? 8.w : 8.0), _buildToggleButton(label: "MONTH/YEAR", isSelected: _dateFilterType == _DateFilterType.monthYear, onTap: () { setState(() => _dateFilterType = _DateFilterType.monthYear); _updateFilter(_currentFilter.copyWith(dateRange: null)); }, isCompact: isCompact), SizedBox(width: isCompact ? 8.w : 8.0), _buildToggleButton(label: "CUSTOM RANGE", isSelected: _dateFilterType == _DateFilterType.range, onTap: () { setState(() => _dateFilterType = _DateFilterType.range); _updateFilter(_currentFilter.copyWith(year: null, month: null)); }, isCompact: isCompact)]),
                          if (_dateFilterType == _DateFilterType.range) ...[
                            SizedBox(height: isCompact ? 16.h : 16.0),
                            GestureDetector(onTap: () async { final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDateRange: _currentFilter.dateRange, builder: (ctx, child) { final mq = MediaQuery.of(ctx); return Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(primary: AppColors.crimson, onPrimary: Colors.white, secondary: AppColors.crimson, onSecondary: Colors.white, secondaryContainer: AppColors.crimson.withValues(alpha: 0.25), onSecondaryContainer: Colors.white, surface: AppColors.surface, onSurface: Colors.white), datePickerTheme: DatePickerThemeData(headerBackgroundColor: AppColors.surface, headerForegroundColor: Colors.white, backgroundColor: AppColors.surface, rangeSelectionBackgroundColor: AppColors.crimson.withValues(alpha: 0.25), rangePickerHeaderBackgroundColor: AppColors.surface, rangePickerHeaderForegroundColor: Colors.white, todayBorder: const BorderSide(color: AppColors.crimson), todayForegroundColor: WidgetStateProperty.all(AppColors.crimson), dayOverlayColor: WidgetStateProperty.all(AppColors.crimson.withValues(alpha: 0.1)))), child: Dialog(insetPadding: EdgeInsets.symmetric(horizontal: mq.size.width > 600 ? 80.0 : 16.0, vertical: mq.size.height > 600 ? 60.0 : 20.0), backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)), clipBehavior: Clip.antiAlias, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560), child: child!))); }); if (range != null) { _updateFilter(_currentFilter.copyWith(dateRange: range)); } }, child: Container(padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 12.h : 12.0), decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha : 0.3), borderRadius: BorderRadius.circular(isCompact ? 12.r : 12.0), border: Border.all(color: AppColors.white.withValues(alpha : 0.05))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_currentFilter.dateRange == null ? "SELECT DATE RANGE" : "${DateFormat('MMM dd').format(_currentFilter.dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_currentFilter.dateRange!.end)}", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: _currentFilter.dateRange == null ? AppColors.textMuted : AppColors.white)), Icon(Icons.calendar_today_rounded, color: AppColors.crimson, size: isCompact ? 16.r : 16.0)]))),
                          ] else if (_dateFilterType == _DateFilterType.monthYear) ...[
                            SizedBox(height: isCompact ? 16.h : 16.0),
                            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildSectionLabel("YEAR", isCompact), _buildDropdown<int?>(value: _currentFilter.year, items: [const DropdownMenuItem(value: null, child: Text("ALL")), ...widget.uniqueYears.map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))], onChanged: (val) => _updateFilter(_currentFilter.copyWith(year: val, month: val == null ? null : _currentFilter.month)), isCompact: isCompact)])) , SizedBox(width: isCompact ? 16.w : 16.0), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildSectionLabel("MONTH", isCompact), _buildDropdown<int?>(value: _currentFilter.month, items: [const DropdownMenuItem(value: null, child: Text("ALL")), ...List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1)).toUpperCase())))], onChanged: _currentFilter.year == null ? null : (val) => _updateFilter(_currentFilter.copyWith(month: val)), isCompact: isCompact)]))]),
                          ],
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionLabel("CYCLE NAMES", isCompact),
                          Wrap(
                            spacing: isCompact ? 8.w : 8.0,
                            runSpacing: isCompact ? 8.h : 8.0,
                            children: widget.uniqueNames.map((name) {
                              final isSelected = _currentFilter.selectedCycleNames.contains(name);
                              return GestureDetector(
                                onTap: () {
                                  final names = Set<String>.from(_currentFilter.selectedCycleNames);
                                  if (isSelected) {
                                    names.remove(name);
                                  } else {
                                    names.add(name);
                                  }
                                  _updateFilter(_currentFilter.copyWith(selectedCycleNames: names));
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 12.0, vertical: isCompact ? 8.h : 8.0),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.crimson.withValues(alpha : 0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0),
                                    border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha : 0.1)),
                                  ),
                                  child: Text(
                                    name.toUpperCase(),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isSelected ? AppColors.crimson : AppColors.textSecondary,
                                      fontSize: isCompact ? 10.sp : 10.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionLabel("STRENGTH PROGRESSION (%)", isCompact),
                          Row(children: [Expanded(child: _buildTextField(_minStrengthController, "MIN", (val) => _updateFilter(_currentFilter.copyWith(minStrength: double.tryParse(val))), isCompact)), SizedBox(width: isCompact ? 16.w : 16.0), Expanded(child: _buildTextField(_maxStrengthController, "MAX", (val) => _updateFilter(_currentFilter.copyWith(maxStrength: double.tryParse(val))), isCompact))],),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionLabel("TOTAL TONNAGE", isCompact),
                          Row(children: [Expanded(child: _buildTextField(_minVolumeController, "MIN", (val) => _updateFilter(_currentFilter.copyWith(minVolume: double.tryParse(val))), isCompact)), SizedBox(width: isCompact ? 16.w : 16.0), Expanded(child: _buildTextField(_maxVolumeController, "MAX", (val) => _updateFilter(_currentFilter.copyWith(maxVolume: double.tryParse(val))), isCompact))],),
                          SizedBox(height: isCompact ? 32.h : 32.0),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { widget.onApply(_currentFilter); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson, padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 16.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 12.0))), child: Text("APPLY FILTERS", style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(color: Colors.white)))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle(bool isCompact) { return Center(child: Container(margin: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 16.0), width: isCompact ? 40.w : 40.0, height: isCompact ? 4.h : 4.0, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha : 0.2), borderRadius: BorderRadius.circular(2.r)))); }
  Widget _buildSectionLabel(String label, bool isCompact) { return Padding(padding: EdgeInsets.only(bottom: isCompact ? 12.h : 12.0), child: Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textMuted, letterSpacing: 1.5, fontWeight: FontWeight.w500))); }
  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap, required bool isCompact}) { return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0), decoration: BoxDecoration(color: isSelected ? AppColors.crimson.withValues(alpha : 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(isCompact ? 12.r : 12.0), border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha : 0.1))), child: Center(child: Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: isSelected ? AppColors.crimson : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500)))))); }
  Widget _buildDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required void Function(T?)? onChanged, required bool isCompact}) { return Container(padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0), decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha : 0.3), borderRadius: BorderRadius.circular(isCompact ? 12.r : 12.0), border: Border.all(color: AppColors.white.withValues(alpha : 0.05))), child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, items: items, onChanged: onChanged, dropdownColor: AppColors.surface, icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.crimson), isExpanded: true, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white)))); }
  Widget _buildTextField(TextEditingController controller, String hint, Function(String) onChanged, bool isCompact) { return Container(decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha : 0.3), borderRadius: BorderRadius.circular(isCompact ? 12.r : 12.0), border: Border.all(color: AppColors.white.withValues(alpha : 0.05))), child: TextField(controller: controller, onChanged: onChanged, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white), decoration: InputDecoration(hintText: hint, hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 12.h : 12.0)))); }
}

