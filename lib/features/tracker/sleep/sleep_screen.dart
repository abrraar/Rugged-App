// lib/features/tracker/sleep/sleep_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:rugged/features/main_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'provider/sleep_provider.dart';
import 'provider/sleep_alarm_provider.dart';
import 'model/sleep_log.dart';

import 'widgets/circular_sleep_picker.dart';
import 'widgets/sleep_analytical_graph.dart';
import 'package:rugged/core/ads/locked_analytics_overlay.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  
  // Trends State
  final Set<String> _visibleMetrics = {'duration'};
  int? _comparePointA;
  int? _comparePointB;

  // Entry State
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedHistoryDate = DateTime.now();
  TimeOfDay _entryBedTime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _entryWakeTime = const TimeOfDay(hour: 06, minute: 45);
  int _selectedQuality = 4;
  String _entryNote = "";

  // Calendar State
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;

  // Overlap State
  OverlayEntry? _snackbarOverlay;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "sleep"; 
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController(
      viewportFraction: 0.2,
      initialPage: 0,
    );
    _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
  }

  @override
  void dispose() {
    _snackbarOverlay?.remove();
    activeSettingsContext.value = "";
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _validateOverlap() {
    // This is now handled reactively inside the Consumer builder
    // We keep the method signature to avoid breaking existing calls
    if (mounted) setState(() {});
  }

  void _showCustomSnackbar(String message, VoidCallback onUndo) {
    EliteSnackbar.show(context, message, onUndo: onUndo);
  }

  void _showInstructions() {
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
                      "SLEEP CONTROLS",
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
                      Icons.touch_app_rounded,
                      "Hold and drag the moon or sun icons to adjust your sleep timing.",
                      isCompact,
                    ),
                    SizedBox(height: isCompact ? 16.h : 12.0),
                    _instructionRow(
                      Icons.calendar_today_rounded,
                      "Tap the current date to select previous sessions for entry.",
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
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.5)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "GOT IT",
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
          );
        },
      ),
    );
  }

  Widget _instructionRow(IconData icon, String text, bool isCompact) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 18.0),
        SizedBox(width: isCompact ? 16.w : 12.0),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final provider = context.read<SleepProvider>();
    
    // Check if current _selectedDate is still valid (not logged and not future)
    bool isCurrentDateSelectable(DateTime date) {
      final bool hasLog = provider.logs.any((l) =>
          l.wakeUpTime.year == date.year &&
          l.wakeUpTime.month == date.month &&
          l.wakeUpTime.day == date.day);
      final bool isFuture = date.isAfter(DateTime.now());
      return !hasLog && !isFuture;
    }

    DateTime initialDatePickerDate = _selectedDate;
    if (!isCurrentDateSelectable(initialDatePickerDate)) {
      // Find the most recent unlogged day
      DateTime searchDate = DateTime.now();
      while (!isCurrentDateSelectable(searchDate) && searchDate.isAfter(DateTime(2000))) {
        searchDate = searchDate.subtract(const Duration(days: 1));
      }
      initialDatePickerDate = searchDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDatePickerDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => child!,
      selectableDayPredicate: (DateTime date) {
        final bool hasLog = provider.logs.any((l) =>
            l.wakeUpTime.year == date.year &&
            l.wakeUpTime.month == date.month &&
            l.wakeUpTime.day == date.day);
        return !hasLog;
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _validateOverlap();
    }
  }

  Future<void> _pickAudio(bool isBedtime, SleepAlarmProvider provider) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );

    if (result != null && result.files.single.path != null) {
        final String path = result.files.single.path!;
        if (isBedtime) {
          await provider.updateSettings(
            bedtimeAudioPath: path,
          );
        } else {
          await provider.updateSettings(
            wakeUpAudioPath: path,
          );
        }
        if (mounted) setState(() {});
    }
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
                                'SLEEP PERFORMANCE',
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
                                color: AppColors.white,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: _showInstructions,
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
                      unselectedLabelColor: AppColors.textSecondary.withValues(alpha: 0.5),
                      labelColor: AppColors.crimson,
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
                child: Consumer2<SleepProvider, SleepAlarmProvider>(
                  builder: (context, provider, alarmProvider, _) {
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTrackerTab(provider, alarmProvider, isCompact),
                        _buildTrendsTab(provider, isCompact),
                        _buildHistoryTab(provider, isCompact),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackerTab(SleepProvider provider, SleepAlarmProvider alarmProvider, bool isCompact) {
    final bool hasLogForSelectedDate = provider.logs.any((l) =>
        l.wakeUpTime.year == _selectedDate.year &&
        l.wakeUpTime.month == _selectedDate.month &&
        l.wakeUpTime.day == _selectedDate.day);
    final bool isFutureDate = _selectedDate.isAfter(DateTime.now());
    final bool canSave = !hasLogForSelectedDate && !isFutureDate;

    String? disabledReason;
    if (isFutureDate) {
      disabledReason = "CANNOT RECORD SLEEP FOR FUTURE DATES";
    } else if (hasLogForSelectedDate) {
      disabledReason = "SLEEP ALREADY RECORDED FOR THIS DATE";
    }

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
                // --- LEFT COLUMN: LOG SLEEP ---
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
                    children: [
                      _buildSectionTitle(context, 'LOG SLEEP', isCompact),
                      const SizedBox(height: 16.0),
                      CircularSleepPicker(
                        initialBedtime: _entryBedTime,
                        initialWakeTime: _entryWakeTime,
                        canSave: canSave,
                        disabledReason: disabledReason,
                        selectedDate: _selectedDate,
                        quality: _selectedQuality,
                        note: _entryNote,
                        use24HourClock: provider.settings.use24HourClock,
                        onPickDate: _pickDate,
                        onTimeChanged: (bedtime, wakeTime) {
                          _entryBedTime = bedtime;
                          _entryWakeTime = wakeTime;
                        },
                        onQualityChanged: (q) => setState(() => _selectedQuality = q),
                        onNoteChanged: (n) => _entryNote = n,
                        isCompact: isCompact,
                        onSave: () async {
                          if (!canSave) {
                            EliteSnackbar.show(context, disabledReason ?? "CANNOT RECORD SLEEP", isError: true);
                            return;
                          }

                          DateTime end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryWakeTime.hour, _entryWakeTime.minute);
                          DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryBedTime.hour, _entryBedTime.minute);
                          
                          if (start.isAfter(end)) {
                            start = start.subtract(const Duration(days: 1));
                          }
                          
                          final logId = const Uuid().v4();
                          final log = SleepLog(
                            id: logId, 
                            bedtime: start, 
                            wakeUpTime: end, 
                            quality: _selectedQuality, 
                            type: SleepType.night,
                            note: _entryNote,
                          );
                          await provider.addSleepLog(log);
                          
                          if (mounted) {
                            _showCustomSnackbar(
                              "Sleep session recorded!",
                              () async {
                                 await provider.deleteLog(logId);
                              },
                            );
                            setState(() {
                              _entryNote = "";
                              _selectedQuality = 4;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                VerticalDivider(color: AppColors.white.withValues(alpha: 0.05), width: 1),
                // --- RIGHT COLUMN: ALARM ---
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
                    children: [
                      _buildSectionTitle(context, 'ALARM CONFIGURATION', isCompact),
                      const SizedBox(height: 20.0),
                      _buildEnhancedAlarmCard(alarmProvider, isCompact),
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
                const SizedBox(height: 12.0),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
                  child: _buildSectionTitle(context, 'LOG SLEEP', isCompact),
                ),
                const SizedBox(height: 16.0),
                CircularSleepPicker(
                  initialBedtime: _entryBedTime,
                  initialWakeTime: _entryWakeTime,
                  canSave: canSave,
                  disabledReason: disabledReason,
                  selectedDate: _selectedDate,
                  quality: _selectedQuality,
                  note: _entryNote,
                  use24HourClock: provider.settings.use24HourClock,
                  onPickDate: _pickDate,
                  onTimeChanged: (bedtime, wakeTime) {
                    _entryBedTime = bedtime;
                    _entryWakeTime = wakeTime;
                  },
                  onQualityChanged: (q) => setState(() => _selectedQuality = q),
                  onNoteChanged: (n) => _entryNote = n,
                  isCompact: isCompact,
                  onSave: () async {
                    if (!canSave) {
                      EliteSnackbar.show(context, disabledReason ?? "CANNOT RECORD SLEEP", isError: true);
                      return;
                    }

                    DateTime end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryWakeTime.hour, _entryWakeTime.minute);
                    DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryBedTime.hour, _entryBedTime.minute);
                    
                    if (start.isAfter(end)) {
                      start = start.subtract(const Duration(days: 1));
                    }
                    
                    final logId = const Uuid().v4();
                    final log = SleepLog(
                      id: logId, 
                      bedtime: start, 
                      wakeUpTime: end, 
                      quality: _selectedQuality, 
                      type: SleepType.night,
                      note: _entryNote,
                    );
                    await provider.addSleepLog(log);
                    
                    if (mounted) {
                      _showCustomSnackbar(
                        "Sleep session recorded!",
                        () async {
                           await provider.deleteLog(logId);
                        },
                      );
                      setState(() {
                        _entryNote = "";
                        _selectedQuality = 4;
                      });
                    }
                  },
                ),
                
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32.0),
                      _buildSectionTitle(context, 'ALARM CONFIGURATION', isCompact),
                      const SizedBox(height: 16.0),
                      _buildEnhancedAlarmCard(alarmProvider, isCompact),
                      const SizedBox(height: 32.0),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendsTab(SleepProvider provider, bool isCompact) {
    if (provider.logs.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => EliteRefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          child: ListView(
            children: [
              Container(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "INSUFFICIENT DATA FOR TRENDS",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedLogs = List<SleepLog>.from(provider.logs)..sort((a, b) => a.bedtime.compareTo(b.bedtime));
    final List<DateTime> dates = sortedLogs.map((l) => l.wakeUpTime).toList();
    final Map<String, List<double?>> data = {
      "duration": sortedLogs.map((l) => l.duration.inMinutes / 60.0).toList(),
    };

    final double width = MediaQuery.sizeOf(context).width;
    final bool isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final bool isTabletOrFoldable = width >= 600;
    final bool isWideLandscape = isTabletOrFoldable && isLandscape;

    Widget buildTrendAndOverlayContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SleepAnalyticalGraph(
            dates: dates,
            data: data,
            visibleMetrics: _visibleMetrics,
            onPointSelected: (idx) {},
          ),
        ],
      );
    }

    Widget buildComparisonContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, 'DATA COMPARISON', isCompact),
          SizedBox(height: 24.h),
          SleepComparisonWidget(
            idx1: _comparePointA,
            idx2: _comparePointB,
            dates: dates,
            data: data,
            use24HourClock: provider.settings.use24HourClock,
            isCompact: isCompact,
            onPointAChanged: (idx) => setState(() => _comparePointA = idx),
            onPointBChanged: (idx) => setState(() => _comparePointB = idx),
          ),
        ],
      );
    }

    return EliteRefreshIndicator(
      onRefresh: () => provider.forceRefresh(),
      color: AppColors.crimson,
      backgroundColor: AppColors.surface,
      child: LockedAnalyticsOverlay(
        unlockKey: 'sleep_analytics',
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
                  children: [
                    buildTrendAndOverlayContent(),
                    SizedBox(height: 32.h),
                    buildComparisonContent(),
                    SizedBox(height: 40.h),
                  ],
                ),
        ),
      ),
    );
  }

  // Remove _buildMetricToggle as it's no longer used


  Widget _buildHistoryTab(SleepProvider provider, bool isCompact) {
    final Set<DateTime> dateSet = provider.logs.map((l) => 
      DateTime(l.wakeUpTime.year, l.wakeUpTime.month, l.wakeUpTime.day)
    ).toSet();
    
    final now = DateTime.now();
    dateSet.add(DateTime(now.year, now.month, now.day));

    final historyLogs = provider.logs.where((l) {
      return l.wakeUpTime.year == _selectedHistoryDate.year &&
             l.wakeUpTime.month == _selectedHistoryDate.month &&
             l.wakeUpTime.day == _selectedHistoryDate.day;
    }).toList();

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
              VerticalDivider(color: AppColors.white.withValues(alpha: 0.05), width: 1),
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
                        color: AppColors.crimson,
                        backgroundColor: AppColors.surface,
                        child: historyLogs.isEmpty
                            ? Center(
                                child: Text(
                                  "No logs for this date.",
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20.0),
                                itemCount: historyLogs.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                                itemBuilder: (context, index) {
                                  final log = historyLogs[index];
                                  return Dismissible(
                                    key: Key("sleep_log_${log.id}"),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: EdgeInsets.only(right: 24.0),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20.r),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                                    ),
                                    confirmDismiss: (direction) => _confirmDelete(context, provider, log.id),
                                    onDismissed: (_) => provider.deleteLog(log.id),
                                    child: _buildHistoryCard(context, provider, log, isCompact),
                                  );
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
              child: EliteRefreshIndicator(
                onRefresh: () => provider.forceRefresh(),
                color: AppColors.crimson,
                backgroundColor: AppColors.surface,
                child: historyLogs.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          children: [
                            Container(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: Text(
                                  "No logs for this date.",
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                        itemCount: historyLogs.length,
                        separatorBuilder: (context, index) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final log = historyLogs[index];
                          return Dismissible(
                            key: Key("sleep_log_${log.id}"),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 24.w),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                            ),
                            confirmDismiss: (direction) => _confirmDelete(context, provider, log.id),
                            onDismissed: (_) {
                              provider.deleteLog(log.id);
                            },
                            child: _buildHistoryCard(context, provider, log, isCompact),
                          );
                        },
                      ),
              ),
            ),
          ],
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

  Widget _buildHistoryCard(BuildContext context, SleepProvider provider, SleepLog log, bool isCompact) {
    final hours = log.duration.inHours;
    final minutes = log.duration.inMinutes % 60;
    final dateStr = DateFormat('MMM dd, yyyy').format(log.wakeUpTime);
    
    final String bedTimeStr = _formatTime(TimeOfDay.fromDateTime(log.bedtime), provider.settings.use24HourClock);
    final String wakeTimeStr = _formatTime(TimeOfDay.fromDateTime(log.wakeUpTime), provider.settings.use24HourClock);
    final timeStr = "$bedTimeStr - $wakeTimeStr";

    return Container(
      padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
                decoration: BoxDecoration(
                  color: log.type == SleepType.night ? AppColors.crimson.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  log.type == SleepType.night ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
                  color: log.type == SleepType.night ? AppColors.crimson : Colors.amber,
                  size: isCompact ? 20.r : 18.0,
                ),
              ),
              SizedBox(width: isCompact ? 16.w : 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${hours}h ${minutes}m",
                      style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.white),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      dateStr,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      timeStr,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded,
                  size: isCompact ? 12.r : 12.0,
                  color: i < log.quality 
                    ? (log.type == SleepType.night ? AppColors.crimson : Colors.amber) 
                    : AppColors.white.withValues(alpha: 0.1),
                )),
              ),
            ],
          ),
          if (log.note.isNotEmpty) ...[
            SizedBox(height: isCompact ? 16.h : 14.0),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NOTES",
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    log.note,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, SleepProvider provider, String id) {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE SLEEP LOG",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THIS SESSION FROM YOUR HISTORY?",
    );
  }

  Widget _buildEnhancedAlarmCard(SleepAlarmProvider alarmProvider, bool isCompact) {
    final settings = alarmProvider.settings;
    
    return Column(
      children: [
        _buildSystemTimeTile(
          title: "Bedtime Reminder",
          subtitle: "Optimized Recovery Start",
          icon: Icons.bedtime_rounded,
          iconColor: AppColors.crimson,
          time: TimeOfDay(hour: settings.bedtimeHour, minute: settings.bedtimeMinute),
          isEnabled: settings.bedtimeEnabled,
          audioName: settings.bedtimeAudioPath != null ? settings.bedtimeAudioPath!.split('/').last : 'Standard',
          use24HourClock: context.read<SleepProvider>().settings.use24HourClock,
          isCompact: isCompact,
          onToggle: (val) {
             if (val) {
                // Optimistic UI update
                alarmProvider.updateSettings(bedtimeEnabled: true);
                // Background permission check
                alarmProvider.checkAndRequestPermissions(context).then((ok) {
                   if (!ok) {
                      // Revert if denied
                      alarmProvider.updateSettings(bedtimeEnabled: false);
                   }
                });
             } else {
                alarmProvider.updateSettings(bedtimeEnabled: false);
             }
          },
          onTimeTap: () async {
            final picked = await showTimePicker(
              context: context, 
              useRootNavigator: true,
              initialTime: TimeOfDay(hour: settings.bedtimeHour, minute: settings.bedtimeMinute),
              builder: (context, child) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        alwaysUse24HourFormat: context.read<SleepProvider>().settings.use24HourClock,
                      ),
                      child: child!,
                    ),
                  ),
                );
              },
            );
            if (picked != null) {
              await alarmProvider.updateSettings(bedtimeHour: picked.hour, bedtimeMinute: picked.minute);
            }
          },
          onAudioTap: () => _pickAudio(true, alarmProvider),
        ),
        SizedBox(height: isCompact ? 12.h : 10.0),
        _buildSystemTimeTile(
          title: "Wake Up Alarm",
          subtitle: "Growth Protocol Active",
          icon: Icons.wb_sunny_rounded,
          iconColor: Colors.amber,
          time: TimeOfDay(hour: settings.wakeUpHour, minute: settings.wakeUpMinute),
          isEnabled: settings.wakeUpEnabled,
          audioName: settings.wakeUpAudioPath != null ? settings.wakeUpAudioPath!.split('/').last : 'Standard',
          use24HourClock: context.read<SleepProvider>().settings.use24HourClock,
          isCompact: isCompact,
          onToggle: (val) {
             if (val) {
                // Optimistic UI update
                alarmProvider.updateSettings(wakeUpEnabled: true);
                // Background permission check
                alarmProvider.checkAndRequestPermissions(context).then((ok) {
                   if (!ok) {
                      // Revert if denied
                      alarmProvider.updateSettings(wakeUpEnabled: false);
                   }
                });
             } else {
                alarmProvider.updateSettings(wakeUpEnabled: false);
             }
          },
          onTimeTap: () async {
            final picked = await showTimePicker(
              context: context, 
              useRootNavigator: true,
              initialTime: TimeOfDay(hour: settings.wakeUpHour, minute: settings.wakeUpMinute),
              builder: (context, child) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        alwaysUse24HourFormat: context.read<SleepProvider>().settings.use24HourClock,
                      ),
                      child: child!,
                    ),
                  ),
                );
              },
            );
            if (picked != null) {
              await alarmProvider.updateSettings(wakeUpHour: picked.hour, wakeUpMinute: picked.minute);
            }
          },
          onAudioTap: () => _pickAudio(false, alarmProvider),
        ),
      ],
    );
  }

  Widget _buildSystemTimeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required TimeOfDay time,
    required bool isEnabled,
    required String audioName,
    required Function(bool) onToggle,
    required VoidCallback onTimeTap,
    required VoidCallback onAudioTap,
    required bool use24HourClock,
    required bool isCompact,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isCompact ? 20.w : 16.0, isCompact ? 16.h : 14.0, isCompact ? 12.w : 10.0, isCompact ? 8.h : 6.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 10.r : 8.0),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: isCompact ? 20.r : 18.0),
                ),
                SizedBox(width: isCompact ? 14.w : 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.white)),
                      Text(subtitle, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeThumbColor: AppColors.crimson,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
          Divider(color: AppColors.white.withValues(alpha: 0.03), height: 1),
          IntrinsicH(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTimeTap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 14.0),
                      child: Column(
                        children: [
                          Text("SCHEDULED", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
                          SizedBox(height: isCompact ? 4.h : 4.0),
                          Text(
                            _formatTime(time, use24HourClock), 
                            style: AppTextStyles.h2.adaptive(context).copyWith(
                              color: isEnabled ? AppColors.white : AppColors.textSecondary.withValues(alpha: 0.5)
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, color: AppColors.white.withValues(alpha: 0.03)),
                Expanded(
                  child: InkWell(
                    onTap: onAudioTap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 14.0, horizontal: isCompact ? 16.w : 14.0),
                      child: Column(
                        children: [
                          Text("ALARM TONE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
                          SizedBox(height: isCompact ? 6.h : 4.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.graphic_eq_rounded, size: isCompact ? 12.r : 12.0, color: AppColors.crimson),
                              SizedBox(width: isCompact ? 6.w : 4.0),
                              Flexible(
                                child: Text(
                                  audioName.toUpperCase(),
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  String _formatTime(TimeOfDay time, bool use24HourClock) {
    if (use24HourClock) {
      final String hour = time.hour.toString().padLeft(2, '0');
      final String minute = time.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    } else {
      final int hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final String minute = time.minute.toString().padLeft(2, '0');
      final String period = time.period == DayPeriod.am ? "AM" : "PM";
      return "$hour:$minute $period";
    }
  }







































  Widget _buildSectionTitle(BuildContext context, String title, bool isCompact) {
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


}

class IntrinsicH extends StatelessWidget {
  final Widget child;
  const IntrinsicH({super.key, required this.child});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(child: child);
}

class SleepComparisonWidget extends StatelessWidget {
  final int? idx1;
  final int? idx2;
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Function(int?) onPointAChanged;
  final Function(int?) onPointBChanged;
  final bool use24HourClock;
  final bool isCompact;

  const SleepComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.dates,
    required this.data,
    required this.onPointAChanged,
    required this.onPointBChanged,
    required this.use24HourClock,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPointPicker("POINT A", idx1, idx2, dates, onPointAChanged, context),
              SizedBox(width: isCompact ? 16.w : 12.0),
              _buildPointPicker("POINT B", idx2, idx1, dates, onPointBChanged, context, isEnd: true),
            ],
          ),
          if (idx1 != null && idx2 != null) ...[
            SizedBox(height: isCompact ? 24.h : 20.0),
            _buildComparisonDetails(context),
          ] else ...[
            SizedBox(height: isCompact ? 32.h : 24.0),
              Center(
                child: Text(
                  "SELECT TWO POINTS TO COMPARE",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointPicker(String title, int? selectedIdx, int? otherIdx, List<DateTime> dates, Function(int?) onChanged, BuildContext context, {bool isEnd = false}) {
    final labels = dates.map((d) {
      if (use24HourClock) {
        return DateFormat('MMM dd, HH:mm').format(d).toUpperCase();
      } else {
        return DateFormat('MMM dd, hh:mm a').format(d).toUpperCase();
      }
    }).toList();
    return Expanded(
      child: Column(
        crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (selectedIdx != null && isEnd) ...[
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isCompact ? 12.r : 10.0),
                  ),
                ),
                SizedBox(width: isCompact ? 8.w : 6.0),
              ],
              Text(title, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.4), fontWeight: FontWeight.w500, letterSpacing: 2)),
              if (selectedIdx != null && !isEnd) ...[
                SizedBox(width: isCompact ? 8.w : 6.0),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isCompact ? 12.r : 10.0),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 10.h : 8.0),
          GestureDetector(
            onTap: () => _showPicker(context, selectedIdx, otherIdx, dates, onChanged),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 10.0, vertical: isCompact ? 12.h : 10.0),
              decoration: BoxDecoration(
                color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.05) : AppColors.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: Border.all(color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.4) : AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIdx != null ? Icons.event_available_rounded : Icons.event_note_rounded, color: AppColors.crimson, size: isCompact ? 18.r : 16.0),
                  SizedBox(width: isCompact ? 10.w : 8.0),
                  Flexible(child: Text(selectedIdx != null ? labels[selectedIdx] : "SET POINT", overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: selectedIdx != null ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, int? current, int? other, List<DateTime> dates, Function(int?) onChanged) async {
    final Map<String, DateTime> availableMonths = {};
    for (var d in dates) {
      final key = DateFormat('MMMM yyyy').format(d).toUpperCase();
      availableMonths.putIfAbsent(key, () => DateTime(d.year, d.month));
    }

    DatePickerFilterPreset selectedPreset = DatePickerFilterPreset.last30Days;
    DateTime? selectedMonth;
    DateTimeRange? customRange;

    final int? result = await AdaptiveUtils.showAdaptiveSheet<int>(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final now = DateTime.now();
          List<DateTime> filteredDates = [];
          if (selectedPreset == DatePickerFilterPreset.last7Days) {
            final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
            filteredDates = dates.where((d) => d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)).toList();
          } else if (selectedPreset == DatePickerFilterPreset.last30Days) {
            final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
            filteredDates = dates.where((d) => d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)).toList();
          } else if (selectedPreset == DatePickerFilterPreset.thisMonth) {
            filteredDates = dates.where((d) => d.year == now.year && d.month == now.month).toList();
          } else if (selectedPreset == DatePickerFilterPreset.selectMonth && selectedMonth != null) {
            filteredDates = dates.where((d) => d.year == selectedMonth!.year && d.month == selectedMonth!.month).toList();
          } else if (selectedPreset == DatePickerFilterPreset.customRange && customRange != null) {
            final start = DateTime(customRange!.start.year, customRange!.start.month, customRange!.start.day);
            final end = DateTime(customRange!.end.year, customRange!.end.month, customRange!.end.day, 23, 59, 59);
            filteredDates = dates.where((d) => (d.isAfter(start) || d.isAtSameMomentAs(start)) && (d.isBefore(end) || d.isAtSameMomentAs(end))).toList();
          } else {
            filteredDates = dates;
          }

          final Map<String, List<int>> dateGroups = {};
          for (int i = 0; i < dates.length; i++) {
            if (filteredDates.contains(dates[i])) {
              final dateKey = DateFormat('yyyy-MM-dd').format(dates[i]);
              dateGroups.putIfAbsent(dateKey, () => []).add(i);
            }
          }
          final sortedDateKeys = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
              final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 600.0);

              Widget buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
                return GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isSheetCompact ? 12.w : 10.0, vertical: isSheetCompact ? 8.h : 6.0),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.crimson.withValues(alpha: 0.15) : AppColors.surfaceLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(isSheetCompact ? 10.r : 8.0),
                      border: Border.all(
                        color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: isSelected ? AppColors.crimson : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                        fontSize: isSheetCompact ? 10.sp : 11.0,
                      ),
                    ),
                  ),
                );
              }

              return Align(
                alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
                child: SizedBox(
                  width: sheetWidth,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      height: isSideSheet ? double.infinity : null,
                      padding: EdgeInsets.fromLTRB(
                        isSheetCompact ? 24.w : 20.0,
                        isSideSheet ? 0 : (isSheetCompact ? 12.h : 10.0),
                        isSheetCompact ? 24.w : 20.0,
                        isSheetCompact ? 40.h : 32.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: isSideSheet
                            ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                            : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                        children: [
                          if (isSideSheet) const SizedBox(height: 24.0),
                          if (!isSideSheet)
                            Container(
                              width: isSheetCompact ? 40.w : 40.0,
                              height: isSheetCompact ? 4.h : 4.0,
                              margin: EdgeInsets.only(bottom: isSheetCompact ? 24.h : 20.0),
                              decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isSheetCompact ? 10.r : 8.0),
                                    decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: Icon(Icons.event_note_rounded, color: AppColors.crimson, size: isSheetCompact ? 24.r : 20.0),
                                  ),
                                  SizedBox(width: isSheetCompact ? 16.w : 12.0),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("SELECT LOG", style: AppTextStyles.h3.adaptive(context)),
                                      Text("CHOOSE A DATE FROM YOUR LOGS", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 1)),
                                    ],
                                  ),
                                ],
                              ),
                              if (isSideSheet)
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => Navigator.pop(sheetContext),
                                ),
                            ],
                          ),
                          SizedBox(height: isSheetCompact ? 16.h : 14.0),

                          Wrap(
                            spacing: isSheetCompact ? 8.w : 6.0,
                            runSpacing: isSheetCompact ? 8.h : 6.0,
                            children: [
                              buildChip(
                                label: "LAST 7 DAYS",
                                isSelected: selectedPreset == DatePickerFilterPreset.last7Days,
                                onTap: () => setSheetState(() => selectedPreset = DatePickerFilterPreset.last7Days),
                              ),
                              buildChip(
                                label: "LAST 30 DAYS",
                                isSelected: selectedPreset == DatePickerFilterPreset.last30Days,
                                onTap: () => setSheetState(() => selectedPreset = DatePickerFilterPreset.last30Days),
                              ),
                              buildChip(
                                label: "THIS MONTH",
                                isSelected: selectedPreset == DatePickerFilterPreset.thisMonth,
                                onTap: () => setSheetState(() => selectedPreset = DatePickerFilterPreset.thisMonth),
                              ),
                              buildChip(
                                label: selectedPreset == DatePickerFilterPreset.selectMonth && selectedMonth != null
                                    ? DateFormat('MMM yyyy').format(selectedMonth!).toUpperCase()
                                    : "SELECT MONTH ▾",
                                isSelected: selectedPreset == DatePickerFilterPreset.selectMonth,
                                onTap: () async {
                                  final DateTime? pickedMonth = await showDialog<DateTime>(
                                    context: sheetContext,
                                    builder: (dialogCtx) {
                                      int tempYear = selectedMonth?.year ?? DateTime.now().year;
                                      int tempMonth = selectedMonth?.month ?? DateTime.now().month;

                                      final years = (dates.map((d) => d.year).toSet().toList()..sort((a, b) => b.compareTo(a)));
                                      if (!years.contains(tempYear)) years.add(tempYear);
                                      years.sort((a, b) => b.compareTo(a));

                                      return StatefulBuilder(
                                        builder: (dialogCtx, setDialogState) {
                                          return Dialog(
                                            backgroundColor: AppColors.surface,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16.0),
                                              side: BorderSide(color: AppColors.white.withValues(alpha: 0.05)),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(20.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "SELECT MONTH & YEAR",
                                                    style: AppTextStyles.labelMedium.adaptive(dialogCtx).copyWith(
                                                      color: AppColors.crimson,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20.0),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: DropdownButtonFormField<int>(
                                                          initialValue: tempMonth,
                                                          dropdownColor: AppColors.surface,
                                                          decoration: InputDecoration(
                                                            labelText: "MONTH",
                                                            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
                                                            ),
                                                          ),
                                                          items: List.generate(12, (i) => i + 1).map((m) {
                                                            return DropdownMenuItem<int>(
                                                              value: m,
                                                              child: Text(
                                                                DateFormat('MMMM').format(DateTime(2024, m)).toUpperCase(),
                                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                                              ),
                                                            );
                                                          }).toList(),
                                                          onChanged: (val) {
                                                            if (val != null) setDialogState(() => tempMonth = val);
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12.0),
                                                      Expanded(
                                                        child: DropdownButtonFormField<int>(
                                                          initialValue: tempYear,
                                                          dropdownColor: AppColors.surface,
                                                          decoration: InputDecoration(
                                                            labelText: "YEAR",
                                                            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
                                                            ),
                                                          ),
                                                          items: years.map((y) {
                                                            return DropdownMenuItem<int>(
                                                              value: y,
                                                              child: Text(
                                                                "$y",
                                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                                              ),
                                                            );
                                                          }).toList(),
                                                          onChanged: (val) {
                                                            if (val != null) setDialogState(() => tempYear = val);
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 24.0),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(dialogCtx),
                                                        child: const Text("CANCEL", style: TextStyle(color: AppColors.textSecondary)),
                                                      ),
                                                      const SizedBox(width: 8.0),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.crimson,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                                        ),
                                                        onPressed: () => Navigator.pop(dialogCtx, DateTime(tempYear, tempMonth)),
                                                        child: const Text("APPLY", style: TextStyle(color: Colors.white)),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                  if (pickedMonth != null) {
                                    setSheetState(() {
                                      selectedMonth = pickedMonth;
                                      selectedPreset = DatePickerFilterPreset.selectMonth;
                                    });
                                  }
                                },
                              ),
                              buildChip(
                                label: selectedPreset == DatePickerFilterPreset.customRange && customRange != null
                                    ? "${DateFormat('MMM dd').format(customRange!.start)} - ${DateFormat('MMM dd').format(customRange!.end)}"
                                    : "CUSTOM RANGE",
                                isSelected: selectedPreset == DatePickerFilterPreset.customRange,
                                onTap: () async {
                                  final picked = await showDateRangePicker(
                                    context: sheetContext,
                                    firstDate: dates.isNotEmpty ? dates.first : DateTime(2020),
                                    lastDate: DateTime.now(),
                                    initialDateRange: customRange,
                                    builder: (ctx, child) {
                                      final mediaQuery = MediaQuery.of(ctx);
                                      final isWide = mediaQuery.size.width > 600;
                                      final isTall = mediaQuery.size.height > 600;
                                      return Theme(
                                        data: Theme.of(ctx).copyWith(
                                          colorScheme: ColorScheme.dark(
                                            primary: AppColors.crimson,
                                            onPrimary: Colors.white,
                                            secondary: AppColors.crimson,
                                            onSecondary: Colors.white,
                                            secondaryContainer: AppColors.crimson.withValues(alpha: 0.25),
                                            onSecondaryContainer: Colors.white,
                                            surface: AppColors.surface,
                                            onSurface: Colors.white,
                                          ),
                                          datePickerTheme: DatePickerThemeData(
                                            headerBackgroundColor: AppColors.surface,
                                            headerForegroundColor: Colors.white,
                                            backgroundColor: AppColors.surface,
                                            rangeSelectionBackgroundColor: AppColors.crimson.withValues(alpha: 0.25),
                                            rangePickerHeaderBackgroundColor: AppColors.surface,
                                            rangePickerHeaderForegroundColor: Colors.white,
                                            todayBorder: const BorderSide(color: AppColors.crimson),
                                            todayForegroundColor: WidgetStateProperty.all(AppColors.crimson),
                                            dayOverlayColor: WidgetStateProperty.all(AppColors.crimson.withValues(alpha: 0.1)),
                                          ),
                                        ),
                                        child: Dialog(
                                          insetPadding: EdgeInsets.symmetric(
                                            horizontal: isWide ? 80.0 : 16.0,
                                            vertical: isTall ? 60.0 : 20.0,
                                          ),
                                          backgroundColor: AppColors.surface,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                                          clipBehavior: Clip.antiAlias,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
                                            child: child!,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setSheetState(() {
                                      customRange = picked;
                                      selectedPreset = DatePickerFilterPreset.customRange;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),

                          SizedBox(height: isSheetCompact ? 16.h : 14.0),

                          sortedDateKeys.isEmpty
                              ? Padding(
                                  padding: EdgeInsets.symmetric(vertical: isSheetCompact ? 32.h : 24.0),
                                  child: Center(
                                    child: Text(
                                      "NO RECORDINGS FOR THIS PERIOD",
                                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                )
                              : ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * (isSideSheet ? 0.75 : 0.45)),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: sortedDateKeys.length,
                                    separatorBuilder: (context, index) => SizedBox(height: isSheetCompact ? 12.h : 10.0),
                                    itemBuilder: (context, i) {
                                      final String dateKey = sortedDateKeys[i];
                                      final List<int> indices = dateGroups[dateKey]!;
                                      final DateTime displayDate = dates[indices.first];

                                      bool isPartiallySelected = indices.contains(current);
                                      bool isOccupiedByOther = indices.contains(other);

                                      return GestureDetector(
                                        onTap: () async {
                                          if (indices.length == 1) {
                                            Navigator.pop(sheetContext, indices.first);
                                          } else {
                                            final int? timeResult = await AdaptiveUtils.showAdaptiveSheet<int>(
                                              context: context,
                                              sheetBuilder: (timeSheetContext, isTimeSideSheet) => LayoutBuilder(
                                                builder: (ctx, constraints) {
                                                  final bool isTimeSheetCompact = constraints.maxWidth < 600 && !isTimeSideSheet;
                                                  final double sheetWidth = isTimeSideSheet ? constraints.maxWidth : (isTimeSheetCompact ? constraints.maxWidth : 600.0);

                                                  return Align(
                                                    alignment: isTimeSideSheet ? Alignment.center : Alignment.bottomCenter,
                                                    child: SizedBox(
                                                      width: sheetWidth,
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: Container(
                                                          height: isTimeSideSheet ? double.infinity : null,
                                                          padding: EdgeInsets.fromLTRB(
                                                            isTimeSheetCompact ? 24.w : 20.0,
                                                            isTimeSideSheet ? 0 : (isTimeSheetCompact ? 12.h : 10.0),
                                                            isTimeSheetCompact ? 24.w : 20.0,
                                                            isTimeSheetCompact ? 40.h : 32.0,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.surface,
                                                            borderRadius: isTimeSideSheet
                                                                ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                                                                : BorderRadius.vertical(top: Radius.circular(isTimeSheetCompact ? 32.r : 24.0)),
                                                            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                                                          ),
                                                          child: Column(
                                                            mainAxisSize: isTimeSideSheet ? MainAxisSize.max : MainAxisSize.min,
                                                            children: [
                                                              if (isTimeSideSheet) const SizedBox(height: 24.0),
                                                              if (!isTimeSideSheet)
                                                                Container(
                                                                  width: isTimeSheetCompact ? 40.w : 40.0,
                                                                  height: isTimeSheetCompact ? 4.h : 4.0,
                                                                  margin: EdgeInsets.only(bottom: isTimeSheetCompact ? 24.h : 20.0),
                                                                  decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
                                                                ),
                                                              Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Container(
                                                                        padding: EdgeInsets.all(isTimeSheetCompact ? 10.r : 8.0),
                                                                        decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle),
                                                                        child: Icon(Icons.access_time_rounded, color: AppColors.crimson, size: isTimeSheetCompact ? 24.r : 20.0),
                                                                      ),
                                                                      SizedBox(width: isTimeSheetCompact ? 16.w : 12.0),
                                                                      Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text("SELECT TIME", style: AppTextStyles.h3.adaptive(context)),
                                                                          Text("CHOOSE A TIME LOG FOR THIS DATE", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 1)),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  if (isTimeSideSheet)
                                                                    IconButton(
                                                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                                                      onPressed: () => Navigator.pop(timeSheetContext),
                                                                    ),
                                                                ],
                                                              ),
                                                              SizedBox(height: isTimeSheetCompact ? 20.h : 16.0),
                                                              ConstrainedBox(
                                                                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * (isTimeSideSheet ? 0.75 : 0.45)),
                                                                child: ListView.separated(
                                                                  shrinkWrap: true,
                                                                  padding: EdgeInsets.zero,
                                                                  itemCount: indices.length,
                                                                  separatorBuilder: (context, index) => SizedBox(height: isTimeSheetCompact ? 12.h : 10.0),
                                                                  itemBuilder: (context, idxPos) {
                                                                    final idx = indices[idxPos];
                                                                    final bool isCurrent = idx == current;
                                                                    final bool isOther = idx == other;
                                                                    return GestureDetector(
                                                                      onTap: () => Navigator.pop(timeSheetContext, idx),
                                                                      child: AnimatedContainer(
                                                                        duration: const Duration(milliseconds: 200),
                                                                        padding: EdgeInsets.all(isTimeSheetCompact ? 16.r : 14.0),
                                                                        decoration: BoxDecoration(
                                                                          color: isCurrent ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                                                                          borderRadius: BorderRadius.circular(isTimeSheetCompact ? 16.r : 12.0),
                                                                          border: Border.all(
                                                                            color: isCurrent ? AppColors.crimson : (isOther ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05)),
                                                                            width: 1.5,
                                                                          ),
                                                                        ),
                                                                        child: Row(
                                                                          children: [
                                                                            Icon(
                                                                              isCurrent ? Icons.check_circle_rounded : (isOther ? Icons.info_outline_rounded : Icons.radio_button_off_rounded),
                                                                              color: isCurrent ? AppColors.crimson : (isOther ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.2)),
                                                                              size: isTimeSheetCompact ? 20.r : 18.0,
                                                                            ),
                                                                            SizedBox(width: isTimeSheetCompact ? 16.w : 12.0),
                                                                            Text(
                                                                              DateFormat('hh:mm a').format(dates[idx]).toUpperCase(),
                                                                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                                                                color: isCurrent ? Colors.white : AppColors.textSecondary,
                                                                                fontWeight: FontWeight.w500,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                            if (timeResult != null && context.mounted) Navigator.pop(sheetContext, timeResult);
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: EdgeInsets.all(isSheetCompact ? 16.r : 14.0),
                                          decoration: BoxDecoration(
                                            color: isPartiallySelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(isSheetCompact ? 16.r : 12.0),
                                            border: Border.all(
                                              color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05)),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isPartiallySelected ? Icons.check_circle_rounded : (isOccupiedByOther ? Icons.info_outline_rounded : Icons.calendar_today_rounded),
                                                color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.2)),
                                                size: isSheetCompact ? 20.r : 18.0,
                                              ),
                                              SizedBox(width: isSheetCompact ? 16.w : 12.0),
                                              Text(
                                                DateFormat('MMMM dd, yyyy').format(displayDate).toUpperCase(),
                                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                                  color: isPartiallySelected ? Colors.white : AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Spacer(),
                                              if (indices.length > 1)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: isSheetCompact ? 8.w : 6.0, vertical: isSheetCompact ? 4.h : 2.0),
                                                  decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(isSheetCompact ? 8.r : 6.0)),
                                                  child: Text("${indices.length} LOGS", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5))),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
    if (result != null) onChanged(result);
  }

  Widget _buildComparisonDetails(BuildContext context) {
    final List<Widget> items = [];
    final v1 = data["duration"]?[idx1!];
    final v2 = data["duration"]?[idx2!];
    if (v1 != null && v2 != null) {
      items.add(_buildMetricComparison(context, "SLEEP DURATION", v1, v2, "hr", AppColors.crimson));
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 16.0),
          child: Text(
            "NO OVERLAPPING METRICS ON THESE DATES", 
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3))
          ),
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildMetricComparison(BuildContext context, String label, double v1, double v2, String unit, Color color) {
    final delta = v2 - v1;
    final percent = v1 != 0 ? (delta / v1.abs()) * 100 : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 12.0),
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: color, fontWeight: FontWeight.w500, letterSpacing: 1)),
              Row(
                children: [
                  Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, size: isCompact ? 18.r : 16.0),
                  SizedBox(width: isCompact ? 6.w : 4.0),
                  Text("${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          SizedBox(height: isCompact ? 20.h : 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _valItem(context, "Point A", v1, unit),
              _valItem(context, "Point B", v2, unit),
              _valItem(context, "Difference", delta, unit, isDelta: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valItem(BuildContext context, String l, double v, String u, {bool isDelta = false}) {
    return Column(
      children: [
        Text(l, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
        SizedBox(height: isCompact ? 4.h : 2.0),
        Text("${v >= 0 && isDelta ? '+' : ''}${v.toStringAsFixed(1)}$u", style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
