import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

enum AnalysisMode { daily, weekly, monthly, yearly }

class MetricMetadata {
  final String label;
  final Color color;
  final String unit;

  MetricMetadata({
    required this.label,
    required this.color,
    required this.unit,
  });
}

class PerformanceGraph extends StatefulWidget {
  final List<DateTime> dates;
  final Map<String, List<double?>> series;
  final Map<String, List<double?>> rawSeries;
  final Set<String> visibleMetrics;
  final Map<String, MetricMetadata> metadata;
  final bool isBarChart;
  final ScrollController? syncController;
  final AnalysisMode mode;
  final bool isAbsolute; // NEW: Use raw values on Y-axis
  final String? yUnit;   // NEW: Custom unit label for Y-axis

  const PerformanceGraph({
    super.key,
    required this.dates,
    required this.series,
    required this.rawSeries,
    required this.visibleMetrics,
    required this.metadata,
    this.isBarChart = false,
    this.syncController,
    this.mode = AnalysisMode.weekly,
    this.isAbsolute = false,
    this.yUnit,
  });

  @override
  State<PerformanceGraph> createState() => _PerformanceGraphState();
}

class _PerformanceGraphState extends State<PerformanceGraph> {
  final double _pointSpacing = 100.w;

  List<DateTime> _activeDates = [];
  Map<String, List<double?>> _activeRawSeries = {};
  final Map<String, double> _baselines = {};

  void _processActiveData() {
    final activeIndices = <int>[];
    for (int i = 0; i < widget.dates.length; i++) {
      bool hasData = false;
      for (var key in widget.visibleMetrics) {
        if (widget.rawSeries[key] != null && 
            i < widget.rawSeries[key]!.length && 
            widget.rawSeries[key]![i] != null) {
          hasData = true;
          break;
        }
      }
      if (hasData) activeIndices.add(i);
    }

    _activeDates = activeIndices.map((idx) => widget.dates[idx]).toList();
    _activeRawSeries = {};
    for (var key in widget.rawSeries.keys) {
      _activeRawSeries[key] = activeIndices.map((idx) => widget.rawSeries[key]![idx]).toList();
    }

    _baselines.clear();
    for (var key in widget.visibleMetrics) {
      if (_activeRawSeries[key] != null) {
        for (var val in _activeRawSeries[key]!) {
          if (val != null && val != 0) {
            _baselines[key] = val;
            break;
          }
        }
      }
    }
  }

  double? _getDisplayValue(String key, int activeIndex) {
    if (widget.isAbsolute) {
      return _activeRawSeries[key]![activeIndex];
    }
    final val = _activeRawSeries[key]![activeIndex];
    final baseline = _baselines[key];
    if (val == null || baseline == null || baseline == 0) return null;
    return ((val - baseline) / baseline) * 100;
  }

  @override
  Widget build(BuildContext context) {
    _processActiveData();

    if (_activeDates.isEmpty) {
      return Center(
        child: Text(
          widget.visibleMetrics.isEmpty ? "SELECT METRICS TO VIEW ANALYSIS" : "NO DATA FOR SELECTED METRICS",
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3)),
        ),
      );
    }

    final double chartContentWidth = (_activeDates.length - 1) * _pointSpacing;
    final double screenWidth = MediaQuery.of(context).size.width - 64.w;
    final double finalWidth = chartContentWidth < screenWidth ? screenWidth : chartContentWidth;

    return SingleChildScrollView(
      controller: widget.syncController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        width: finalWidth + 64.w,
        padding: EdgeInsets.only(top: 60.h, bottom: 20.h, left: 48.w, right: 32.w),
        child: widget.isBarChart
            ? BarChart(_buildBarChartData())
            : LineChart(_buildChartData()),
      ),
    );
  }

  LineChartData _buildChartData() {
    final List<LineChartBarData> lineBarsData = [];
    final activeKeys = widget.visibleMetrics.where((k) => _activeRawSeries.containsKey(k)).toList();

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var key in activeKeys) {
      final spots = <FlSpot>[];
      for (int i = 0; i < _activeDates.length; i++) {
        final val = _getDisplayValue(key, i);
        if (val != null) {
          spots.add(FlSpot(i.toDouble(), val));
          if (val < minY) minY = val;
          if (val > maxY) maxY = val;
        }
      }

      if (spots.isNotEmpty) {
        final meta = widget.metadata[key]!;
        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: meta.color,
          barWidth: 2.0,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4.0,
              color: barData.color ?? Colors.white,
              strokeWidth: 2,
              strokeColor: AppColors.surface,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [meta.color.withValues(alpha : 0.1), meta.color.withValues(alpha : 0.0)],
            ),
          ),
        ));
      }
    }

    if (minY == double.infinity) {
      minY = widget.isAbsolute ? 0 : -10;
      maxY = widget.isAbsolute ? 100 : 10;
    } else {
      double buffer = (maxY - minY).abs() * 0.15;
      if (buffer == 0) buffer = widget.isAbsolute ? 10 : 5;
      minY = (minY - buffer).floorToDouble();
      maxY = (maxY + buffer).ceilToDouble();
      if (widget.isAbsolute && minY < 0) minY = 0;
    }

    return LineChartData(
      lineTouchData: _buildLineTouchData(activeKeys),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: true,
        horizontalInterval: widget.isAbsolute ? ((maxY - minY) / 5).clamp(1, 1000) : 10,
        getDrawingHorizontalLine: (value) => FlLine(
          color: (!widget.isAbsolute && value == 0) ? AppColors.crimson.withValues(alpha : 0.2) : AppColors.white.withValues(alpha : 0.03),
          strokeWidth: (!widget.isAbsolute && value == 0) ? 1.5 : 1,
          dashArray: (!widget.isAbsolute && value == 0) ? null : [5, 5],
        ),
        getDrawingVerticalLine: (_) => FlLine(color: AppColors.white.withValues(alpha : 0.05), strokeWidth: 1),
      ),
      titlesData: _buildTitlesData(minY, maxY),
      borderData: FlBorderData(show: false),
      minX: -0.2,
      maxX: _activeDates.length - 1 + 0.2,
      minY: minY,
      maxY: maxY,
      lineBarsData: lineBarsData,
    );
  }

  BarChartData _buildBarChartData() {
    final activeKeys = widget.visibleMetrics.where((k) => _activeRawSeries.containsKey(k)).toList();
    final List<BarChartGroupData> groups = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < _activeDates.length; i++) {
      final List<BarChartRodData> rods = [];
      for (var key in activeKeys) {
        final val = _getDisplayValue(key, i);
        if (val != null) {
          final meta = widget.metadata[key]!;
          rods.add(BarChartRodData(
            toY: val,
            color: meta.color,
            width: 14.w,
            borderRadius: BorderRadius.circular(4.r),
          ));
          if (val < minY) minY = val;
          if (val > maxY) maxY = val;
        }
      }
      if (rods.isNotEmpty) {
        groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 4.w));
      }
    }

    if (minY == double.infinity) {
      minY = widget.isAbsolute ? 0 : -10;
      maxY = widget.isAbsolute ? 100 : 10;
    } else {
      double buffer = (maxY - minY).abs() * 0.15;
      if (buffer == 0) buffer = widget.isAbsolute ? 10 : 5;
      minY = (minY - buffer).floorToDouble();
      maxY = (maxY + buffer).ceilToDouble();
      if (widget.isAbsolute && minY < 0) minY = 0;
    }

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      minY: minY,
      maxY: maxY,
      barTouchData: BarTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.surface.withValues(alpha : 0.95),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
             final key = activeKeys[rodIndex];
             final meta = widget.metadata[key]!;
             final ts = _activeDates[group.x.toInt()];
             final rawValue = _activeRawSeries[key]![group.x.toInt()];
             final displayValue = rod.toY;
             final bool isPct = !widget.isAbsolute;

             return BarTooltipItem(
               "${DateFormat('MMM dd, HH:mm').format(ts).toUpperCase()}\n",
               AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
               children: [
                 TextSpan(text: "${meta.label}: ", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                 TextSpan(text: "${rawValue?.toStringAsFixed(1) ?? "0.0"} ${meta.unit}", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: meta.color, fontWeight: FontWeight.w500)),
                 if (isPct) TextSpan(text: " (${displayValue >= 0 ? '+' : ''}${displayValue.toStringAsFixed(1)}%)", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: displayValue >= 0 ? AppColors.success : AppColors.crimson)),
               ],
             );
          }
        )
      ),
      titlesData: _buildTitlesData(minY, maxY),
      gridData: FlGridData(show: true, drawHorizontalLine: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: (!widget.isAbsolute && v == 0) ? AppColors.crimson.withValues(alpha : 0.2) : AppColors.white.withValues(alpha : 0.03)), getDrawingVerticalLine: (_) => FlLine(color: AppColors.white.withValues(alpha : 0.05))),
      borderData: FlBorderData(show: false),
      barGroups: groups,
    );
  }

  LineTouchData _buildLineTouchData(List<String> activeKeys) {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => AppColors.surface.withValues(alpha : 0.95),
        tooltipBorderRadius: BorderRadius.circular(12.r),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.asMap().entries.map((entry) {
            final spot = entry.value;
            final key = activeKeys[spot.barIndex];
            final meta = widget.metadata[key]!;
            final ts = _activeDates[spot.x.toInt()];
            final rawValue = _activeRawSeries[key]![spot.x.toInt()];
            final displayValue = spot.y;
            final bool isPct = !widget.isAbsolute;

            return LineTooltipItem(
              entry.key == 0 ? "${DateFormat('MMM dd, HH:mm').format(ts).toUpperCase()}\n" : "",
              AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
              children: [
                TextSpan(text: "${meta.label}: ", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                TextSpan(text: "${rawValue?.toStringAsFixed(1) ?? "0.0"} ${meta.unit}", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: meta.color, fontWeight: FontWeight.w500)),
                if (isPct) TextSpan(text: " (${displayValue >= 0 ? '+' : ''}${displayValue.toStringAsFixed(1)}%)", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: displayValue >= 0 ? AppColors.success : AppColors.crimson)),
              ],
            );
          }).toList();
        },
      ),
    );
  }

  FlTitlesData _buildTitlesData(double minY, double maxY) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 45,
          getTitlesWidget: (value, meta) {
            if (value == minY || value == maxY || (widget.isAbsolute ? (value % ((maxY - minY) / 4).ceil() == 0) : value == 0)) {
              String label = widget.isAbsolute ? "${value.toInt()}${widget.yUnit ?? ""}" : "${value > 0 ? '+' : ''}${value.toInt()}%";
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3)),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final int index = value.toInt();
            if (index < 0 || index >= _activeDates.length || value != index.toDouble()) {
              return const SizedBox.shrink();
            }

            final DateTime ts = _activeDates[index];
            String label;
            switch (widget.mode) {
              case AnalysisMode.daily:
                label = DateFormat('HH:mm').format(ts);
                break;
              case AnalysisMode.weekly:
                label = DateFormat('EEE').format(ts).toUpperCase();
                break;
              case AnalysisMode.monthly:
                label = DateFormat('MMM').format(ts).toUpperCase();
                break;
              case AnalysisMode.yearly:
                label = DateFormat('yyyy').format(ts);
                break;
            }

            return SideTitleWidget(
              meta: meta,
              space: 8,
              child: Text(
                label,
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha : 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
