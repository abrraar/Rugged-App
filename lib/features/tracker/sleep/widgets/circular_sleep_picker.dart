import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

class CircularSleepPicker extends StatefulWidget {
  final TimeOfDay initialBedtime;
  final TimeOfDay initialWakeTime;
  final bool canSave;
  final String? disabledReason;
  final DateTime selectedDate;
  final int quality;
  final String note;
  final VoidCallback onPickDate;
  final Function(TimeOfDay bedtime, TimeOfDay wakeTime) onTimeChanged;
  final Function(int) onQualityChanged;
  final Function(String) onNoteChanged;
  final VoidCallback onSave;
  final bool use24HourClock;
  final bool isCompact;

  const CircularSleepPicker({
    super.key,
    required this.initialBedtime,
    required this.initialWakeTime,
    required this.canSave,
    this.disabledReason,
    required this.selectedDate,
    required this.quality,
    required this.note,
    required this.onPickDate,
    required this.onTimeChanged,
    required this.onQualityChanged,
    required this.onNoteChanged,
    required this.onSave,
    required this.use24HourClock,
    this.isCompact = true,
  });

  @override
  State<CircularSleepPicker> createState() => _CircularSleepPickerState();
}

class _CircularSleepPickerState extends State<CircularSleepPicker> {
  final GlobalKey _containerKey = GlobalKey();
  late double _startAngle;
  late double _endAngle;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _startAngle = _timeToAngle(widget.initialBedtime);
    _endAngle = _timeToAngle(widget.initialWakeTime);
    _noteController = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double _timeToAngle(TimeOfDay time) {
    final double totalMinutes = time.hour * 60.0 + time.minute;
    final double dayMinutes = 24.0 * 60.0;
    return ((totalMinutes / dayMinutes) * 2 * pi - (pi / 2)) % (2 * pi);
  }

  TimeOfDay _angleToTime(double angle) {
    double normalizedAngle = (angle + pi / 2) % (2 * pi);
    if (normalizedAngle < 0) normalizedAngle += 2 * pi;
    final double dayMinutes = 24.0 * 60.0;
    final int totalMinutes = ((normalizedAngle / (2 * pi)) * dayMinutes).round();
    return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
  }

  String _formatTime(double angle) {
    final time = _angleToTime(angle);
    if (widget.use24HourClock) {
      return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    } else {
      final int hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final String minute = time.minute.toString().padLeft(2, '0');
      final String period = time.period == DayPeriod.am ? "am" : "pm";
      return "$hour:$minute $period";
    }
  }

  Future<void> _pickTime(bool isBedtime) async {
    final initialTime = isBedtime ? _angleToTime(_startAngle) : _angleToTime(_endAngle);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      useRootNavigator: true,
      initialTime: initialTime,
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: widget.use24HourClock,
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isBedtime) {
          _startAngle = _timeToAngle(picked);
        } else {
          _endAngle = _timeToAngle(picked);
        }
      });
      widget.onTimeChanged(_angleToTime(_startAngle), _angleToTime(_endAngle));
    }
  }

  void _updateAngle(Offset localPosition, bool isStart) {
    final RenderBox? box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final center = box.size.center(Offset.zero);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final angle = atan2(dy, dx) % (2 * pi);

    setState(() {
      if (isStart) {
        _startAngle = angle;
      } else {
        _endAngle = angle;
      }
    });
    widget.onTimeChanged(_angleToTime(_startAngle), _angleToTime(_endAngle));
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration();
    final bool isCompact = widget.isCompact;
    final double containerSize = isCompact ? 300.0 : 280.0;
    final double ringRadius = isCompact ? 105.0 : 100.0;
    final double centerX = containerSize / 2;
    final double centerY = containerSize / 2;

    final EdgeInsets horizontalPad = EdgeInsets.symmetric(
      horizontal: isCompact ? 20.w : 24.0,
    );

    return Column(
      children: [
        SizedBox(
          key: _containerKey,
          width: containerSize,
          height: containerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Static Ring & Arc
              CustomPaint(
                size: Size(containerSize, containerSize),
                painter: SleepPickerPainter(
                  startAngle: _startAngle,
                  endAngle: _endAngle,
                  radius: ringRadius,
                  isCompact: isCompact,
                ),
              ),

              // 2. Center Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _pickTime(true),
                    child: Column(
                      children: [
                        Text(
                          "Fall asleep",
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            fontSize: 11.0,
                          ),
                        ),
                        Text(
                          _formatTime(_startAngle),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  SizedBox(
                    width: 140.0,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "${duration.inHours}",
                              style: AppTextStyles.h1.copyWith(
                                fontSize: 42.0,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: "hr",
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 20.0,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (duration.inMinutes % 60 > 0)
                              TextSpan(
                                text: " ${duration.inMinutes % 60}m",
                                style: AppTextStyles.h3.copyWith(
                                  fontSize: 16.0,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  GestureDetector(
                    onTap: () => _pickTime(false),
                    child: Column(
                      children: [
                        Text(
                          "Wake Up",
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            fontSize: 11.0,
                          ),
                        ),
                        Text(
                          _formatTime(_endAngle),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 3. Draggable Handles (Positioned relative to CENTER)
              _buildDraggableHandle(
                centerX: centerX,
                centerY: centerY,
                angle: _startAngle,
                radius: ringRadius,
                icon: Icons.bedtime_rounded,
                color: const Color(0xFF4A55A2),
                isStart: true,
                isDragging: _isDraggingStart,
                isCompact: isCompact,
              ),
              _buildDraggableHandle(
                centerX: centerX,
                centerY: centerY,
                angle: _endAngle,
                radius: ringRadius,
                icon: Icons.wb_sunny_rounded,
                color: Colors.yellow,
                isStart: false,
                isDragging: _isDraggingEnd,
                isCompact: isCompact,
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 28.h : 24.0),
        // Rating and Note
        Padding(
          padding: horizontalPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SESSION QUALITY",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                  fontSize: 11.0,
                ),
              ),
              SizedBox(height: isCompact ? 10.h : 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  final isSelected = rating <= widget.quality;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onQualityChanged(rating);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(isCompact ? 10.r : 8.0),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.surfaceLight.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: isSelected ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.2),
                        size: isCompact ? 24.r : 20.0,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: isCompact ? 20.h : 16.0),
              Text(
                "NOTES",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                  fontSize: 11.0,
                ),
              ),
              SizedBox(height: isCompact ? 10.h : 8.0),
              TextField(
                controller: _noteController,
                onChanged: widget.onNoteChanged,
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontSize: 14.0),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "How did you feel today?",
                  hintStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3), fontSize: 14.0),
                  filled: true,
                  fillColor: AppColors.surfaceLight.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                    borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                    borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                    borderSide: const BorderSide(color: AppColors.crimson),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 24.h : 20.0),
        // Date Picker Row
        Padding(
          padding: horizontalPad,
          child: GestureDetector(
            onTap: widget.onPickDate,
            child: Container(
              padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM dd, yyyy').format(widget.selectedDate).toUpperCase(),
                    style: AppTextStyles.labelMedium.copyWith(color: Colors.white, letterSpacing: 1, fontSize: 13.0),
                  ),
                  Icon(Icons.calendar_today_rounded, color: AppColors.crimson, size: isCompact ? 18.r : 16.0),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 16.h : 12.0),
        GestureDetector(
          onTap: widget.canSave ? widget.onSave : null,
          child: Opacity(
            opacity: widget.canSave ? 1.0 : 0.4,
            child: Container(
              margin: horizontalPad,
              height: isCompact ? 52.h : 48.0,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.crimson,
                borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                boxShadow: [
                  if (widget.canSave)
                    BoxShadow(color: AppColors.crimson.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.canSave ? "RECORD SLEEP" : (widget.disabledReason ?? "RECORD SLEEP"),
                style: AppTextStyles.buttonPrimary.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.2,
                  fontSize: widget.canSave ? 14.0 : 12.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableHandle({
    required double centerX,
    required double centerY,
    required double angle,
    required double radius,
    required IconData icon,
    required Color color,
    required bool isStart,
    required bool isDragging,
    required bool isCompact,
  }) {
    final x = centerX + radius * cos(angle);
    final y = centerY + radius * sin(angle);
    final double handleSize = isCompact ? 52.0 : 44.0;

    return Positioned(
      left: x - (handleSize / 2),
      top: y - (handleSize / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) {
          HapticFeedback.mediumImpact();
          setState(() {
            if (isStart) {
              _isDraggingStart = true;
            } else {
              _isDraggingEnd = true;
            }
          });
        },
        onLongPressMoveUpdate: (details) {
          final RenderBox? box = _containerKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null) {
            final localPos = box.globalToLocal(details.globalPosition);
            _updateAngle(localPos, isStart);
          }
        },
        onLongPressEnd: (_) {
          setState(() {
            _isDraggingStart = false;
            _isDraggingEnd = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isDragging ? color.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
                blurRadius: isDragging ? 15 : 8,
                spreadRadius: isDragging ? 2 : 0,
                offset: const Offset(0, 2),
              )
            ],
            border: Border.all(
              color: isDragging ? color : color.withValues(alpha: 0.6),
              width: isDragging ? 2.5 : 1.5,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: isCompact ? 26.0 : 20.0),
        ),
      ),
    );
  }

  Duration _calculateDuration() {
    final start = _angleToTime(_startAngle);
    final end = _angleToTime(_endAngle);
    int startMin = start.hour * 60 + start.minute;
    int endMin = end.hour * 60 + end.minute;
    int diff = endMin - startMin;
    if (diff <= 0) diff += 24 * 60;
    return Duration(minutes: diff);
  }
}

class SleepPickerPainter extends CustomPainter {
  final double startAngle;
  final double endAngle;
  final double radius;
  final bool isCompact;

  SleepPickerPainter({
    required this.startAngle, 
    required this.endAngle, 
    required this.radius,
    this.isCompact = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final strokeWidth = isCompact ? 32.0 : 30.0;

    final bgPaint = Paint()
      ..color = AppColors.surfaceLight.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    double sweepAngle = endAngle - startAngle;
    if (sweepAngle < 0) sweepAngle += 2 * pi;

    final double safeSweepAngle = sweepAngle.clamp(0.001, 2 * pi);

    final activePaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: safeSweepAngle,
        colors: const [
          Color(0xFF1A237E),
          Color(0xFF673AB7),
          Color(0xFFE91E63),
          Color(0xFFFFB74D),
          Colors.yellow,
        ],
        stops: const [0.0, 0.4, 0.7, 0.9, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
