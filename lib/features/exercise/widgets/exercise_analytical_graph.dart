import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/features/tracker/calorie/widgets/calorie_analytical_widget.dart';
import 'package:intl/intl.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:provider/provider.dart';
import '../../tracker/cycle_tracker/model/exercise_log.dart';

class ExerciseAnalyticalGraph extends StatefulWidget {
  final List<ExerciseLog> logs;
  final Function(int) onPointSelected;
  final bool? isTablet;

  const ExerciseAnalyticalGraph({
    super.key,
    required this.logs,
    required this.onPointSelected,
    this.isTablet,
  });

  @override
  State<ExerciseAnalyticalGraph> createState() => _ExerciseAnalyticalGraphState();
}

class _ExerciseAnalyticalGraphState extends State<ExerciseAnalyticalGraph> {
  DatePickerFilterPreset _selectedPreset = DatePickerFilterPreset.last30Days;
  DateTime? _selectedMonth;
  DateTimeRange? _customRange;

  late PageController _pageController;
  int _currentIndex = 0;
  
  final Set<String> _visibleMetrics = {"weight", "pos", "neg", "hold", "forced"};
  int? _comparisonIdx1;
  int? _comparisonIdx2;

  List<int> _getFilteredIndices() {
    if (widget.logs.isEmpty) return [];
    final now = DateTime.now();
    final indices = <int>[];

    for (int i = 0; i < widget.logs.length; i++) {
      final d = widget.logs[i].timestamp;
      if (_selectedPreset == DatePickerFilterPreset.last7Days) {
        final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        if (d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)) indices.add(i);
      } else if (_selectedPreset == DatePickerFilterPreset.last30Days) {
        final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        if (d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)) indices.add(i);
      } else if (_selectedPreset == DatePickerFilterPreset.thisMonth) {
        if (d.year == now.year && d.month == now.month) indices.add(i);
      } else if (_selectedPreset == DatePickerFilterPreset.selectMonth && _selectedMonth != null) {
        if (d.year == _selectedMonth!.year && d.month == _selectedMonth!.month) indices.add(i);
      } else if (_selectedPreset == DatePickerFilterPreset.customRange && _customRange != null) {
        final start = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
        final end = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
        if ((d.isAfter(start) || d.isAtSameMomentAs(start)) && (d.isBefore(end) || d.isAtSameMomentAs(end))) indices.add(i);
      } else {
        indices.add(i);
      }
    }
    return indices;
  }

  @override
  void initState() {
    super.initState();
    final filtered = _getFilteredIndices();
    _currentIndex = filtered.isEmpty ? 0 : filtered.length - 1;
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.28,
    );
  }

  @override
  void didUpdateWidget(ExerciseAnalyticalGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length && widget.logs.isNotEmpty) {
      final filtered = _getFilteredIndices();
      _currentIndex = filtered.isEmpty ? 0 : filtered.length - 1;
      _pageController.jumpToPage(_currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) return const SizedBox.shrink();

    final bool isTablet = widget.isTablet ?? (MediaQuery.of(context).size.width >= 600);
    final filteredIndices = _getFilteredIndices();

    return Column(
      children: [
        _buildGraphFilterBar(isTablet),
        SizedBox(height: isTablet ? 12.0 : 12.h),

        if (filteredIndices.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: isTablet ? 32.0 : 24.h),
            child: Center(
              child: Text(
                "NO DATA LOGGED FOR THIS PERIOD",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else ...[
          // ─── THE COMMAND GRAPH (Denser Snapping Workstation) ───────────────
          SizedBox(
            height: isTablet ? 180.0 : 180.h, 
            child: Stack(
              children: [
                _buildGlobalGrid(isTablet),

                PageView.builder(
                  controller: _pageController,
                  itemCount: filteredIndices.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    widget.onPointSelected(filteredIndices[index]);
                  },
                  itemBuilder: (context, index) {
                    final bool isFocused = index == _currentIndex;
                    final double opacity = isFocused ? 1.0 : 0.35;

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: opacity,
                      child: Center(
                        child: BarChart(_buildChartDataForIndex(filteredIndices[index], isFocused, isTablet)),
                      ),
                    );
                  },
                ),
                
                // Central Focus Needle
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: isTablet ? 2.0 : 2.w,
                      height: isTablet ? 120.0 : 120.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.crimson.withValues(alpha: 0.0),
                            AppColors.crimson.withValues(alpha: 0.4),
                            AppColors.crimson.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: isTablet ? 16.0 : 24.h),

          _buildStatsBreakdown(widget.logs[filteredIndices[_currentIndex.clamp(0, filteredIndices.length - 1)]], isTablet),
          
          SizedBox(height: isTablet ? 20.0 : 32.h),

          Text(
            DateFormat('MMMM dd, yyyy').format(widget.logs[filteredIndices[_currentIndex.clamp(0, filteredIndices.length - 1)]].timestamp).toUpperCase(),
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: isTablet ? 6.0 : 8.h),
          Text(
            DateFormat('hh:mm a').format(widget.logs[filteredIndices[_currentIndex.clamp(0, filteredIndices.length - 1)]].timestamp),
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
          ),

          SizedBox(height: isTablet ? 16.0 : 24.h),

          // ─── TIMELINE SLIDER ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24.0 : 40.w),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double trackWidth = constraints.maxWidth;
                    final double indicatorWidth = (trackWidth / (filteredIndices.isEmpty ? 1 : filteredIndices.length)).clamp(isTablet ? 40.0 : 40.w, trackWidth);
                    final double scrollableWidth = trackWidth - indicatorWidth;
                    
                    final double progress = filteredIndices.length > 1 
                        ? _currentIndex / (filteredIndices.length - 1)
                        : 0;
                    
                    final double leftOffset = progress * scrollableWidth;

                    return GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final localOffset = box.globalToLocal(details.globalPosition);
                        double percent = (localOffset.dx - (indicatorWidth / 2)) / scrollableWidth;
                        percent = percent.clamp(0.0, 1.0);
                        
                        final int targetPage = (percent * (filteredIndices.length - 1)).round();
                        if (targetPage != _currentIndex) {
                          _pageController.jumpToPage(targetPage);
                        }
                      },
                      child: Container(
                        width: trackWidth,
                        height: isTablet ? 8.0 : 8.h, 
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(isTablet ? 10.0 : 10.r),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: leftOffset,
                              child: Container(
                                width: indicatorWidth,
                                height: isTablet ? 8.0 : 8.h,
                                decoration: BoxDecoration(
                                  color: AppColors.crimson,
                                  borderRadius: BorderRadius.circular(isTablet ? 10.0 : 10.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ),
                  );
                },
              ),
              SizedBox(height: isTablet ? 8.0 : 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("OLDEST", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2))),
                  Text("LATEST", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2))),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: isTablet ? 24.0 : 40.h),
        _buildSectionHeader("METRIC OVERLAY", isTablet),
        SizedBox(height: isTablet ? 12.0 : 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 16.0 : 24.w),
          child: Wrap(
            spacing: isTablet ? 10.0 : 10.w,
            runSpacing: isTablet ? 10.0 : 10.h,
            children: [
              _buildMetricToggle("WEIGHT", "weight", AppColors.crimson, isTablet),
              _buildMetricToggle("POS REPS", "pos", Colors.blueAccent, isTablet),
              _buildMetricToggle("NEG REPS", "neg", Colors.tealAccent, isTablet),
              _buildMetricToggle("STATIC", "hold", Colors.orangeAccent, isTablet),
              _buildMetricToggle("FORCED", "forced", Colors.purpleAccent, isTablet),
            ],
          ),
        ),

        SizedBox(height: isTablet ? 24.0 : 40.h),
        _buildSectionHeader("DATA COMPARISON", isTablet),
        SizedBox(height: isTablet ? 12.0 : 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 16.0 : 24.w),
          child: ExerciseComparisonWidget(
            idx1: _comparisonIdx1,
            idx2: _comparisonIdx2,
            logs: widget.logs,
            isTablet: isTablet,
            onPointAChanged: (val) => setState(() => _comparisonIdx1 = val),
            onPointBChanged: (val) => setState(() => _comparisonIdx2 = val),
          ),
        ),
      ],
    ],
  );
}

  Widget _buildGraphFilterBar(bool isTablet) {
    final bool isFiltered = _selectedPreset != DatePickerFilterPreset.last30Days;
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: !isTablet ? 3.w : 2.5,
                height: !isTablet ? 12.h : 12.0,
                decoration: BoxDecoration(
                  color: AppColors.crimson,
                  borderRadius: BorderRadius.circular(!isTablet ? 2.r : 2.0),
                ),
              ),
              SizedBox(width: !isTablet ? 8.w : 6.0),
              Text(
                "EXERCISE TRENDS",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showFilterSheet(context, isTablet),
            icon: Icon(
              isFiltered ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
              color: isFiltered ? Colors.orangeAccent : AppColors.crimson,
              size: isTablet ? 20.0 : 18.0,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Filter Graph Data",
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, bool isTablet) async {
    await AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget buildFilterOption({
            required String label,
            required String sublabel,
            required bool isSelected,
            required VoidCallback onTap,
          }) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(sheetContext);
                onTap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: isTablet ? 10.0 : 8.0),
                padding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(isTablet ? 16.0 : 12.0),
                  border: Border.all(
                    color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.3),
                      size: isTablet ? 20.0 : 18.0,
                    ),
                    SizedBox(width: isTablet ? 16.0 : 12.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          sublabel,
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: AppColors.textSecondary.withValues(alpha: 0.4),
                            fontSize: isTablet ? 9.sp : 10.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (ctx, constraints) {
              final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
              final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 600.0);

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
                                    child: Icon(Icons.tune_rounded, color: AppColors.crimson, size: isSheetCompact ? 24.r : 20.0),
                                  ),
                                  SizedBox(width: isSheetCompact ? 16.w : 12.0),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("FILTER GRAPH TRENDS", style: AppTextStyles.h3.adaptive(context)),
                                      Text("SELECT RANGE FOR CHART DATA", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 1)),
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
                          SizedBox(height: isSheetCompact ? 20.h : 16.0),

                          buildFilterOption(
                            label: "LAST 7 DAYS",
                            sublabel: "SHOW DATA FROM THE LAST WEEK",
                            isSelected: _selectedPreset == DatePickerFilterPreset.last7Days,
                            onTap: () {
                              setState(() {
                                _selectedPreset = DatePickerFilterPreset.last7Days;
                                final f = _getFilteredIndices();
                                _currentIndex = f.isEmpty ? 0 : f.length - 1;
                                if (f.isNotEmpty) _pageController.jumpToPage(_currentIndex);
                              });
                              final f = _getFilteredIndices();
                              if (f.isNotEmpty) widget.onPointSelected(f[_currentIndex]);
                            },
                          ),
                          buildFilterOption(
                            label: "LAST 30 DAYS",
                            sublabel: "SHOW DATA FROM THE LAST 30 DAYS (DEFAULT)",
                            isSelected: _selectedPreset == DatePickerFilterPreset.last30Days,
                            onTap: () {
                              setState(() {
                                _selectedPreset = DatePickerFilterPreset.last30Days;
                                final f = _getFilteredIndices();
                                _currentIndex = f.isEmpty ? 0 : f.length - 1;
                                if (f.isNotEmpty) _pageController.jumpToPage(_currentIndex);
                              });
                              final f = _getFilteredIndices();
                              if (f.isNotEmpty) widget.onPointSelected(f[_currentIndex]);
                            },
                          ),
                          buildFilterOption(
                            label: "THIS MONTH",
                            sublabel: "SHOW DATA FOR THE CURRENT CALENDAR MONTH",
                            isSelected: _selectedPreset == DatePickerFilterPreset.thisMonth,
                            onTap: () {
                              setState(() {
                                _selectedPreset = DatePickerFilterPreset.thisMonth;
                                final f = _getFilteredIndices();
                                _currentIndex = f.isEmpty ? 0 : f.length - 1;
                                if (f.isNotEmpty) _pageController.jumpToPage(_currentIndex);
                              });
                              final f = _getFilteredIndices();
                              if (f.isNotEmpty) widget.onPointSelected(f[_currentIndex]);
                            },
                          ),
                          buildFilterOption(
                            label: "ALL TIME",
                            sublabel: "SHOW ALL HISTORICAL DATA LOGS",
                            isSelected: _selectedPreset == DatePickerFilterPreset.selectMonth && _selectedMonth == null && _customRange == null,
                            onTap: () {
                              setState(() {
                                _selectedPreset = DatePickerFilterPreset.selectMonth;
                                _selectedMonth = null;
                                _customRange = null;
                                final f = _getFilteredIndices();
                                _currentIndex = f.isEmpty ? 0 : f.length - 1;
                                if (f.isNotEmpty) _pageController.jumpToPage(_currentIndex);
                              });
                              final f = _getFilteredIndices();
                              if (f.isNotEmpty) widget.onPointSelected(f[_currentIndex]);
                            },
                          ),
                          buildFilterOption(
                            label: _selectedPreset == DatePickerFilterPreset.selectMonth && _selectedMonth != null
                                ? DateFormat('MMM yyyy').format(_selectedMonth!).toUpperCase()
                                : "SELECT MONTH",
                            sublabel: "CHOOSE A SPECIFIC MONTH & YEAR",
                            isSelected: _selectedPreset == DatePickerFilterPreset.selectMonth && _selectedMonth != null,
                            onTap: () => _selectMonthYearDialog(context),
                          ),
                          buildFilterOption(
                            label: _selectedPreset == DatePickerFilterPreset.customRange && _customRange != null
                                ? "${DateFormat('MMM dd').format(_customRange!.start)} - ${DateFormat('MMM dd').format(_customRange!.end)}"
                                : "CUSTOM RANGE",
                            sublabel: "CHOOSE A CUSTOM START AND END DATE",
                            isSelected: _selectedPreset == DatePickerFilterPreset.customRange,
                            onTap: () => _selectCustomRangeDialog(context),
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
  }

  Future<void> _selectMonthYearDialog(BuildContext context) async {
    final DateTime? pickedMonth = await showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) {
        int tempYear = _selectedMonth?.year ?? DateTime.now().year;
        int tempMonth = _selectedMonth?.month ?? DateTime.now().month;

        final years = (widget.logs.map((d) => d.timestamp.year).toSet().toList()..sort((a, b) => b.compareTo(a)));
        if (!years.contains(tempYear)) years.add(tempYear);
        years.sort((a, b) => b.compareTo(a));

        final initialYearIndex = years.indexOf(tempYear);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: BorderSide(color: AppColors.white.withValues(alpha: 0.05)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
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
                      const SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text("MONTH", style: AppTextStyles.labelSmall.adaptive(dialogCtx).copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
                          Text("YEAR", style: AppTextStyles.labelSmall.adaptive(dialogCtx).copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      SizedBox(
                        height: 140,
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 36.0,
                                scrollController: FixedExtentScrollController(initialItem: tempMonth - 1),
                                selectionOverlay: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.crimson.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                                  ),
                                ),
                                onSelectedItemChanged: (index) {
                                  setDialogState(() => tempMonth = index + 1);
                                },
                                children: List.generate(12, (i) {
                                  final monthName = DateFormat('MMMM').format(DateTime(2024, i + 1)).toUpperCase();
                                  return Center(
                                    child: Text(
                                      monthName,
                                      style: AppTextStyles.labelSmall.adaptive(dialogCtx).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 36.0,
                                scrollController: FixedExtentScrollController(initialItem: initialYearIndex >= 0 ? initialYearIndex : 0),
                                selectionOverlay: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.crimson.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                                  ),
                                ),
                                onSelectedItemChanged: (index) {
                                  setDialogState(() => tempYear = years[index]);
                                },
                                children: years.map((y) {
                                  return Center(
                                    child: Text(
                                      "$y",
                                      style: AppTextStyles.labelSmall.adaptive(dialogCtx).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20.0),
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
              ),
            );
          },
        );
      },
    );

    if (pickedMonth != null) {
      setState(() {
        _selectedMonth = pickedMonth;
        _selectedPreset = DatePickerFilterPreset.selectMonth;
        final f = _getFilteredIndices();
        _currentIndex = f.isEmpty ? 0 : f.length - 1;
        if (f.isNotEmpty) _pageController.jumpToPage(_currentIndex);
      });
      final f = _getFilteredIndices();
      if (f.isNotEmpty) widget.onPointSelected(f[_currentIndex]);
    }
  }

  Future<void> _selectCustomRangeDialog(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: widget.logs.isNotEmpty ? widget.logs.first.timestamp : DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
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
      setState(() {
        _customRange = picked;
        _selectedPreset = DatePickerFilterPreset.customRange;
        final f = _getFilteredIndices();
        _currentIndex = f.isEmpty ? 0 : f.length - 1;
        if (f.isNotEmpty) _pageController.jumpToPage(_currentIndex);
      });
      final f = _getFilteredIndices();
      if (f.isNotEmpty) widget.onPointSelected(f[_currentIndex]);
    }
  }

  Widget _buildSectionHeader(String title, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(left: isTablet ? 16.0 : 24.w),
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

  Widget _buildMetricToggle(String label, String key, Color color, bool isTablet) {
    final bool isActive = _visibleMetrics.contains(key);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_visibleMetrics.contains(key)) {
            if (_visibleMetrics.length > 1) _visibleMetrics.remove(key);
          } else {
            _visibleMetrics.add(key);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 16.0 : 16.w, vertical: isTablet ? 10.0 : 10.h),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(isTablet ? 12.0 : 12.r),
          border: Border.all(
            color: isActive ? color : AppColors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isTablet ? 8.0 : 8.r,
              height: isTablet ? 8.0 : 8.r,
              decoration: BoxDecoration(
                color: isActive ? color : AppColors.textSecondary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: isTablet ? 10.0 : 10.w),
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

  Widget _buildStatsBreakdown(ExerciseLog log, bool isTablet) {
    final provider = context.read<CycleProvider>();
    final bool isKg = provider.settings.weightUnit == WeightUnit.kgs;
    final double displayWeight = isKg ? log.weightKg : log.weightLbs;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 12.0 : 12.w),
      child: Wrap(
        spacing: isTablet ? 12.0 : 12.w,
        runSpacing: isTablet ? 12.0 : 12.h,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end, // Align all columns by their bottom edge
        children: [
          _buildMetricItem("WEIGHT", displayWeight > 0 ? double.parse(displayWeight.toStringAsFixed(3)).toString() : "--", displayWeight > 0 ? (isKg ? "KG" : "LBS") : "", AppColors.crimson, isTablet),
          _buildMetricItem("POS", log.positiveReps > 0 ? "${log.positiveReps}" : "--", "", Colors.blueAccent, isTablet, valueColor: Colors.blueAccent),
          _buildMetricItem("NEG", log.negativeReps > 0 ? "${log.negativeReps}" : "--", "", Colors.tealAccent, isTablet, valueColor: Colors.tealAccent),
          _buildMetricItem("HOLD", log.staticHoldSeconds > 0 ? "${log.staticHoldSeconds}" : "--", log.staticHoldSeconds > 0 ? "S" : "", Colors.orangeAccent, isTablet, valueColor: Colors.orangeAccent),
          _buildMetricItem("FORCE", log.forcedReps > 0 ? "${log.forcedReps}" : "--", "", Colors.purpleAccent, isTablet, valueColor: Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String unit, Color color, bool isTablet, {Color valueColor = Colors.white}) {
    // Determine if we should show neutral color for "--" empty state
    final bool isNoData = value == "--";
    final Color displayValueColor = isNoData ? AppColors.textSecondary.withValues(alpha: 0.3) : valueColor;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: isTablet ? 4.0 : 4.h),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTextStyles.h2.adaptive(context).copyWith(
                color: displayValueColor,
                fontWeight: FontWeight.w500,
                height: 1, 
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                " $unit",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  height: 1, 
                ),
              ),
          ],
        ),
      ],
    );
  }

  BarChartData _buildChartDataForIndex(int index, bool isFocused, bool isTablet) {
    final log = widget.logs[index];
    
    double globalMaxWeight = 0;
    for (var l in widget.logs) {
      final w = context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs ? l.weightKg : l.weightLbs;
      if (w > globalMaxWeight) globalMaxWeight = w;
    }
    if (globalMaxWeight == 0) globalMaxWeight = 100;

    return BarChartData(
      maxY: 100,
      minY: 0,
      alignment: BarChartAlignment.center,
      barTouchData: BarTouchData(enabled: false),
      titlesData: const FlTitlesData(show: false),
      gridData: const FlGridData(show: false), // Grid is now global background
      borderData: FlBorderData(show: false),
      barGroups: [
        _makeGroupData(index, log, globalMaxWeight, isFocused, isTablet),
      ],
    );
  }

  Widget _buildGlobalGrid(bool isTablet) {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24.0 : 40.w),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.white.withValues(alpha: 0.05),
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [const FlSpot(0, 0), const FlSpot(1, 0)],
                show: false, // Transparent data, we only want the grid
              ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, ExerciseLog log, double maxWeight, bool isFocused, bool isTablet) {
    final bool isKg = context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs;
    final double weightValue = isKg ? log.weightKg : log.weightLbs;

    double weightH = (weightValue / maxWeight) * 100;
    double posH = (log.positiveReps / 12) * 100;
    double negH = (log.negativeReps / 12) * 100;
    double staticH = (log.staticHoldSeconds / 30) * 100;
    double forcedH = (log.forcedReps / 6) * 100;

    const double floor = 2.0; 

    final List<BarChartRodData> rods = [];
    
    if (_visibleMetrics.contains("weight")) rods.add(_makePremiumRod(weightH.clamp(floor, 100), AppColors.crimson, isTablet));
    if (_visibleMetrics.contains("pos")) rods.add(_makePremiumRod(posH.clamp(floor, 100), Colors.blueAccent, isTablet));
    if (_visibleMetrics.contains("neg") && log.negativeReps > 0) rods.add(_makePremiumRod(negH.clamp(floor, 100), Colors.tealAccent, isTablet));
    if (_visibleMetrics.contains("hold") && log.staticHoldSeconds > 0) rods.add(_makePremiumRod(staticH.clamp(floor, 100), Colors.orangeAccent, isTablet));
    if (_visibleMetrics.contains("forced") && log.forcedReps > 0) rods.add(_makePremiumRod(forcedH.clamp(floor, 100), Colors.purpleAccent, isTablet));

    return BarChartGroupData(
      x: x,
      barsSpace: isTablet ? 6.0 : 4.w,
      barRods: rods,
    );
  }

  BarChartRodData _makePremiumRod(double y, Color color, bool isTablet) {
    return BarChartRodData(
      toY: y,
      width: isTablet ? 14.0 : 14.w, // High DENSITY styling
      gradient: LinearGradient(
        colors: [color, color.withValues(alpha: 0.6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(isTablet ? 4.0 : 4.r),
      // Background "ghost" bars removed for cleaner aesthetic
      backDrawRodData: BackgroundBarChartRodData(show: false),
    );
  }
}

class ExerciseComparisonWidget extends StatelessWidget {
  final int? idx1;
  final int? idx2;
  final List<ExerciseLog> logs;
  final Function(int?) onPointAChanged;
  final Function(int?) onPointBChanged;
  final bool? isTablet;

  const ExerciseComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.logs,
    required this.onPointAChanged,
    required this.onPointBChanged,
    this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTab = isTablet ?? (MediaQuery.of(context).size.width >= 600);

    return Container(
      padding: EdgeInsets.all(isTab ? 20.0 : 24.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isTab ? 20.0 : 28.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPointPicker("POINT A", idx1, idx2, logs, onPointAChanged, context, isTab),
              SizedBox(width: isTab ? 16.0 : 16.w),
              _buildPointPicker("POINT B", idx2, idx1, logs, onPointBChanged, context, isTab, isEnd: true),
            ],
          ),
          if (idx1 != null && idx2 != null) ...[
            SizedBox(height: isTab ? 20.0 : 24.h),
            _buildComparisonDetails(context, isTab),
          ] else ...[
            SizedBox(height: isTab ? 24.0 : 32.h),
            Center(
              child: Text(
                "SELECT TWO POINTS TO COMPARE",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointPicker(String title, int? selectedIdx, int? otherIdx, List<ExerciseLog> logs, Function(int?) onChanged, BuildContext context, bool isTab, {bool isEnd = false}) {
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
                    padding: EdgeInsets.all(isTab ? 4.0 : 4.r),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isTab ? 12.0 : 12.r),
                  ),
                ),
                SizedBox(width: isTab ? 8.0 : 8.w),
              ],
              Flexible(
                child: Text(
                  title, 
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.4), 
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (selectedIdx != null && !isEnd) ...[
                SizedBox(width: isTab ? 8.0 : 8.w),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(isTab ? 4.0 : 4.r),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isTab ? 12.0 : 12.r),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isTab ? 8.0 : 10.h),
          GestureDetector(
            onTap: () => _showPicker(context, selectedIdx, otherIdx, logs, onChanged),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isTab ? 10.0 : 14.w, vertical: isTab ? 10.0 : 12.h),
              decoration: BoxDecoration(
                color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.05) : AppColors.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(isTab ? 12.0 : 12.r),
                border: Border.all(color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.4) : AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIdx != null ? Icons.event_available_rounded : Icons.event_note_rounded, color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.3), size: isTab ? 18.0 : 18.r),
                  SizedBox(width: isTab ? 10.0 : 10.w),
                  Flexible(child: Text(selectedIdx != null ? DateFormat('MM/dd').format(logs[selectedIdx].timestamp) : "SET", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: selectedIdx != null ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, int? current, int? other, List<ExerciseLog> logs, Function(int?) onChanged) async {
    final int? result = await AdaptiveUtils.showAdaptiveSheet<int>(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

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
                    isSheetCompact ? 40.h : 32.0
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
                      if (isSideSheet) SizedBox(height: 24.0),
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
                          Text("SELECT SESSION", style: AppTextStyles.h3.adaptive(context)),
                          if (isSideSheet)
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                        ],
                      ),
                      SizedBox(height: isSheetCompact ? 24.h : 20.0),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * (isSideSheet ? 0.8 : 0.5)),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: logs.length,
                          separatorBuilder: (context, index) => SizedBox(height: 12.h),
                          itemBuilder: (context, i) {
                            final log = logs[i];
                            final bool isSelected = i == current;
                            final bool isOther = i == other;

                            return GestureDetector(
                              onTap: isOther ? null : () => Navigator.pop(sheetContext, i),
                              child: Opacity(
                                opacity: isOther ? 0.4 : 1.0,
                                child: Container(
                                  padding: EdgeInsets.all(isSheetCompact ? 16.r : 16.0),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(isSheetCompact ? 16.r : 16.0),
                                    border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(DateFormat('MMMM dd, yyyy').format(log.timestamp).toUpperCase(), style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: isSelected ? Colors.white : AppColors.textSecondary)),
                                      const Spacer(),
                                      Text("${double.parse((context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs ? log.weightKg : log.weightLbs).toStringAsFixed(3)).toString()} KG", style: AppTextStyles.labelSmall.adaptive(context).copyWith(fontWeight: FontWeight.w500)),
                                    ],
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
              ),
            ),
          );
        },
      ),
    );
    if (result != null) onChanged(result);
  }

  Widget _buildComparisonDetails(BuildContext context, bool isTab) {
    final log1 = logs[idx1!];
    final log2 = logs[idx2!];
    final bool isKg = context.read<CycleProvider>().settings.weightUnit == WeightUnit.kgs;
    
    final List<Widget> items = [];
    items.add(_buildMetricComparison(context, "LOAD INTENSITY", isKg ? log1.weightKg : log1.weightLbs, isKg ? log2.weightKg : log2.weightLbs, "", AppColors.crimson, isTab, precision: 3));
    items.add(_buildMetricComparison(context, "POSITIVE REPS", log1.positiveReps.toDouble(), log2.positiveReps.toDouble(), "", Colors.blueAccent, isTab));
    
    if (log1.negativeReps > 0 || log2.negativeReps > 0) {
      items.add(_buildMetricComparison(context, "NEGATIVE REPS", log1.negativeReps.toDouble(), log2.negativeReps.toDouble(), "", Colors.tealAccent, isTab));
    }
    if (log1.staticHoldSeconds > 0 || log2.staticHoldSeconds > 0) {
      items.add(_buildMetricComparison(context, "STATIC HOLD", log1.staticHoldSeconds.toDouble(), log2.staticHoldSeconds.toDouble(), "S", Colors.orangeAccent, isTab));
    }

    return Column(children: items);
  }

  Widget _buildMetricComparison(BuildContext context, String label, double v1, double v2, String unit, Color color, bool isTab, {int precision = 1}) {
    final delta = v2 - v1;
    // We check neutrality based on the display precision to avoid -0.0 artifacts
    final double roundedDelta = double.parse(delta.toStringAsFixed(precision));
    final bool isNeutral = roundedDelta == 0;
    
    final Color trendColor = isNeutral ? AppColors.textSecondary.withValues(alpha: 0.5) : (delta > 0 ? Colors.greenAccent : Colors.redAccent);
    final IconData? trendIcon = isNeutral ? null : (delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded);

    final double percent = v1 != 0 ? (delta / v1.abs()) * 100 : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: isTab ? 12.0 : 16.h),
      padding: EdgeInsets.all(isTab ? 16.0 : 20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isTab ? 16.0 : 20.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: color, fontWeight: FontWeight.w500, letterSpacing: 1)),
              Row(
                children: [
                  if (trendIcon != null) ...[
                    Icon(trendIcon, color: trendColor, size: isTab ? 18.0 : 18.r),
                    SizedBox(width: isTab ? 6.0 : 6.w),
                  ],
                  Text(
                    isNeutral ? "0%" : "${delta > 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", 
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: trendColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isTab ? 16.0 : 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _valItem(context, "Point A", v1, "", precision),
              _valItem(context, "Point B", v2, "", precision),
              _valItem(context, "Difference", delta, unit, precision, isDelta: true, isNeutral: isNeutral),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valItem(BuildContext context, String l, double v, String u, int p, {bool isDelta = false, bool isNeutral = false}) {
    String text;
    if (isDelta && isNeutral) {
      text = "0"; // Display exactly "0" for neutral delta as requested
    } else {
      final String prefix = (isDelta && v > 0) ? "+" : "";
      text = "$prefix${double.parse(v.toStringAsFixed(3)).toString()}";
    }

    return Column(
      children: [
        Text(l, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
        SizedBox(height: 4.h),
        Text(
          "$text$u", 
          style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
