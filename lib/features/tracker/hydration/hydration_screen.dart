// lib/features/tracker/hydration/hydration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/hydration/widgets/hydration_analytical_widget.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'model/hydration_log.dart';
import 'provider/hydration_provider.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/main_wrapper.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'widgets/water_glass_widget.dart';
import 'package:rugged/core/ads/locked_analytics_overlay.dart';

class _HydrationFilter {
  bool isDescending;
  DateTimeRange? dateRange;
  int? year;
  int? month;
  double? minAmount;
  double? maxAmount;

  _HydrationFilter({
    this.isDescending = true,
    this.dateRange,
    this.year,
    this.month,
    this.minAmount,
    this.maxAmount,
  });

  bool get isInitial =>
      isDescending &&
      dateRange == null &&
      year == null &&
      month == null &&
      minAmount == null &&
      maxAmount == null;

  _HydrationFilter copyWith({
    bool? isDescending,
    DateTimeRange? dateRange,
    int? year,
    int? month,
    double? minAmount,
    double? maxAmount,
  }) {
    return _HydrationFilter(
      isDescending: isDescending ?? this.isDescending,
      dateRange: dateRange,
      year: year,
      month: month,
      minAmount: minAmount,
      maxAmount: maxAmount,
    );
  }
}

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  final _HydrationFilter _recordsFilter = _HydrationFilter();

  DateTime _selectedHistoryDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;

  // Trends Tab State
  final Set<String> _visibleTrendsMetrics = {"water"};
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  // Manual Entry State
  DateTime _manualDate = DateTime.now();
  TimeOfDay _manualTime = TimeOfDay.now();
  final TextEditingController _amountController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "hydration";
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });
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
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickManualDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: _manualDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.blueAccent,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: Colors.white,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _manualDate = picked);
    }
  }

  Future<void> _pickManualTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      useRootNavigator: true,
      initialTime: _manualTime,
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.blueAccent,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: Colors.white,
                ),
                timePickerTheme: Theme.of(context).timePickerTheme.copyWith(
                  dayPeriodColor: WidgetStateColor.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.blueAccent;
                    }
                    return Colors.white.withValues(alpha: 0.05);
                  }),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                ),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _manualTime = picked);
    }
  }

  Future<bool?> _showDeleteLogConfirmation(String amount) async {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE LOG",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THE '$amount' ENTRY?",
      icon: Icons.delete_forever_rounded,
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

        return Consumer<HydrationProvider>(
          builder: (context, provider, _) {
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
                                    'HYDRATION',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.h2.adaptive(context).copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
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
                          indicatorColor: Colors.blueAccent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          unselectedLabelColor: AppColors.textSecondary.withValues(alpha: 0.5),
                          labelColor: Colors.blueAccent,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: "TRACKER"),
                            Tab(text: "TRENDS"),
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
                        _buildTrackerTab(provider, isCompact),
                        _buildTrendsTab(provider, isCompact),
                        _buildRecordsTab(provider, isCompact),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrackerTab(HydrationProvider provider, bool isCompact) {
    return EliteRefreshIndicator(
      onRefresh: () => provider.forceRefresh(),
      color: Colors.blueAccent,
      backgroundColor: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth > 700;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- LEFT COLUMN: DAILY INTAKE ---
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                    children: [
                      _buildSectionHeader("DAILY INTAKE", isCompact),
                      SizedBox(height: isCompact ? 12.h : 10.0),
                      _buildCurrentIntakeCard(provider, isCompact),
                    ],
                  ),
                ),
                VerticalDivider(color: AppColors.white.withValues(alpha : 0.05), width: 1),
                // --- RIGHT COLUMN: MANUAL ENTRY ---
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                    children: [
                      _buildSectionHeader("MANUAL LOG", isCompact),
                      SizedBox(height: isCompact ? 12.h : 10.0),
                      _buildManualEntryCard(provider, isCompact),
                    ],
                  ),
                ),
              ],
            );
          }

          // --- MOBILE: SINGLE COLUMN ---
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isCompact ? 10.h : 8.0),
                _buildSectionHeader("DAILY INTAKE", isCompact),
                SizedBox(height: isCompact ? 12.h : 10.0),
                _buildCurrentIntakeCard(provider, isCompact),
                SizedBox(height: isCompact ? 32.h : 24.0),
                _buildSectionHeader("MANUAL LOG", isCompact),
                SizedBox(height: isCompact ? 12.h : 10.0),
                _buildManualEntryCard(provider, isCompact),
                SizedBox(height: 40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendsTab(HydrationProvider provider, bool isCompact) {
    if (provider.logs.isEmpty) {
      return Center(
        child: Text(
          "LOG INTAKE TO VIEW TRENDS",
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            letterSpacing: 1,
          ),
        ),
      );
    }

    // Aggregate logs by identical timestamp (ignoring seconds/milliseconds)
    final Map<DateTime, double> aggregatedMap = {};
    for (var log in provider.logs) {
      final ts = log.timestamp;
      final normalized = DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute);
      aggregatedMap[normalized] = (aggregatedMap[normalized] ?? 0.0) + log.amountMl.toDouble();
    }

    final sortedEntries = aggregatedMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final List<DateTime> sortedDates = sortedEntries.map((e) => e.key).toList();
    final Map<String, List<double?>> aggregatedData = {
      "water": sortedEntries.map((e) => e.value).toList(),
    };

    final double width = MediaQuery.sizeOf(context).width;
    final bool isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final bool isTabletOrFoldable = width >= 600;
    final bool isWideLandscape = isTabletOrFoldable && isLandscape;

    Widget buildTrendAndOverlayContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HydrationAnalyticalGraph(
            dates: sortedDates,
            data: aggregatedData,
            visibleMetrics: _visibleTrendsMetrics,
            onPointSelected: (idx) {},
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
          HydrationComparisonWidget(
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
      color: Colors.blueAccent,
      backgroundColor: AppColors.surface,
      child: LockedAnalyticsOverlay(
        unlockKey: 'hydration_analytics',
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
  }

  Widget _buildSectionHeader(String title, bool isCompact) {
    return Row(
      children: [
        Container(
          width: 2.5,
          height: 12.0,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
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

  Widget _buildRecordsTab(HydrationProvider provider, bool isCompact) {
    final Set<DateTime> dateSet = provider.logs.map((l) => 
      DateTime(l.timestamp.year, l.timestamp.month, l.timestamp.day)
    ).toSet();
    
    final now = DateTime.now();
    dateSet.add(DateTime(now.year, now.month, now.day));

    final List<HydrationLog> filteredLogs = provider.logs.where((log) {
      if (_recordsFilter.isInitial) {
        return log.timestamp.year == _selectedHistoryDate.year &&
               log.timestamp.month == _selectedHistoryDate.month &&
               log.timestamp.day == _selectedHistoryDate.day;
      }
      if (_recordsFilter.dateRange != null) {
        final start = DateTime(_recordsFilter.dateRange!.start.year, _recordsFilter.dateRange!.start.month, _recordsFilter.dateRange!.start.day);
        final end = DateTime(_recordsFilter.dateRange!.end.year, _recordsFilter.dateRange!.end.month, _recordsFilter.dateRange!.end.day, 23, 59, 59);
        if (log.timestamp.isBefore(start) || log.timestamp.isAfter(end)) return false;
      }
      if (_recordsFilter.year != null && log.timestamp.year != _recordsFilter.year) return false;
      if (_recordsFilter.month != null && log.timestamp.month != _recordsFilter.month) return false;
      final double amount = log.amountMl.toDouble();
      if (_recordsFilter.minAmount != null && amount < _recordsFilter.minAmount!) return false;
      if (_recordsFilter.maxAmount != null && amount > _recordsFilter.maxAmount!) return false;
      return true;
    }).toList();

    filteredLogs.sort((a, b) {
      return _recordsFilter.isDescending 
          ? b.timestamp.compareTo(a.timestamp) 
          : a.timestamp.compareTo(b.timestamp);
    });
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 700;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LEFT COLUMN: CALENDAR ---
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
              VerticalDivider(color: AppColors.white.withValues(alpha : 0.05), width: 1),
              // --- RIGHT COLUMN: SLIDER + LOGS ---
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildHorizontalCalendar(dateSet, isCompact),
                    const Divider(color: Colors.white10, height: 1),
                    Expanded(
                      child: EliteRefreshIndicator(
                        onRefresh: () => provider.forceRefresh(),
                        color: Colors.blueAccent,
                        backgroundColor: AppColors.surface,
                        child: filteredLogs.isEmpty
                            ? Center(
                                child: Text(
                                  _recordsFilter.isInitial ? "NO LOGS FOR THIS DATE" : "NO MATCHING LOGS",
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                ),
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20.0),
                                itemCount: filteredLogs.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                                itemBuilder: (context, index) {
                                  final log = filteredLogs[index];
                                  return _buildRecordItem(log, provider, isCompact);
                                },
                              ),
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
              child: RefreshIndicator(
                onRefresh: () => provider.forceRefresh(),
                color: Colors.blueAccent,
                backgroundColor: AppColors.surface,
                child: filteredLogs.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Container(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Text(
                                  _recordsFilter.isInitial ? "NO LOGS FOR THIS DATE" : "NO MATCHING LOGS",
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(20.r),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (context, index) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          return _buildRecordItem(log, provider, isCompact);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordItem(HydrationLog log, HydrationProvider provider, bool isCompact) {
    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: isCompact ? 24.w : 20.0),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: isCompact ? 28.r : 24.0),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteLogConfirmation(provider.formatAmount(log.amountMl));
      },
      onDismissed: (direction) {
        provider.deleteLog(log.id);
      },
      child: Container(
        padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha : 0.3),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
          border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.formatAmount(log.amountMl),
                  style: AppTextStyles.h3.adaptive(context).copyWith(color: Colors.blueAccent),
                ),
                SizedBox(height: isCompact ? 4.h : 2.0),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(log.timestamp),
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            Icon(Icons.water_drop_outlined, color: Colors.blueAccent.withValues(alpha: 0.5), size: isCompact ? 20.r : 18.0),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentIntakeCard(HydrationProvider provider, bool isCompact) {
    int currentIntakeMl = provider.todayIntake;
    int goalIntakeMl = provider.settings.dailyGoal;
    int remainingMl = goalIntakeMl - currentIntakeMl;
    double progress = (currentIntakeMl / goalIntakeMl).clamp(0.0, 1.0);
    
    bool useMetric = provider.settings.useMetric;
    String unit = useMetric ? "ML" : "OZ";
    
    String displayIntake = useMetric ? currentIntakeMl.toString() : provider.mlToOz(currentIntakeMl).toStringAsFixed(1);
    String displayGoal = useMetric ? goalIntakeMl.toString() : provider.mlToOz(goalIntakeMl).toStringAsFixed(1);
    String displayRemaining = useMetric ? remainingMl.abs().toString() : provider.mlToOz(remainingMl.abs()).toStringAsFixed(1);
    
    int quickAddMl = provider.settings.addValue;
    int quickRemoveMl = provider.settings.minusValue;
    
    String displayQuickAdd = useMetric ? "$quickAddMl$unit" : "${provider.mlToOz(quickAddMl).toStringAsFixed(1)}$unit";
    String displayQuickRemove = useMetric ? "$quickRemoveMl$unit" : "${provider.mlToOz(quickRemoveMl).toStringAsFixed(1)}$unit";

    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header moved outside
            ],
          ),
          SizedBox(height: isCompact ? 4.h : 0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayIntake,
                    style: AppTextStyles.h1.adaptive(context).copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    "/ $displayGoal $unit",
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isCompact ? 12.h : 10.0),
                  Text(
                    remainingMl <= 0 ? "GOAL REACHED" : "REMAINING: $displayRemaining $unit",
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: remainingMl <= 0 ? Colors.greenAccent : Colors.blueAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: isCompact ? 100.r : 90.0,
                width: isCompact ? 90.r : 80.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WaterGlassWidget(
                      progress: progress,
                      size: isCompact ? 60.r : 45.0,
                    ),
                    SizedBox(height: isCompact ? 8.h : 6.0),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 24.h : 20.0),
          Row(
            children: [
              Expanded(child: _buildAdjustmentButton('- $displayQuickRemove', -quickRemoveMl, provider, isCompact, isSubtract: true)),
              SizedBox(width: isCompact ? 12.w : 10.0),
              Expanded(child: _buildAdjustmentButton('+ $displayQuickAdd', quickAddMl, provider, isCompact)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAdjustmentButton(String label, int amountMl, HydrationProvider provider, bool isCompact, {bool isSubtract = false}) {
    final color = isSubtract ? AppColors.error : Colors.blueAccent;
    return GestureDetector(
      onTap: () {
        provider.addWater(amountMl);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 14.h : 12.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 14.0),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        )),
      ),
    );
  }

  Widget _buildManualEntryCard(HydrationProvider provider, bool isCompact) {
    bool useMetric = provider.settings.useMetric;
    String unit = useMetric ? "ml" : "oz";

    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Header moved outside
            ],
          ),
          SizedBox(height: isCompact ? 4.h : 0),
          Row(
            children: [
              Expanded(
                child: _buildManualEntryField(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('MMM dd, yyyy').format(_manualDate),
                  onTap: _pickManualDate,
                  isCompact: isCompact,
                ),
              ),
              SizedBox(width: isCompact ? 12.w : 10.0),
              Expanded(
                child: _buildManualEntryField(
                  icon: Icons.access_time_rounded,
                  label: _manualTime.format(context),
                  onTap: _pickManualTime,
                  isCompact: isCompact,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12.h : 10.0),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            style: AppTextStyles.labelMedium.adaptive(context),
            decoration: InputDecoration(
              hintText: 'Enter amount ($unit)',
              hintStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
              ),
              suffixText: unit,
              suffixStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(height: isCompact ? 16.h : 12.0),
          (() {
            double? amount = double.tryParse(_amountController.text);
            bool isValid = amount != null && amount > 0;

            return GestureDetector(
              onTap: isValid ? () async {
                int amountInMl = useMetric ? amount.round() : provider.ozToMl(amount);
                
                DateTime finalTimestamp = DateTime(
                  _manualDate.year, _manualDate.month, _manualDate.day,
                  _manualTime.hour, _manualTime.minute,
                );
                
                final existing = provider.logs.where((l) => l.timestamp.isAtSameMomentAs(finalTimestamp)).toList();
                if (existing.isNotEmpty) {
                  for (var log in existing) {
                    await provider.deleteLog(log.id);
                  }
                }

                provider.addWater(amountInMl, timestamp: finalTimestamp);
                _amountController.clear();
                if (mounted) {
                  EliteSnackbar.show(context, 'Water intake recorded!');
                }
              } : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: isCompact ? 48.h : 44.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isValid ? Colors.blueAccent : AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                  border: Border.all(
                    color: isValid ? Colors.blueAccent : AppColors.white.withValues(alpha: 0.05),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  isValid ? 'LOG INTAKE' : 'ENTER AMOUNT TO LOG',
                  style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
                    color: isValid ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            );
          }()),
        ],
      ),
    );
  }

  Widget _buildManualEntryField({required IconData icon, required String label, required VoidCallback onTap, required bool isCompact}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, size: isCompact ? 16.r : 14.0, color: Colors.blueAccent),
            SizedBox(width: 8.w),
            Text(label, style: AppTextStyles.labelSmall.adaptive(context)),
          ],
        ),
      ),
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
                        builder: (context, child) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Colors.blueAccent,
                                    onPrimary: Colors.white,
                                    surface: AppColors.surface,
                                    onSurface: Colors.white,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                                  ),
                                ),
                                child: child!,
                              ),
                            ),
                          );
                        },
                      );
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
                          color: isSelected ? Colors.blueAccent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected 
                              ? Border.all(color: Colors.blueAccent.withValues(alpha: 0.5))
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
                                color: (hasData && !isSelected) ? Colors.blueAccent : Colors.transparent,
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
                color: isSelected ? Colors.blueAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: isToday && !isSelected 
                    ? Border.all(color: Colors.blueAccent.withValues(alpha: 0.5))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(dateOnly).toUpperCase(),
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
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
                        color: Colors.blueAccent,
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
}
