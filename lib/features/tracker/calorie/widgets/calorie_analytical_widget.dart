import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:intl/intl.dart';

enum DatePickerFilterPreset { last7Days, last30Days, thisMonth, selectMonth, customRange }

class CalorieAnalyticalGraph extends StatefulWidget {
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Set<String> visibleMetrics;
  final Function(int) onPointSelected;
  final bool isCompact;

  const CalorieAnalyticalGraph({
    super.key,
    required this.dates,
    required this.data,
    required this.visibleMetrics,
    required this.onPointSelected,
    this.isCompact = false,
  });

  @override
  State<CalorieAnalyticalGraph> createState() => _CalorieAnalyticalGraphState();
}

class _CalorieAnalyticalGraphState extends State<CalorieAnalyticalGraph> {
  DatePickerFilterPreset _selectedPreset = DatePickerFilterPreset.last30Days;
  DateTime? _selectedMonth;
  DateTimeRange? _customRange;

  double _currentPos = 0;

  List<int> _getFilteredIndices() {
    if (widget.dates.isEmpty) return [];
    final now = DateTime.now();
    final indices = <int>[];

    for (int i = 0; i < widget.dates.length; i++) {
      final d = widget.dates[i];
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

  int get _currentIndex {
    final filtered = _getFilteredIndices();
    if (filtered.isEmpty) return 0;
    final clampedPos = _currentPos.round().clamp(0, filtered.length - 1);
    return filtered[clampedPos];
  }

  @override
  void initState() {
    super.initState();
    final filtered = _getFilteredIndices();
    _currentPos = filtered.isEmpty ? 0 : (filtered.length - 1).toDouble();
  }

  @override
  void didUpdateWidget(CalorieAnalyticalGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dates.length != oldWidget.dates.length && widget.dates.isNotEmpty) {
      final filtered = _getFilteredIndices();
      _currentPos = filtered.isEmpty ? 0 : (filtered.length - 1).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dates.isEmpty) return const SizedBox.shrink();

    final bool isCompact = widget.isCompact;
    final bool hasSelection = widget.visibleMetrics.isNotEmpty;
    final filteredIndices = _getFilteredIndices();

    return Column(
      children: [
        _buildGraphFilterBar(isCompact),
        SizedBox(height: isCompact ? 16.h : 12.0),

        if (filteredIndices.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: isCompact ? 32.h : 24.0),
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
          SizedBox(
            height: isCompact ? 220.h : 180.0,
            child: Stack(
              children: [
                if (hasSelection)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 40.w : 32.0),
                    child: LineChart(_buildChartData(isCompact, filteredIndices)),
                  )
                else
                  Center(
                    child: Text(
                      "SELECT A METRIC TO VIEW TRENDS",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.2),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (hasSelection)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      final double sensitivity = 0.04; 
                      setState(() {
                        _currentPos -= details.primaryDelta! * sensitivity;
                        _currentPos = _currentPos.clamp(0, (filteredIndices.length - 1).toDouble());
                      });
                      widget.onPointSelected(_currentIndex);
                    },
                    onHorizontalDragEnd: (_) {
                      setState(() {
                        _currentPos = _currentPos.round().clamp(0, filteredIndices.length - 1).toDouble();
                      });
                    },
                    child: const SizedBox.expand(),
                  ),
                if (hasSelection)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: isCompact ? 2.w : 2.0,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.crimson.withValues(alpha: 0.0),
                              AppColors.crimson.withValues(alpha: 0.2),
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
          
          SizedBox(height: isCompact ? 24.h : 20.0),

          if (hasSelection)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatMini("CALORIES", widget.data["calories"]?[_currentIndex], AppColors.crimson, isCompact),
                  _buildStatMini("PROTEIN", widget.data["protein"]?[_currentIndex], Colors.blueAccent, isCompact),
                  _buildStatMini("CARBS", widget.data["carbs"]?[_currentIndex], Colors.greenAccent, isCompact),
                  _buildStatMini("FATS", widget.data["fats"]?[_currentIndex], Colors.orangeAccent, isCompact),
                ],
              ),
            ),
          
          SizedBox(height: hasSelection ? (isCompact ? 32.h : 24.0) : 0),

          if (hasSelection) ...[
            Text(
              DateFormat('MMM dd, yyyy').format(widget.dates[_currentIndex]).toUpperCase(),
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              DateFormat('hh:mm a').format(widget.dates[_currentIndex]),
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ],

          SizedBox(height: isCompact ? 24.h : 20.0),

          Opacity(
            opacity: hasSelection ? 1.0 : 0.3,
            child: IgnorePointer(
              ignoring: !hasSelection,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 40.w : 32.0),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double trackWidth = constraints.maxWidth;
                        final double indicatorWidth = (trackWidth / (filteredIndices.isEmpty ? 1 : filteredIndices.length)).clamp(isCompact ? 40.w : 40.0, trackWidth);
                        final double scrollableWidth = trackWidth - indicatorWidth;
                        
                        final double leftOffset = filteredIndices.length > 1 
                            ? (_currentPos / (filteredIndices.length - 1)) * scrollableWidth
                            : 0;

                        return GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            final RenderBox box = context.findRenderObject() as RenderBox;
                            final localOffset = box.globalToLocal(details.globalPosition);
                            double percent = (localOffset.dx - (indicatorWidth / 2)) / scrollableWidth;
                            percent = percent.clamp(0.0, 1.0);
                            
                            final double newPos = percent * (filteredIndices.length - 1);
                            if (newPos != _currentPos) {
                              setState(() {
                                _currentPos = newPos;
                              });
                              widget.onPointSelected(_currentIndex);
                            }
                          },
                          onHorizontalDragEnd: (_) {
                            setState(() {
                              _currentPos = _currentPos.round().clamp(0, filteredIndices.length - 1).toDouble();
                            });
                          },
                          child: Container(
                            width: trackWidth,
                            height: isCompact ? 8.h : 6.0, 
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: leftOffset,
                                  child: Container(
                                    width: indicatorWidth,
                                    height: isCompact ? 8.h : 6.0,
                                    decoration: BoxDecoration(
                                      color: AppColors.crimson,
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "START",
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: AppColors.textSecondary.withValues(alpha: 0.2),
                          ),
                        ),
                        Text(
                          "LATEST",
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: AppColors.textSecondary.withValues(alpha: 0.2),
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
      ],
    );
  }

  Widget _buildGraphFilterBar(bool isCompact) {
    final bool isFiltered = _selectedPreset != DatePickerFilterPreset.last30Days;
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: isCompact ? 3.w : 2.5,
                height: isCompact ? 12.h : 12.0,
                decoration: BoxDecoration(
                  color: AppColors.crimson,
                  borderRadius: BorderRadius.circular(isCompact ? 2.r : 2.0),
                ),
              ),
              SizedBox(width: isCompact ? 8.w : 6.0),
              Text(
                "ENERGY TRENDS (KCAL)",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showFilterSheet(context, isCompact),
            icon: Icon(
              isFiltered ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
              color: isFiltered ? Colors.orangeAccent : AppColors.crimson,
              size: isCompact ? 20.r : 18.0,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Filter Graph Data",
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, bool isCompact) async {
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
                margin: EdgeInsets.only(bottom: isCompact ? 10.h : 8.0),
                padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
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
                      size: isCompact ? 20.r : 18.0,
                    ),
                    SizedBox(width: isCompact ? 16.w : 12.0),
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
                            fontSize: isCompact ? 9.sp : 10.0,
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
                                _currentPos = f.isEmpty ? 0 : (f.length - 1).toDouble();
                              });
                              if (_getFilteredIndices().isNotEmpty) widget.onPointSelected(_currentIndex);
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
                                _currentPos = f.isEmpty ? 0 : (f.length - 1).toDouble();
                              });
                              if (_getFilteredIndices().isNotEmpty) widget.onPointSelected(_currentIndex);
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
                                _currentPos = f.isEmpty ? 0 : (f.length - 1).toDouble();
                              });
                              if (_getFilteredIndices().isNotEmpty) widget.onPointSelected(_currentIndex);
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
                                _currentPos = f.isEmpty ? 0 : (f.length - 1).toDouble();
                              });
                              if (_getFilteredIndices().isNotEmpty) widget.onPointSelected(_currentIndex);
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

        final years = (widget.dates.map((d) => d.year).toSet().toList()..sort((a, b) => b.compareTo(a)));
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
        _currentPos = f.isEmpty ? 0 : (f.length - 1).toDouble();
      });
      if (_getFilteredIndices().isNotEmpty) widget.onPointSelected(_currentIndex);
    }
  }

  Future<void> _selectCustomRangeDialog(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: widget.dates.isNotEmpty ? widget.dates.first : DateTime(2020),
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
        _currentPos = f.isEmpty ? 0 : (f.length - 1).toDouble();
      });
      if (_getFilteredIndices().isNotEmpty) widget.onPointSelected(_currentIndex);
    }
  }

  Widget _buildStatMini(String label, double? value, Color color, bool isCompact) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          value != null ? value.round().toString() : "--",
          style: AppTextStyles.h3.adaptive(context).copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  LineChartData _buildChartData(bool isCompact, List<int> filteredIndices) {
    final List<LineChartBarData> lineBarsData = [];
    
    final metrics = {
      "calories": AppColors.crimson,
      "protein": Colors.blueAccent,
      "carbs": Colors.greenAccent,
      "fats": Colors.orangeAccent,
    };

    final double viewMinX = _currentPos - 2.0;
    final double viewMaxX = _currentPos + 2.0;

    final Map<String, List<double?>> normalized = {};
    for (var key in metrics.keys) {
      if (!widget.visibleMetrics.contains(key)) continue;
      final raw = widget.data[key] ?? [];
      
      final List<double> visibleValues = [];
      for (int i = 0; i < filteredIndices.length; i++) {
        final realIdx = filteredIndices[i];
        if (i >= viewMinX - 0.5 && i <= viewMaxX + 0.5 && realIdx < raw.length && raw[realIdx] != null) {
          visibleValues.add(raw[realIdx]!);
        }
      }
      
      if (visibleValues.isEmpty) continue;
      
      double min = visibleValues.reduce((a, b) => a < b ? a : b);
      double max = visibleValues.reduce((a, b) => a > b ? a : b);
      
      if (max == min) {
        normalized[key] = raw.map((v) => v == null ? null : 50.0).toList();
      } else {
        normalized[key] = raw.map((v) => v == null ? null : ((v - min) / (max - min)) * 100).toList();
      }
    }

    for (var entry in metrics.entries) {
      if (!widget.visibleMetrics.contains(entry.key)) continue;
      
      final spots = <FlSpot>[];
      final normData = normalized[entry.key] ?? [];
      
      for (int i = 0; i < filteredIndices.length; i++) {
        final realIdx = filteredIndices[i];
        if (realIdx < normData.length && normData[realIdx] != null) {
          final val = normData[realIdx]!;
          spots.add(FlSpot(i.toDouble(), val));
        }
      }

      if (spots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: entry.value,
          barWidth: 2.0,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              final bool isSelected = spot.x.round() == _currentPos.round();
              return FlDotCirclePainter(
                radius: isSelected ? 5.0 : 2.0,
                color: isSelected ? Colors.white : entry.value,
                strokeWidth: isSelected ? 3 : 0,
                strokeColor: entry.value,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [entry.value.withValues(alpha: 0.15), entry.value.withValues(alpha: 0)],
            ),
          ),
        ));
      }
    }

    return LineChartData(
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.white.withValues(alpha: 0.05),
          strokeWidth: 1,
          dashArray: [5, 5],
        ),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: _currentPos - 2.0,
      maxX: _currentPos + 2.0,
      minY: -10,
      maxY: 110,
      lineBarsData: lineBarsData,
      lineTouchData: const LineTouchData(enabled: false),
    );
  }
}

class CalorieComparisonWidget extends StatelessWidget {
  final int? idx1;
  final int? idx2;
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Function(int?) onPointAChanged;
  final Function(int?) onPointBChanged;
  final bool isCompact;

  const CalorieComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.dates,
    required this.data,
    required this.onPointAChanged,
    required this.onPointBChanged,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isCompact ? 28.r : 24.0),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPointPicker(
                  "POINT A", idx1, idx2, dates, onPointAChanged, context),
              SizedBox(width: isCompact ? 16.w : 12.0),
              _buildPointPicker(
                  "POINT B", idx2, idx1, dates, onPointBChanged, context,
                  isEnd: true),
            ],
          ),
          if (idx1 == null && idx2 == null) ...[
            SizedBox(height: isCompact ? 32.h : 24.0),
            Center(
              child: Text(
                "SELECT DATA POINTS TO ANALYZE",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  letterSpacing: 1,
                ),
              ),
            ),
          ] else
            if (idx1 != null && idx2 == null) ...[
              SizedBox(height: isCompact ? 24.h : 20.0),
              _buildSinglePointView(context, idx1!),
            ] else
              if (idx1 == null && idx2 != null) ...[
                SizedBox(height: isCompact ? 24.h : 20.0),
                _buildSinglePointView(context, idx2!),
              ] else
                ...[
                  SizedBox(height: isCompact ? 24.h : 20.0),
                  _buildIntervalHeader(context),
                  SizedBox(height: isCompact ? 16.h : 12.0),
                  _buildComparisonDetails(context),
                ],
        ],
      ),
    );
  }

  Widget _buildIntervalHeader(BuildContext context) {
    final duration = dates[idx2!].difference(dates[idx1!]).abs();
    final days = duration.inDays;
    final hrs = duration.inHours % 24;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
              Icons.timer_outlined, color: AppColors.crimson, size: 12.0),
          const SizedBox(width: 6.0),
          Text(
            "INTERVAL: ${days > 0 ? '${days}D ' : ''}${hrs}H",
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePointView(BuildContext context, int idx) {
    final metrics = [
      {
        'label': "CALORIES",
        'key': "calories",
        'color': AppColors.crimson,
        'unit': "kcal"
      },
      {
        'label': "PROTEIN",
        'key': "protein",
        'color': Colors.blueAccent,
        'unit': "kcal"
      },
      {
        'label': "CARBS",
        'key': "carbs",
        'color': Colors.greenAccent,
        'unit': "kcal"
      },
      {
        'label': "FATS",
        'key': "fats",
        'color': Colors.orangeAccent,
        'unit': "kcal"
      },
    ];

    final List<Widget> items = [];
    for (var m in metrics) {
      final val = data[m['key']]?[idx];
      if (val != null) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 2.5,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: m['color'] as Color,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      m['label'] as String,
                      style: AppTextStyles.labelSmall
                          .adaptive(context)
                          .copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  "${val.round()} ${m['unit']}",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 16.0),
          child: Text(
            "NO LOGGED METRICS FOR THIS POINT",
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildComparisonDetails(BuildContext context) {
    final List<Widget> items = [];

    final metrics = [
      {'label': "CALORIES", 'key': "calories", 'color': AppColors.crimson, 'unit': "kcal"},
      {'label': "PROTEIN", 'key': "protein", 'color': Colors.blueAccent, 'unit': "g"},
      {'label': "CARBS", 'key': "carbs", 'color': Colors.greenAccent, 'unit': "g"},
      {'label': "FATS", 'key': "fats", 'color': Colors.orangeAccent, 'unit': "g"},
    ];

    for (var m in metrics) {
      final v1 = data[m['key']]?[idx1!];
      final v2 = data[m['key']]?[idx2!];
      if (v1 != null && v2 != null) {
        items.add(_buildMetricComparison(context, m['label'] as String, v1, v2, m['unit'] as String, m['color'] as Color));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 16.0),
          child: Text(
            "NO OVERLAPPING METRICS ON THESE DATES",
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
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
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: color, fontWeight: FontWeight.w500, letterSpacing: 1)),
              Row(
                children: [
                  Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, size: 14.0),
                  const SizedBox(width: 4.0),
                  Text("${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12.0),
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
        const SizedBox(height: 2.0),
        Text("${v >= 0 && isDelta ? '+' : ''}${v.round()}$u", style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPointPicker(String title, int? selectedIdx, int? otherIdx,
      List<DateTime> dates, Function(int?) onChanged, BuildContext context,
      {bool isEnd = false}) {
    final labels = dates.map((d) =>
        DateFormat('MMM dd, HH:mm').format(d).toUpperCase()).toList();
    return Expanded(
      child: Column(
        crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment
            .start,
        children: [
          Row(
            mainAxisAlignment: isEnd ? MainAxisAlignment.end : MainAxisAlignment
                .start,
            children: [
              if (selectedIdx != null && isEnd) ...[
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(
                        color: AppColors.crimson.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.crimson,
                        size: isCompact ? 10.r : 8.0),
                  ),
                ),
                SizedBox(width: isCompact ? 8.w : 6.0),
              ],
              Text(title,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: selectedIdx != null ? AppColors.crimson : AppColors
                          .textSecondary.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2)),
              if (selectedIdx != null && !isEnd) ...[
                SizedBox(width: isCompact ? 8.w : 6.0),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(
                        color: AppColors.crimson.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.crimson,
                        size: isCompact ? 10.r : 8.0),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 10.h : 8.0),
          GestureDetector(
            onTap: () =>
                _showPicker(context, selectedIdx, otherIdx, dates, onChanged),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 10.0,
                  vertical: isCompact ? 12.h : 10.0),
              decoration: BoxDecoration(
                color: selectedIdx != null ? AppColors.crimson.withValues(
                    alpha: 0.05) : AppColors.surfaceLight.withValues(
                    alpha: 0.3),
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: Border.all(
                    color: selectedIdx != null ? AppColors.crimson.withValues(
                        alpha: 0.4) : AppColors.white.withValues(alpha: 0.05),
                    width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIdx != null
                      ? Icons.event_available_rounded
                      : Icons.event_note_rounded,
                      color: selectedIdx != null ? AppColors.crimson : AppColors
                          .textSecondary.withValues(alpha: 0.3),
                      size: isCompact ? 18.r : 16.0),
                  SizedBox(width: isCompact ? 10.w : 8.0),
                  Flexible(child: Text(
                      selectedIdx != null ? labels[selectedIdx] : "SET POINT",
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall
                          .adaptive(context)
                          .copyWith(
                          color: selectedIdx != null ? Colors.white : AppColors
                              .textSecondary.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, int? current, int? other,
      List<DateTime> dates, Function(int?) onChanged) async {
    DatePickerFilterPreset selectedPreset = DatePickerFilterPreset.last30Days;
    DateTime? selectedMonth;
    DateTimeRange? customRange;

    final int? result = await AdaptiveUtils.showAdaptiveSheet<int>(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) =>
          StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final now = DateTime.now();
              List<DateTime> filteredDates = [];
              if (selectedPreset == DatePickerFilterPreset.last7Days) {
                final cutoff = DateTime(now.year, now.month, now.day).subtract(
                    const Duration(days: 7));
                filteredDates = dates.where((d) =>
                d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)).toList();
              } else if (selectedPreset == DatePickerFilterPreset.last30Days) {
                final cutoff = DateTime(now.year, now.month, now.day).subtract(
                    const Duration(days: 30));
                filteredDates = dates.where((d) =>
                d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff)).toList();
              } else if (selectedPreset == DatePickerFilterPreset.thisMonth) {
                filteredDates = dates.where((d) =>
                d.year == now.year && d.month == now.month).toList();
              } else if (selectedPreset == DatePickerFilterPreset.selectMonth &&
                  selectedMonth != null) {
                filteredDates = dates.where((d) =>
                d.year == selectedMonth!.year &&
                    d.month == selectedMonth!.month).toList();
              } else if (selectedPreset == DatePickerFilterPreset.customRange &&
                  customRange != null) {
                final start = DateTime(
                    customRange!.start.year, customRange!.start.month,
                    customRange!.start.day);
                final end = DateTime(
                    customRange!.end.year, customRange!.end.month,
                    customRange!.end.day, 23, 59, 59);
                filteredDates = dates.where((d) =>
                (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
                    (d.isBefore(end) || d.isAtSameMomentAs(end))).toList();
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
              final sortedDateKeys = dateGroups.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool isSheetCompact = constraints.maxWidth < 600 &&
                      !isSideSheet;
                  final double sheetWidth = isSideSheet
                      ? constraints.maxWidth
                      : (isSheetCompact ? constraints.maxWidth : 600.0);

                  Widget buildChip(
                      {required String label, required bool isSelected, required VoidCallback onTap}) {
                    return GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isSheetCompact
                            ? 12.w
                            : 10.0, vertical: isSheetCompact ? 8.h : 6.0),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.crimson.withValues(
                              alpha: 0.15) : AppColors.surfaceLight.withValues(
                              alpha: 0.3),
                          borderRadius: BorderRadius.circular(
                              isSheetCompact ? 10.r : 8.0),
                          border: Border.all(
                            color: isSelected ? AppColors.crimson : AppColors
                                .white.withValues(alpha: 0.05),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          label,
                          style: AppTextStyles.labelSmall
                              .adaptive(context)
                              .copyWith(
                            color: isSelected ? AppColors.crimson : AppColors
                                .textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w500,
                            fontSize: isSheetCompact ? 10.sp : 11.0,
                          ),
                        ),
                      ),
                    );
                  }

                  return Align(
                    alignment: isSideSheet ? Alignment.center : Alignment
                        .bottomCenter,
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
                                ? const BorderRadius.horizontal(
                                left: Radius.circular(24.0))
                                : BorderRadius.vertical(top: Radius.circular(
                                isSheetCompact ? 32.r : 24.0)),
                            border: Border.all(
                                color: AppColors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            mainAxisSize: isSideSheet
                                ? MainAxisSize.max
                                : MainAxisSize.min,
                            children: [
                              if (isSideSheet) const SizedBox(height: 24.0),
                              if (!isSideSheet)
                                Container(
                                  width: isSheetCompact ? 40.w : 40.0,
                                  height: isSheetCompact ? 4.h : 4.0,
                                  margin: EdgeInsets.only(
                                      bottom: isSheetCompact ? 24.h : 20.0),
                                  decoration: BoxDecoration(
                                      color: AppColors.textSecondary.withValues(
                                          alpha: 0.2),
                                      borderRadius: BorderRadius.circular(2.r)),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                            isSheetCompact ? 10.r : 8.0),
                                        decoration: BoxDecoration(
                                            color: AppColors.crimson.withValues(
                                                alpha: 0.1),
                                            shape: BoxShape.circle),
                                        child: Icon(Icons.event_note_rounded,
                                            color: AppColors.crimson,
                                            size: isSheetCompact ? 24.r : 20.0),
                                      ),
                                      SizedBox(
                                          width: isSheetCompact ? 16.w : 12.0),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text("SELECT RECORDING",
                                              style: AppTextStyles.h3.adaptive(
                                                  context)),
                                          Text(
                                              "CHOOSE A DATE FROM YOUR HISTORY",
                                              style: AppTextStyles.labelSmall
                                                  .adaptive(context).copyWith(
                                                  color: AppColors.textSecondary
                                                      .withValues(alpha: 0.5),
                                                  letterSpacing: 1)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: AppColors.textSecondary,
                                          size: 20),
                                      onPressed: () =>
                                          Navigator.pop(sheetContext),
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
                                    isSelected: selectedPreset ==
                                        DatePickerFilterPreset.last7Days,
                                    onTap: () =>
                                        setSheetState(() =>
                                        selectedPreset =
                                            DatePickerFilterPreset.last7Days),
                                  ),
                                  buildChip(
                                    label: "LAST 30 DAYS",
                                    isSelected: selectedPreset ==
                                        DatePickerFilterPreset.last30Days,
                                    onTap: () =>
                                        setSheetState(() =>
                                        selectedPreset =
                                            DatePickerFilterPreset
                                                .last30Days),
                                  ),
                                  buildChip(
                                    label: "THIS MONTH",
                                    isSelected: selectedPreset ==
                                        DatePickerFilterPreset.thisMonth,
                                    onTap: () =>
                                        setSheetState(() =>
                                        selectedPreset =
                                            DatePickerFilterPreset.thisMonth),
                                  ),
                                  buildChip(
                                    label: selectedPreset ==
                                        DatePickerFilterPreset.selectMonth &&
                                        selectedMonth != null
                                        ? DateFormat('MMM yyyy').format(
                                        selectedMonth!).toUpperCase()
                                        : "SELECT MONTH ▾",
                                    isSelected: selectedPreset ==
                                        DatePickerFilterPreset.selectMonth,
                                    onTap: () async {
                                      final DateTime? pickedMonth = await showDialog<DateTime>(
                                        context: sheetContext,
                                        builder: (dialogCtx) {
                                          int tempYear = selectedMonth?.year ?? DateTime.now().year;
                                          int tempMonth = selectedMonth?.month ?? DateTime.now().month;

                                          final years = (dates.map((d) => d.year).toSet().toList()..sort((a, b) => b.compareTo(a)));
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
                                        setSheetState(() {
                                          selectedMonth = pickedMonth;
                                          selectedPreset =
                                              DatePickerFilterPreset
                                                  .selectMonth;
                                        });
                                      }
                                    },
                                  ),
                                  buildChip(
                                    label: selectedPreset ==
                                        DatePickerFilterPreset.customRange &&
                                        customRange != null
                                        ? "${DateFormat('MMM dd').format(
                                        customRange!.start)} - ${DateFormat(
                                        'MMM dd').format(customRange!.end)}"
                                        : "CUSTOM RANGE",
                                    isSelected: selectedPreset ==
                                        DatePickerFilterPreset.customRange,
                                    onTap: () async {
                                      final picked = await showDateRangePicker(
                                        context: sheetContext,
                                        firstDate: dates.isNotEmpty ? dates
                                            .first : DateTime(2020),
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
                                          selectedPreset =
                                              DatePickerFilterPreset
                                                  .customRange;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),

                              SizedBox(height: isSheetCompact ? 16.h : 14.0),

                              sortedDateKeys.isEmpty
                                  ? Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: isSheetCompact ? 32.h : 24.0),
                                child: Center(
                                  child: Text(
                                    "NO RECORDINGS FOR THIS PERIOD",
                                    style: AppTextStyles.labelSmall.adaptive(
                                        context).copyWith(
                                      color: AppColors.textSecondary.withValues(
                                          alpha: 0.4),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              )
                                  : ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxHeight: MediaQuery
                                        .of(context)
                                        .size
                                        .height * (isSideSheet ? 0.75 : 0.45)),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: sortedDateKeys.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(
                                          height: isSheetCompact ? 12.h : 10.0),
                                  itemBuilder: (context, i) {
                                    final String dateKey = sortedDateKeys[i];
                                    final List<
                                        int> indices = dateGroups[dateKey]!;
                                    final DateTime displayDate = dates[indices
                                        .first];

                                    bool isPartiallySelected = indices.contains(
                                        current);
                                    bool isOccupiedByOther = indices.contains(
                                        other);

                                    return GestureDetector(
                                      onTap: () async {
                                        if (indices.length == 1) {
                                          Navigator.pop(
                                              sheetContext, indices.first);
                                        } else {
                                          final int? timeResult = await AdaptiveUtils
                                              .showAdaptiveSheet<int>(
                                            context: context,
                                            sheetBuilder: (timeSheetContext,
                                                isTimeSideSheet) =>
                                                LayoutBuilder(
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
                                          if (timeResult != null &&
                                              context.mounted) {
                                            Navigator.pop(
                                              sheetContext, timeResult);
                                          }
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 200),
                                        padding: EdgeInsets.all(
                                            isSheetCompact ? 16.r : 14.0),
                                        decoration: BoxDecoration(
                                          color: isPartiallySelected
                                              ? AppColors.crimson.withValues(
                                              alpha: 0.1)
                                              : AppColors.background.withValues(
                                              alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                              isSheetCompact ? 16.r : 12.0),
                                          border: Border.all(
                                            color: isPartiallySelected
                                                ? AppColors.crimson
                                                : (isOccupiedByOther
                                                ? AppColors.crimson.withValues(
                                                alpha: 0.3)
                                                : AppColors.white.withValues(
                                                alpha: 0.05)),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPartiallySelected
                                                  ? Icons.check_circle_rounded
                                                  : (isOccupiedByOther ? Icons
                                                  .info_outline_rounded : Icons
                                                  .calendar_today_rounded),
                                              color: isPartiallySelected
                                                  ? AppColors.crimson
                                                  : (isOccupiedByOther
                                                  ? AppColors.crimson
                                                  .withValues(alpha: 0.5)
                                                  : AppColors.textSecondary
                                                  .withValues(alpha: 0.2)),
                                              size: isSheetCompact
                                                  ? 20.r
                                                  : 18.0,
                                            ),
                                            SizedBox(width: isSheetCompact
                                                ? 16.w
                                                : 12.0),
                                            Text(
                                              DateFormat('MMMM dd, yyyy')
                                                  .format(displayDate)
                                                  .toUpperCase(),
                                              style: AppTextStyles.labelSmall
                                                  .adaptive(context).copyWith(
                                                color: isPartiallySelected
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (indices.length > 1)
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: isSheetCompact
                                                        ? 8.w
                                                        : 6.0,
                                                    vertical: isSheetCompact ? 4
                                                        .h : 2.0),
                                                decoration: BoxDecoration(
                                                    color: AppColors.white
                                                        .withValues(
                                                        alpha: 0.05),
                                                    borderRadius: BorderRadius
                                                        .circular(isSheetCompact
                                                        ? 8.r
                                                        : 6.0)),
                                                child: Text(
                                                    "${indices.length} LOGS",
                                                    style: AppTextStyles
                                                        .labelSmall.adaptive(
                                                        context).copyWith(
                                                        color: AppColors
                                                            .textSecondary
                                                            .withValues(
                                                            alpha: 0.5))),
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
}