import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:rugged/features/tracker/calorie/widgets/sheets/calorie_notification_sheet.dart';
import 'package:rugged/features/tracker/calorie/widgets/calorie_analytical_widget.dart';
import 'package:rugged/core/ads/locked_analytics_overlay.dart';
import '../../main_wrapper.dart';
import 'model/saved_meal.dart';
import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:rugged/features/tracker/calorie/widgets/add_meal_sheet.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:rugged/features/tracker/calorie/model/calorie_log.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:rugged/core/constants/dimensions.dart';

class CalorieScreen extends StatefulWidget {
  final int initialTabIndex;
  const CalorieScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CalorieScreen> createState() => _CalorieScreenState();
}

class _CalorieScreenState extends State<CalorieScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  DateTime _selectedHistoryDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;
  final Set<String> _expandedSupplementIds = {};

  // Analytical Tab State
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "calorie";
    _tabController = TabController(
      length: 4, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _pageController = PageController(
      viewportFraction: 0.2,
      initialPage: 0,
    );
    _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _openAddMealSheet(BuildContext context) {
    final provider = context.read<CalorieProvider>();
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => AddMealSheet(
        isSideSheet: isSideSheet,
        savedMeals: provider.savedMeals,
        onSave: (log, saveTemplate, servings, multiplySupps) {
          provider.addLog(log);
          if (saveTemplate) {
            provider.saveMealTemplate(SavedMeal(
              id: Uuid().v4(),
              name: log.mealName,
              foodItems: log.foodItems,
              calories: log.calories,
              protein: log.protein,
              carbs: log.carbs,
              fats: log.fats,
              addedSupplementsJson: log.addedSupplementsJson,
              addedStacksJson: log.addedStacksJson,
              servings: servings,
              multiplySupps: multiplySupps,
            ));
          }
        },
      ),
    );
  }

  Future<void> _showLogPrompt(SavedMeal meal, CalorieProvider provider) async {
    double tempServings = meal.servings;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return StatefulBuilder(
            builder: (context, setDialogState) {
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
                        color: Colors.greenAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_task_rounded, color: Colors.greenAccent, size: isCompact ? 28.r : 24.0),
                    ),
                    SizedBox(height: isCompact ? 16.h : 16.0),
                    Text(
                      "LOG MEAL",
                      style: AppTextStyles.h3.adaptive(context).copyWith(
                        letterSpacing: 1.2
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ADJUST SERVINGS FOR '${meal.name.toUpperCase()}'",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: isCompact ? 24.h : 20.0),
                    Container(
                      padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (tempServings > 0.5) {
                                setDialogState(() => tempServings -= 0.5);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white24),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: tempServings % 1 == 0 ? tempServings.toInt().toString() : tempServings.toStringAsFixed(1),
                                  style: AppTextStyles.h2.adaptive(context).copyWith(
                                    color: AppColors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: "X",
                                  style: AppTextStyles.h2.adaptive(context).copyWith(
                                    color: AppColors.white,
                                    fontSize: 16.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (tempServings < 99) {
                                setDialogState(() => tempServings += 0.5);
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white24),
                          ),
                        ],
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
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                                border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "CANCEL",
                                style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 12.w : 12.0),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, {'servings': tempServings}),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "CONFIRM",
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
          );
        },
      ),
    );

    if (result != null && mounted) {
      final double finalServings = result['servings'];
      final double ratio = finalServings / (meal.servings > 0 ? meal.servings : 1.0);
      final mealId = const Uuid().v4();
      final supplementProvider = context.read<SupplementProvider>();

      List<Map<String, dynamic>> suppsPayload = [];
      if (meal.addedSupplementsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(meal.addedSupplementsJson!);
          for (var item in decoded) {
            if (item is Map) {
              final String id = item['id'];
              double baseAmount = (item['amount'] as num).toDouble();
              if (meal.multiplySupps) {
                 baseAmount = baseAmount / (meal.servings > 0 ? meal.servings : 1.0);
              }
              
              final double newAmount = meal.multiplySupps ? (baseAmount * finalServings) : baseAmount;
              final supp = supplementProvider.library.firstWhere((s) => s.id == id);
              
              await supplementProvider.recordEntry(
                supplement: supp,
                isIntake: true,
                isRestock: false,
                weightAdjustment: -(newAmount * supp.weightPerServing),
                historyDetails: "MEAL LOG: ${meal.name.toUpperCase()} | SUPPLEMENT | $newAmount ${supp.servingUnit.toUpperCase()}",
                timestamp: DateTime.now(),
                sourceId: mealId,
              );
              suppsPayload.add({'id': id, 'amount': newAmount});
            }
          }
        } catch (e) {
          debugPrint("LogPrompt: Supplement Error: $e");
        }
      }

      List<Map<String, dynamic>> stacksPayload = [];
      if (meal.addedStacksJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(meal.addedStacksJson!);
          for (var item in decoded) {
            if (item is Map) {
              final String id = item['id'];
              final Map<String, dynamic> rawAmounts = item['itemAmounts'];
              final Map<String, double> newAmounts = {};

              final stack = supplementProvider.supplementStacks.firstWhere((s) => s.id == id);
              for (var supplement in stack.items) {
                if (!rawAmounts.containsKey(supplement.id)) continue;
                
                double baseAmount = (rawAmounts[supplement.id] as num).toDouble();
                if (meal.multiplySupps) {
                  baseAmount = baseAmount / (meal.servings > 0 ? meal.servings : 1.0);
                }

                final double newAmount = meal.multiplySupps ? (baseAmount * finalServings) : baseAmount;
                await supplementProvider.recordEntry(
                  supplement: supplement,
                  isIntake: true,
                  isRestock: false,
                  weightAdjustment: -(newAmount * supplement.weightPerServing),
                  historyDetails: "MEAL LOG: ${meal.name.toUpperCase()} | STACK: ${stack.name.toUpperCase()} | $newAmount ${supplement.servingUnit.toUpperCase()}",
                  timestamp: DateTime.now(),
                  sourceId: mealId,
                );
                newAmounts[supplement.id] = newAmount;
              }
              stacksPayload.add({'id': id, 'itemAmounts': newAmounts});
            }
          }
        } catch (e) {
          debugPrint("LogPrompt: Stack Error: $e");
        }
      }

      provider.addLog(CalorieLog(
        id: mealId,
        mealName: meal.name,
        foodItems: meal.foodItems,
        calories: (meal.calories * ratio),
        protein: meal.protein != null ? meal.protein! * ratio : null,
        carbs: meal.carbs != null ? meal.carbs! * ratio : null,
        fats: meal.fats != null ? meal.fats! * ratio : null,
        addedSupplementsJson: suppsPayload.isNotEmpty ? jsonEncode(suppsPayload) : null,
        addedStacksJson: stacksPayload.isNotEmpty ? jsonEncode(stacksPayload) : null,
        servings: finalServings,
        timestamp: DateTime.now(),
      ));
      if (!mounted) return;
      EliteSnackbar.show(context, "${meal.name} logged!");
    }
  }

  Future<bool?> _showActionConfirmation({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) async {
    return EliteConfirmDialog.show(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      confirmColor: confirmColor,
      icon: icon,
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
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'CALORIE TRACKER',
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
                                color: Colors.transparent,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: null,
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
                        Tab(text: "TRACKER"),
                        Tab(text: "TRENDS"),
                        Tab(text: "LIBRARY"),
                        Tab(text: "LOGS"),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrackerTab(isCompact),
                    _buildTrendsTab(isCompact),
                    _buildLibraryTab(isCompact),
                    _buildHistoryTab(isCompact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendsTab(bool isCompact) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        if (provider.logs.isEmpty) {
          return Center(
            child: Text(
              "LOG MEALS TO VIEW TRENDS",
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                letterSpacing: 1,
              ),
            ),
          );
        }

        // Sort logs by timestamp
        final sortedLogs = List<CalorieLog>.from(provider.logs)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        final List<DateTime> sortedDates = sortedLogs.map((l) => l.timestamp).toList();

        final Map<String, List<double?>> aggregatedData = {
          "calories": sortedLogs.map((l) => l.calories.toDouble()).toList(),
          "protein": sortedLogs.map((l) => l.protein != null ? l.protein! * 4 : null).toList(),
          "carbs": sortedLogs.map((l) => l.carbs != null ? l.carbs! * 4 : null).toList(),
          "fats": sortedLogs.map((l) => l.fats != null ? l.fats! * 9 : null).toList(),
        };

        final double width = MediaQuery.sizeOf(context).width;
        final bool isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
        final bool isTabletOrFoldable = width >= 600;
        final bool isWideLandscape = isTabletOrFoldable && isLandscape;

        Widget buildTrendAndOverlayContent() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CalorieAnalyticalGraph(
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
                  _buildAnalyticalMetricToggle("CALORIES", "calories", AppColors.crimson, isCompact),
                  _buildAnalyticalMetricToggle("PROTEIN (kcal)", "protein", Colors.blueAccent, isCompact),
                  _buildAnalyticalMetricToggle("CARBS (kcal)", "carbs", Colors.greenAccent, isCompact),
                  _buildAnalyticalMetricToggle("FATS (kcal)", "fats", Colors.orangeAccent, isCompact),
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
              CalorieComparisonWidget(
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
            unlockKey: 'calorie_analytics',
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
                        SizedBox(height: 40.h),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticalMetricToggle(String label, String key, Color color, bool isCompact) {
    final provider = context.watch<CalorieProvider>();
    final bool isActive = provider.visibleMetrics.contains(key);
    return GestureDetector(
      onTap: () {
        final newMetrics = Set<String>.from(provider.visibleMetrics);
        if (isActive) {
          newMetrics.remove(key);
        } else {
          newMetrics.add(key);
        }
        provider.setVisibleMetrics(newMetrics);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 12.0, vertical: isCompact ? 10.h : 8.0),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : AppColors.surfaceLight.withValues(alpha: 0.6),
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
                color: isActive ? color : AppColors.textSecondary.withValues(alpha: 0.3),
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

  Widget _buildTrackerTab(bool isCompact) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        final consumed = provider.consumedCalories;

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
                    // --- LEFT COLUMN: SUMMARY & MACROS ---
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.0),
                            child: _buildSectionHeader("CONSUMED", isCompact),
                          ),
                          SizedBox(height: 12.0),
                          _buildEnergySummary(
                            consumed, 
                            settings.dailyCalorieGoal,
                            provider.proteinTotal,
                            provider.carbsTotal,
                            provider.fatsTotal,
                            isCompact,
                          ),
                          if (settings.trackMacros) ...[
                            SizedBox(height: 24.0),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.0),
                              child: _buildSectionHeader("MACROS", isCompact),
                            ),
                            SizedBox(height: 12.0),
                            _buildMacroSection(
                              provider.proteinTotal,
                              provider.carbsTotal,
                              provider.fatsTotal,
                              isCompact,
                            ),
                          ],
                        ],
                      ),
                    ),
                    VerticalDivider(color: AppColors.white..withValues(alpha: 0.05), width: 1),
                    // --- RIGHT COLUMN: MEAL LOG ---
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(20.0),
                        children: [
                          _buildSectionHeader("MEAL LOG", isCompact),
                          SizedBox(height: 12.0),
                          _buildMealLogSection(context, provider, isCompact),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // --- MOBILE: SINGLE COLUMN ---
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isCompact ? 20.h : 20.0),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
                      child: _buildSectionHeader("CONSUMED", isCompact),
                    ),
                    SizedBox(height: isCompact ? 12.h : 10.0),
                    _buildEnergySummary(
                      consumed, 
                      settings.dailyCalorieGoal,
                      provider.proteinTotal,
                      provider.carbsTotal,
                      provider.fatsTotal,
                      isCompact,
                    ),
                    if (settings.trackMacros) ...[
                      SizedBox(height: 24.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
                        child: _buildSectionHeader("MACROS", isCompact),
                      ),
                      SizedBox(height: isCompact ? 12.h : 10.0),
                      _buildMacroSection(
                        provider.proteinTotal,
                        provider.carbsTotal,
                        provider.fatsTotal,
                        isCompact,
                      ),
                    ],
                    SizedBox(height: 24.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
                      child: _buildMealLogSection(context, provider, isCompact),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLibraryTab(bool isCompact) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final savedMeals = provider.savedMeals;

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
                    // --- LEFT COLUMN: ACTIONS ---
                    Expanded(
                      flex: 4,
                      child: ListView(
                        padding: EdgeInsets.all(20.0),
                        children: [
                          _buildSectionHeader("MEAL ACTIONS", isCompact),
                          SizedBox(height: 20.0),
                          _buildAddMealButton(context, provider, isCompact),
                        ],
                      ),
                    ),
                    VerticalDivider(color: AppColors.white..withValues(alpha: 0.05), width: 1),
                    // --- RIGHT COLUMN: SAVED MEALS ---
                    Expanded(
                      flex: 6,
                      child: savedMeals.isEmpty 
                          ? Center(child: Text("No saved meals in your library.", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary)))
                          : ListView.builder(
                              padding: EdgeInsets.all(20.0),
                              itemCount: savedMeals.length,
                              itemBuilder: (context, index) => _buildSavedMealItem(savedMeals[index], provider, isCompact),
                            ),
                    ),
                  ],
                );
              }

              // --- MOBILE: SINGLE COLUMN ---
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                    child: _buildAddMealButton(context, provider, isCompact),
                  ),
                  Expanded(
                    child: savedMeals.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) => ListView(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              children: [
                                Container(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: Center(
                                    child: Text(
                                      "No saved meals in your library.",
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            itemCount: savedMeals.length,
                            itemBuilder: (context, index) => _buildSavedMealItem(savedMeals[index], provider, isCompact),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAddMealButton(BuildContext context, CalorieProvider provider, bool isCompact) {
    return GestureDetector(
      onTap: () {
        AdaptiveUtils.showAdaptiveSheet(
          context: context,
          sheetBuilder: (sheetContext, isSideSheet) => AddMealSheet(
            isSideSheet: isSideSheet,
            isLibraryOnly: true,
            savedMeals: provider.savedMeals,
            onSave: (log, _, servings, multiplySupps) {
              provider.saveMealTemplate(SavedMeal(
                id: Uuid().v4(),
                name: log.mealName,
                foodItems: log.foodItems,
                calories: log.calories,
                protein: log.protein,
                carbs: log.carbs,
                fats: log.fats,
                addedSupplementsJson: log.addedSupplementsJson,
                addedStacksJson: log.addedStacksJson,
                servings: servings,
                multiplySupps: multiplySupps,
              ));
            },
          ),
        );
      },
      child: Container(
        height: isCompact ? 50.h : 48.0,
        decoration: BoxDecoration(
          color: AppColors.crimson.withValues(alpha: 0.1),
          border: Border.all(
            color: AppColors.crimson.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.crimson,
              size: isCompact ? 20.r : 18.0,
            ),
            SizedBox(width: 8.w),
            Text(
              "ADD A MEAL",
              style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(bool isCompact) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final Set<DateTime> dateSet = provider.logs.map((l) => 
          DateTime(l.timestamp.year, l.timestamp.month, l.timestamp.day)
        ).toSet();
        
        final now = DateTime.now();
        dateSet.add(DateTime(now.year, now.month, now.day));
        
        final historyLogs = provider.logs.where((l) {
          return l.timestamp.year == _selectedHistoryDate.year &&
              l.timestamp.month == _selectedHistoryDate.month &&
              l.timestamp.day == _selectedHistoryDate.day;
        }).toList();

        final consumed = historyLogs.fold(0.0, (sum, l) => sum + l.calories).round();
        final protein = historyLogs.any((l) => l.protein != null) 
            ? historyLogs.fold(0.0, (sum, l) => sum + (l.protein ?? 0.0)) 
            : null;
        final carbs = historyLogs.any((l) => l.carbs != null) 
            ? historyLogs.fold(0.0, (sum, l) => sum + (l.carbs ?? 0.0)) 
            : null;
        final fats = historyLogs.any((l) => l.fats != null) 
            ? historyLogs.fold(0.0, (sum, l) => sum + (l.fats ?? 0.0)) 
            : null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth > 700;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN: CALENDAR (TAKES WHOLE SPACE) ---
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: AppColors.background,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: _buildCustomExpandedCalendar(dateSet, isCompact),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(color: AppColors.white..withValues(alpha: 0.05), width: 1),
                  // --- RIGHT COLUMN: SLIDER + LOGS ---
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildHorizontalCalendar(dateSet, isCompact),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20.0),
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            children: [
                              if (historyLogs.isNotEmpty) ...[
                                _buildEnergySummary(
                                  consumed, 
                                  provider.settings.dailyCalorieGoal,
                                  protein,
                                  carbs,
                                  fats,
                                  isCompact,
                                ),
                                if (provider.settings.trackMacros) ...[
                                  SizedBox(height: 24.0),
                                  _buildMacroSection(protein, carbs, fats, isCompact),
                                ],
                                SizedBox(height: 24.0),
                                _buildSectionHeader("LOGGED MEALS", isCompact),
                                SizedBox(height: 20.0),
                                Column(
                                  children: historyLogs.map((log) => _buildMealCard(log, provider, isCompact)).toList(),
                                ),
                              ] else
                                SizedBox(
                                  height: 400,
                                  child: Center(
                                    child: Text(
                                      "No logs for this date.",
                                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // --- MOBILE: SINGLE COLUMN ---
            if (_isCalendarExpanded) {
              return Container(
                color: AppColors.background,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildCustomExpandedCalendar(dateSet, isCompact),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isCalendarExpanded = false);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final target = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month, _selectedHistoryDate.day);
                          final int dayDiff = today.difference(target).inDays;
                          if (dayDiff >= 0 && dayDiff < 365) {
                            if (_pageController.hasClients) {
                              _pageController.animateToPage(
                                dayDiff, 
                                duration: const Duration(milliseconds: 300), 
                                curve: Curves.easeInOut
                              );
                            }
                          }
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        color: Colors.transparent,
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                          size: 24.r,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildHorizontalCalendar(dateSet, isCompact),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCalendarExpanded = true;
                      _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    color: Colors.transparent,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 24.r,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    children: [
                      if (historyLogs.isNotEmpty) ...[
                        SizedBox(height: 20.h),
                        _buildEnergySummary(
                          consumed, 
                          provider.settings.dailyCalorieGoal,
                          protein,
                          carbs,
                          fats,
                          isCompact,
                        ),
                        if (provider.settings.trackMacros) ...[
                          SizedBox(height: 24.h),
                          _buildMacroSection(protein, carbs, fats, isCompact),
                        ],
                        SizedBox(height: 24.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _buildSectionHeader("LOGGED MEALS", isCompact),
                        ),
                        SizedBox(height: 12.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: historyLogs.map((log) => _buildMealCard(log, provider, isCompact)).toList(),
                          ),
                        ),
                        SizedBox(height: 40.h),
                      ] else
                        SizedBox(
                          height: 300.h,
                          child: Center(
                            child: Text(
                              "No logs for this date.",
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomExpandedCalendar(Set<DateTime> dateSet, bool isCompact) {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final isCurrentMonth = _displayedMonth.year == DateTime.now().year && _displayedMonth.month == DateTime.now().month;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 10.h : 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
                }),
              ),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    useRootNavigator: true,
                    initialDate: _selectedHistoryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
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
                          ),
                          child: child!,
                        ),
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  if (picked != null) {
                    setState(() {
                      _selectedHistoryDate = picked;
                      _displayedMonth = DateTime(picked.year, picked.month);
                    });
                  }
                },
                child: Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth).toUpperCase(),
                  style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                    color: Colors.white, 
                    letterSpacing: 1.5,
                    fontSize: isCompact ? 14.0 : 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: isCurrentMonth ? Colors.white.withValues(alpha: 0.1) : Colors.white),
                onPressed: isCurrentMonth ? null : () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["M", "T", "W", "T", "F", "S", "S"].map((d) => Expanded(
              child: Text(
                d, 
                textAlign: TextAlign.center, 
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: isCompact ? 11.0 : 13.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8.0),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: daysInMonth + (firstDayOfMonth - 1),
            itemBuilder: (context, index) {
              if (index < firstDayOfMonth - 1) return const SizedBox.shrink();
              
              final day = index - (firstDayOfMonth - 1) + 1;
              final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
              final isSelected = date.year == _selectedHistoryDate.year &&
                  date.month == _selectedHistoryDate.month &&
                  date.day == _selectedHistoryDate.day;
              final hasData = dateSet.contains(date);
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture ? null : () {
                  setState(() {
                    _selectedHistoryDate = date;
                  });
                },
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.crimson : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected 
                          ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day.toString(),
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            fontSize: isCompact ? 13.0 : 15.0,
                            color: isSelected 
                                ? Colors.white 
                                : (isFuture ? Colors.white.withValues(alpha: 0.05) : (hasData ? Colors.white : Colors.white.withValues(alpha: 0.2))),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Container(
                          width: 4.0,
                          height: 4.0,
                          decoration: BoxDecoration(
                            color: (hasData && !isSelected) ? AppColors.crimson : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(Set<DateTime> dateSet, bool isCompact) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: isCompact ? 90.h : 80.0,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 8.0),
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
        physics: const PageScrollPhysics(),
        itemCount: 365,
        itemBuilder: (context, index) {
          final dateOnly = today.subtract(Duration(days: index));
          
          final isSelected = dateOnly.year == _selectedHistoryDate.year &&
              dateOnly.month == _selectedHistoryDate.month &&
              dateOnly.day == _selectedHistoryDate.day;
          
          final isToday = dateOnly.day == today.day && 
                          dateOnly.month == today.month && 
                          dateOnly.year == today.year;
          
          final hasData = dateSet.contains(dateOnly);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedHistoryDate = dateOnly);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 6.w : 6.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: isToday && !isSelected 
                    ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(dateOnly).toUpperCase(),
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      fontSize: isCompact ? 10.sp : 10.0,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.2)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isCompact ? 4.h : 4.0),
                  Text(
                    dateOnly.day.toString(),
                    style: AppTextStyles.h3.adaptive(context).copyWith(
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.white : AppColors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: isCompact ? 4.h : 4.0),
                      width: isCompact ? 4.r : 4.0,
                      height: isCompact ? 4.r : 4.0,
                      decoration: const BoxDecoration(
                        color: AppColors.crimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnergySummary(int consumed, int goal, double? protein, double? carbs, double? fats, bool isCompact) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        final int remaining = goal - consumed;
        final bool isOver = remaining < 0;

        final double totalMacros = (protein ?? 0) + (carbs ?? 0) + (fats ?? 0);
        final bool hasMacros = totalMacros > 0;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
          padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$consumed",
                    style: AppTextStyles.h1.adaptive(context).copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    "/ $goal kcal",
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (settings.showRemaining) ...[
                    SizedBox(height: isCompact ? 8.h : 6.0),
                    Text(
                      isOver ? "OVER: ${remaining.abs()} kcal" : "REMAINING: $remaining kcal",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: isOver ? AppColors.crimson : Colors.greenAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(
                height: isCompact ? 90.r : 80.0,
                width: isCompact ? 90.r : 80.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: isCompact ? 32.r : 28.0,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            color: AppColors.crimson,
                            value: consumed.toDouble(),
                            radius: isCompact ? 6.r : 5.0,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            color: AppColors.white.withValues(alpha: 0.05),
                            value: remaining < 0 ? 0 : remaining.toDouble(),
                            radius: isCompact ? 6.r : 5.0,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    if (hasMacros)
                      SizedBox(
                        height: isCompact ? 56.r : 48.0,
                        width: isCompact ? 56.r : 48.0,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: isCompact ? 20.r : 18.0,
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                color: Colors.blueAccent,
                                value: protein ?? 0,
                                radius: isCompact ? 6.r : 5.0,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                color: Colors.greenAccent,
                                value: carbs ?? 0,
                                radius: isCompact ? 6.r : 5.0,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                color: Colors.orangeAccent,
                                value: fats ?? 0,
                                radius: isCompact ? 6.r : 5.0,
                                showTitle: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroSection(double? protein, double? carbs, double? fats, bool isCompact) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        final goal = settings.dailyCalorieGoal;
        
        final targetPro = (goal * (settings.proteinPercent / 100)) / 4;
        final targetCho = (goal * (settings.carbPercent / 100)) / 4;
        final targetFat = (goal * (settings.fatPercent / 100)) / 9;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
          child: Row(
            children: [
              _buildMacroTile("Protein", protein != null ? "${protein.toInt()}g" : "-", "${targetPro.toInt()}g", Colors.blueAccent, isCompact),
              SizedBox(width: isCompact ? 10.w : 10.0),
              _buildMacroTile("Carbs", carbs != null ? "${carbs.toInt()}g" : "-", "${targetCho.toInt()}g", Colors.greenAccent, isCompact),
              SizedBox(width: isCompact ? 10.w : 10.0),
              _buildMacroTile("Fats", fats != null ? "${fats.toInt()}g" : "-", "${targetFat.toInt()}g", Colors.orangeAccent, isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroTile(String label, String value, String target, Color color, bool isCompact) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 14.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(isCompact ? 20.r : 18.0),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
            ),
            Text(
              "/ $target",
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: isCompact ? 4.h : 4.0),
            Text(
              label.toUpperCase(),
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: color,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealLogSection(BuildContext context, CalorieProvider provider, bool isCompact) {
    final todayLogs = provider.logs.where((l) {
      final now = DateTime.now();
      return l.timestamp.year == now.year &&
          l.timestamp.month == now.month &&
          l.timestamp.day == now.day;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAddMealEntryButton(context, provider, isCompact),
        SizedBox(height: isCompact ? 24.h : 20.0),
        _buildSectionHeader("DAILY MEALS", isCompact),
        SizedBox(height: isCompact ? 12.h : 10.0),
        if (todayLogs.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 16.0),
              child: Text(
                "No meals logged today.",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...todayLogs.map((log) => _buildMealCard(log, provider, isCompact)),
      ],
    );
  }

  Widget _buildAddMealEntryButton(BuildContext context, CalorieProvider provider, bool isCompact) {
    return GestureDetector(
      onTap: () => _openAddMealSheet(context),
      child: Container(
        height: isCompact ? 50.h : 48.0,
        decoration: BoxDecoration(
          color: AppColors.crimson.withValues(alpha: 0.1),
          border: Border.all(
            color: AppColors.crimson.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.crimson,
              size: isCompact ? 20.r : 18.0,
            ),
            SizedBox(width: 8.w),
            Text(
              "ADD MEAL ENTRY",
              style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
                color: AppColors.crimson,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(CalorieLog log, CalorieProvider provider, bool isCompact) {
    final supplementProvider = context.read<SupplementProvider>();
    List<Map<String, dynamic>> additions = [];
    double totalSuppCals = 0;

    // 1. Calculate Supplement & Stack Breakdown
    if (log.addedSupplementsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(log.addedSupplementsJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final double amount = (item is Map) ? (item['amount'] as num).toDouble() : 1.0;
          final s = supplementProvider.library.firstWhere((s) => s.id == id);
          final double itemCals = ((s.caloriesPerUnit ?? 0.0) * amount);
          totalSuppCals += itemCals;
          additions.add({
            'name': s.name,
            'cals': itemCals,
            'pro': (s.proteinPerUnit ?? 0.0) * amount,
            'cho': (s.carbsPerUnit ?? 0.0) * amount,
            'fat': (s.fatsPerUnit ?? 0.0) * amount,
          });
        }
      } catch (_) {}
    }

    if (log.addedStacksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(log.addedStacksJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final Map<String, double>? itemAmounts = (item is Map) 
              ? (item['itemAmounts'] as Map).cast<String, dynamic>().map((k, v) => MapEntry(k, (v as num).toDouble()))
              : null;

          final stack = supplementProvider.supplementStacks.firstWhere((s) => s.id == id);
          double stCals = 0;
          double stPro = 0, stCho = 0, stFat = 0;
          
          for (var supplement in stack.items) {
            if (itemAmounts != null && !itemAmounts.containsKey(supplement.id)) continue;
            double amount = itemAmounts?[supplement.id] ?? 1.0;
            stCals += ((supplement.caloriesPerUnit ?? 0.0) * amount);
            stPro += (supplement.proteinPerUnit ?? 0.0) * amount;
            stCho += (supplement.carbsPerUnit ?? 0.0) * amount;
            stFat += (supplement.fatsPerUnit ?? 0.0) * amount;
          }
          
          totalSuppCals += stCals;
          additions.add({
            'name': stack.name,
            'isStack': true,
            'cals': stCals,
            'pro': stPro,
            'cho': stCho,
            'fat': stFat,
          });
        }
      } catch (_) {}
    }

    // 2. Nutrition Ledger Calculations
    final double portion = log.servings;
    final double finalTotalCals = log.calories;
    final double mealCalsIncludingPortion = finalTotalCals - totalSuppCals;
    final double baseMealOriginalCals = (mealCalsIncludingPortion / (portion > 0 ? portion : 1.0));

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isCompact ? 24.w : 20.0),
        margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: isCompact ? 28.r : 24.0),
      ),
      confirmDismiss: (direction) async => await _showActionConfirmation(
        title: "DELETE MEAL ENTRY",
        message: "REMOVE THIS MEAL FROM YOUR LOG?",
        confirmText: "DELETE",
        confirmColor: AppColors.crimson,
        icon: Icons.delete_forever_rounded,
      ),
      onDismissed: (_) {
        final logsToRollback = supplementProvider.history.where((h) => h.sourceId == log.id).toList();
        for (var entry in logsToRollback) {
          supplementProvider.removeSupplementItem(entry.id);
        }
        provider.deleteLog(log.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            // --- HEADER: Name & Summary ---
            Padding(
              padding: EdgeInsets.fromLTRB(isCompact ? 24.r : 20.0, isCompact ? 24.r : 20.0, isCompact ? 24.r : 20.0, isCompact ? 12.r : 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.mealName.toUpperCase(), 
                          style: AppTextStyles.h2.adaptive(context).copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
                        if (log.foodItems.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Text(log.foodItems, 
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary)),
                          ),
                      ],
                    ),
                  ),
                  _buildTotalBadge(finalTotalCals, isCompact),
                ],
              ),
            ),

            // --- VIVID BIG MACROS (Center Aligned) ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 14.0, vertical: isCompact ? 12.h : 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: _buildBigVividMacro(
                    log.protein != null ? "${log.protein!.toStringAsFixed(log.protein! % 1 == 0 ? 0 : 1)}G" : "-", 
                    "PROTEIN", 
                    Colors.blueAccent,
                    isCompact,
                  )),
                  SizedBox(width: isCompact ? 8.w : 8.0),
                  Expanded(child: _buildBigVividMacro(
                    log.carbs != null ? "${log.carbs!.toStringAsFixed(log.carbs! % 1 == 0 ? 0 : 1)}G" : "-", 
                    "CARBS", 
                    Colors.greenAccent,
                    isCompact,
                  )),
                  SizedBox(width: isCompact ? 8.w : 8.0),
                  Expanded(child: _buildBigVividMacro(
                    log.fats != null ? "${log.fats!.toStringAsFixed(log.fats! % 1 == 0 ? 0 : 1)}G" : "-", 
                    "FAT", 
                    Colors.orangeAccent,
                    isCompact,
                  )),
                ],
              ),
            ),

            // --- TOGGLE BUTTON: Unified Adaptive Design ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 20.0),
              child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
            ),
            GestureDetector(
              onTap: () => setState(() {
                if (_expandedSupplementIds.contains(log.id)) {
                  _expandedSupplementIds.remove(log.id);
                } else {
                  _expandedSupplementIds.add(log.id);
                }
              }),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 10.0),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expandedSupplementIds.contains(log.id) ? "COLLAPSE DETAILS" : "SHOW MORE DETAILS",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    AnimatedRotation(
                      turns: _expandedSupplementIds.contains(log.id) ? 0.5 : 0,
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

            // --- COLLAPSIBLE DETAILS: Animated Transition ---
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              alignment: Alignment.topCenter,
              child: _expandedSupplementIds.contains(log.id)
                  ? Container(
                      padding: EdgeInsets.fromLTRB(isCompact ? 24.w : 20.0, 0, isCompact ? 24.w : 20.0, isCompact ? 16.h : 14.0),
                      child: Container(
                        padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                        ),
                        child: Column(
                          children: [
                            _buildLedgerRow("ORIGINAL MEAL", "${baseMealOriginalCals.toInt()} kcal", isCompact),
                            _buildLedgerRow("PORTION SCALE", "× ${portion % 1 == 0 ? portion.toInt() : portion.toStringAsFixed(1)}", isCompact, isAccent: true),
                            
                            if (additions.isNotEmpty) ...[
                              SizedBox(height: isCompact ? 12.h : 10.0),
                              ...additions.map((item) => _buildIngredientDetail(item, isCompact)),
                            ],

                            Padding(
                              padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 10.0),
                              child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
                            ),
                            _buildLedgerRow("TOTAL INTAKE", "${finalTotalCals.toInt()} kcal", isCompact, isBold: true),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedMealItem(SavedMeal meal, CalorieProvider provider, bool isCompact) {
    final supplementProvider = context.read<SupplementProvider>();
    List<Map<String, dynamic>> additions = [];

    if (meal.addedSupplementsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(meal.addedSupplementsJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final double amount = (item is Map) ? (item['amount'] as num).toDouble() : 1.0;
          final s = supplementProvider.library.firstWhere((s) => s.id == id);
          additions.add({
            'name': s.name,
            'cals': ((s.caloriesPerUnit ?? 0.0) * amount),
            'pro': (s.proteinPerUnit ?? 0.0) * amount,
            'cho': (s.carbsPerUnit ?? 0.0) * amount,
            'fat': (s.fatsPerUnit ?? 0.0) * amount,
          });
        }
      } catch (_) {}
    }
    if (meal.addedStacksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(meal.addedStacksJson!);
        for (var item in decoded) {
          final String id = (item is Map) ? item['id'] : item as String;
          final Map<String, double>? itemAmounts = (item is Map) 
              ? (item['itemAmounts'] as Map).cast<String, dynamic>().map((k, v) => MapEntry(k, (v as num).toDouble()))
              : null;

          final s = supplementProvider.supplementStacks.firstWhere((s) => s.id == id);
          double stPro = 0, stCho = 0, stFat = 0;
          double stCals = 0;
          
          for (var supplement in s.items) {
            double amount = itemAmounts?[supplement.id] ?? 1.0;
            stCals += ((supplement.caloriesPerUnit ?? 0.0) * amount);
            stPro += (supplement.proteinPerUnit ?? 0.0) * amount;
            stCho += (supplement.carbsPerUnit ?? 0.0) * amount;
            stFat += (supplement.fatsPerUnit ?? 0.0) * amount;
          }

          additions.add({
            'name': s.name,
            'cals': stCals,
            'pro': stPro,
            'cho': stCho,
            'fat': stFat,
          });
        }
      } catch (_) {}
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Dismissible(
        key: Key("library_${meal.id}"),
        confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await _showLogPrompt(meal, provider);
                return false;
              } else {
            final confirm = await _showActionConfirmation(
              title: "DELETE SAVED MEAL",
              message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE '${meal.name.toUpperCase()}' FROM YOUR LIBRARY?",
              confirmText: "DELETE",
              confirmColor: AppColors.crimson,
              icon: Icons.delete_forever_rounded,
            );
            if (confirm == true) {
              await provider.deleteSavedMeal(meal.id);
              return true;
            }
            return false;
          }
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 20.w),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: const Icon(Icons.add_circle_outline_rounded, color: Colors.greenAccent),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
        ),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 18.r : 16.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name.toUpperCase(), 
                          style: AppTextStyles.h3.adaptive(context).copyWith(
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        if (meal.sharedBy != null)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.share_rounded, color: Colors.blueAccent, size: isCompact ? 10.r : 10.0),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "SHARED BY ${meal.sharedBy!.toUpperCase()}",
                                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (meal.foodItems.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Text(
                              meal.foodItems,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<AuthProvider>(
                        builder: (context, authProv, _) {
                          final bool isPro = authProv.isPro;
                          return _buildQuickActionButton(
                            icon: isPro ? Icons.ios_share_rounded : Icons.lock_rounded,
                            isActive: false,
                            onTap: () async {
                              if (!isPro) {
                                context.push(AppRoutes.proUpgrade);
                                return;
                              }
                              final userName = authProv.displayName;
                              final link = await provider.generateShareableLink(meal, userName);
                              if (link != null) {
                                await Share.share(
                                  "CHECK OUT THIS MEAL SHARED BY $userName IN RUGGED:\n\n$link",
                                  subject: "MEAL SHARED BY $userName",
                                );
                              }
                            },
                            isCompact: isCompact,
                          );
                        },
                      ),
                      SizedBox(width: isCompact ? 8.w : 6.0),
                      _buildQuickActionButton(
                        icon: Icons.edit_rounded,
                        isActive: false,
                        onTap: () {
                          AdaptiveUtils.showAdaptiveSheet(
                            context: context,
                            sheetBuilder: (sheetContext, isSideSheet) => AddMealSheet(
                              isSideSheet: isSideSheet,
                              isLibraryOnly: true,
                              existingMeal: meal,
                              savedMeals: provider.savedMeals,
                              onSave: (log, _, servings, multiplySupps) {
                                provider.saveMealTemplate(SavedMeal(
                                  id: log.id,
                                  name: log.mealName,
                                  foodItems: log.foodItems,
                                  calories: log.calories,
                                  protein: log.protein,
                                  carbs: log.carbs,
                                  fats: log.fats,
                                  addedSupplementsJson: log.addedSupplementsJson,
                                  addedStacksJson: log.addedStacksJson,
                                  isPinnedToHome: meal.isPinnedToHome,
                                  notificationsEnabled: meal.notificationsEnabled,
                                  reminders: meal.reminders,
                                  servings: servings,
                                  multiplySupps: multiplySupps,
                                ));
                              },
                            ),
                          );
                        },
                        isCompact: isCompact,
                      ),
                      SizedBox(width: isCompact ? 8.w : 6.0),
                      _buildQuickActionButton(
                        icon: Icons.push_pin_rounded,
                        isActive: meal.isPinnedToHome,
                        onTap: () => provider.updateSavedMeal(meal.copyWith(isPinnedToHome: !meal.isPinnedToHome)),
                        isCompact: isCompact,
                      ),
                      SizedBox(width: isCompact ? 8.w : 6.0),
                      _buildQuickActionButton(
                        icon: Icons.notifications_active_outlined,
                        isActive: meal.notificationsEnabled,
                        onTap: () {
                          AdaptiveUtils.showAdaptiveSheet(
                            context: context,
                            sheetBuilder: (sheetContext, isSideSheet) => CalorieNotificationSheet(meal: meal, isSideSheet: isSideSheet),
                          );
                        },
                        isCompact: isCompact,
                      ),
                    ],
                  ),
                ],
              ),
              
              if (additions.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(top: 16.h),
                  child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
                ),
                ...(() {
                  final bool isExpanded = _expandedSupplementIds.contains(meal.id);
                  final List<Map<String, dynamic>> visibleAdditions = 
                      isExpanded ? additions : additions.take(1).toList();
                  final int totalAdditionsCals = additions.fold(0, (sum, item) => sum + (item['cals'] as num).round());
                  
                  return [
                    ...visibleAdditions.map((item) => Padding(
                      padding: EdgeInsets.only(top: 14.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['name'].toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department_rounded, color: AppColors.crimson, size: isCompact ? 12.r : 12.0),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "+${item['cals']}",
                                    style: AppTextStyles.h3.adaptive(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    "kcal",
                                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Row(
                              children: [
                                _buildSpecMacro(item['pro'].toDouble(), "PRO", Colors.blueAccent, isCompact),
                                _buildSpecDivider(isCompact),
                                _buildSpecMacro(item['cho'].toDouble(), "CHO", Colors.greenAccent, isCompact),
                                _buildSpecDivider(isCompact),
                                _buildSpecMacro(item['fat'].toDouble(), "FAT", Colors.orangeAccent, isCompact),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (additions.length > 1)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedSupplementIds.remove(meal.id);
                            } else {
                              _expandedSupplementIds.add(meal.id);
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.only(top: 16.h),
                          color: Colors.transparent,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isExpanded 
                                    ? "SHOW FEWER INGREDIENTS" 
                                    : "SHOW ${additions.length - 1} MORE ADDITIONS",
                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(
                                isExpanded 
                                    ? Icons.keyboard_arrow_up_rounded 
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary.withValues(alpha: 0.4),
                                size: isCompact ? 16.r : 14.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (additions.length > 1)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "TOTAL ADDITIONS:",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded, color: AppColors.crimson, size: isCompact ? 12.r : 12.0),
                                SizedBox(width: 4.w),
                                Text(
                                  "+$totalAdditionsCals",
                                  style: AppTextStyles.h3.adaptive(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  "kcal",
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ];
                })(),
              ],

              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: AppColors.crimson, size: isCompact ? 16.r : 16.0),
                      SizedBox(width: 6.w),
                      Text(
                        meal.calories % 1 == 0 ? meal.calories.toInt().toString() : meal.calories.toStringAsFixed(1),
                        style: AppTextStyles.h3.adaptive(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        "kcal",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: isCompact ? 8.w : 6.0,
                    children: [
                      if (meal.protein != null) _buildSmallMacroPill("${meal.protein!.toInt()}g Protein", Colors.blueAccent, isCompact),
                      if (meal.carbs != null) _buildSmallMacroPill("${meal.carbs!.toInt()}g Carbs", Colors.greenAccent, isCompact),
                      if (meal.fats != null) _buildSmallMacroPill("${meal.fats!.toInt()}g Fats", Colors.orangeAccent, isCompact),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBadge(double total, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(1),
          style: AppTextStyles.h1.adaptive(context).copyWith(
            color: Colors.white,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          "KCAL",
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.crimson,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBigVividMacro(String value, String label, Color color, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 8.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Text(value, 
            style: AppTextStyles.h2.adaptive(context).copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
          SizedBox(height: 2.h),
          Text(label, 
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: color, fontWeight: FontWeight.w500, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _buildLedgerRow(String label, String value, bool isCompact, {bool isAccent = false, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, 
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: isAccent ? AppColors.crimson.withValues(alpha: 0.9) : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            )),
          Text(value, 
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: isBold ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            )),
        ],
      ),
    );
  }

  Widget _buildIngredientDetail(Map<String, dynamic> item, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(
            item['isStack'] == true ? Icons.layers_rounded : Icons.medication_rounded, 
            color: AppColors.crimson.withValues(alpha: 0.6), 
            size: isCompact ? 14.r : 14.0
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              item['name'].toString().toUpperCase(), 
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: Colors.white.withValues(alpha: 0.8), 
                fontWeight: FontWeight.w500, 
                letterSpacing: 0.5,
              )
            ),
          ),
          Text(
            "+${item['cals']} kcal", 
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.6), 
              fontWeight: FontWeight.w500, 
            )
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

  Widget _buildSmallMacroPill(String text, Color color, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10.w : 8.0, vertical: isCompact ? 6.h : 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSpecMacro(num? value, String label, Color color, bool isCompact) {
    if (value == null) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "- ",
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: label,
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    final String formattedValue = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: "$formattedValue ",
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: label,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecDivider(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Text(
        "|",
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isCompact ? 8.r : 8.0),
        decoration: BoxDecoration(
          color: isActive ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isActive ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.crimson : AppColors.textSecondary,
          size: isCompact ? 18.r : 16.0,
        ),
      ),
    );
  }
}
