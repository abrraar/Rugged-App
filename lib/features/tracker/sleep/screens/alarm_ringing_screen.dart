// lib/features/tracker/sleep/screens/alarm_ringing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import '../provider/sleep_alarm_provider.dart';
import 'package:intl/intl.dart';

class AlarmRingingScreen extends StatefulWidget {
  final int alarmId;
  final String label;

  const AlarmRingingScreen({
    super.key,
    required this.alarmId,
    required this.label,
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    setState(() {
      _dragValue += details.delta.dx / maxWidth;
      _dragValue = _dragValue.clamp(0.0, 1.0);
    });

    if (_dragValue >= 0.9) {
      _stopAlarm();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragValue < 0.9) {
      setState(() {
        _dragValue = 0.0;
      });
    }
  }

  void _stopAlarm() {
    context.read<SleepAlarmProvider>().stopAlarm(widget.alarmId);
    
    // Instead of just popping (which leaves app open), we terminate the task
    // if it was launched as a full-screen intent takeover.
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.crimson.withValues(alpha: 0.2),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.15).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  padding: EdgeInsets.all(30.r),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Icon(
                    Icons.alarm_on_rounded,
                    color: AppColors.crimson,
                    size: 64.r,
                  ),
                ),
              ),
              
              SizedBox(height: 40.h),
              
              Text(
                DateFormat('hh:mm a').format(DateTime.now()),
                style: AppTextStyles.h1.copyWith(fontSize: 48.sp, letterSpacing: 4),
              ),
              
              SizedBox(height: 16.h),
              
              Text(
                widget.label.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const Spacer(),
              
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      _buildSlider(),
                      SizedBox(height: 20.h),
                      TextButton(
                        onPressed: () {
                          // Snooze logic could go here
                        },
                        child: Text(
                          "SNOOZE (9 MIN)",
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 60.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        double knobSize = 56.h;
        double trackHeight = 64.h;
        double availableWidth = maxWidth - knobSize - 8.w;

        return Container(
          height: trackHeight,
          width: maxWidth,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(trackHeight / 2),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Stack(
            children: [
              Center(
                child: Opacity(
                  opacity: (1.0 - _dragValue * 2).clamp(0.0, 1.0),
                  child: Text(
                    "SLIDE TO STOP",
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4.w + (_dragValue * availableWidth),
                top: 4.h,
                bottom: 4.h,
                child: GestureDetector(
                  onPanUpdate: (details) => _onDragUpdate(details, availableWidth),
                  onPanEnd: _onDragEnd,
                  child: Container(
                    width: knobSize,
                    decoration: const BoxDecoration(
                      color: AppColors.crimson,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
