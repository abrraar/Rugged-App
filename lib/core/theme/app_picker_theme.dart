// lib/core/theme/app_picker_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';

class AppPickerTheme {
  AppPickerTheme._();

  static ThemeData theme(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 600;
    return getTheme(isCompact: isCompact);
  }

  static ThemeData get themeData => getTheme(isCompact: true);

  static ThemeData getTheme({required bool isCompact}) {
    const TextStyle brandFontBase = TextStyle(
      fontFamily: 'Impact',
      fontWeight: FontWeight.w500,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Impact',

      colorScheme: const ColorScheme.dark(
        primary: AppColors.crimson,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: Colors.white,
        secondary: AppColors.crimson,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        headerHeadlineStyle: brandFontBase.copyWith(
          fontSize: isCompact ? 24.sp : 24.0, 
          color: Colors.white
        ),
        headerHelpStyle: brandFontBase.copyWith(
          fontSize: isCompact ? 12.sp : 12.0, 
          color: Colors.white70
        ),
        weekdayStyle: brandFontBase.copyWith(
          fontSize: isCompact ? 12.sp : 11.0,
          color: Colors.white70,
        ),
        dayStyle: const TextStyle(fontSize: 14.0, height: 1.0, fontWeight: FontWeight.w500, color: Colors.white),
        yearStyle: brandFontBase.copyWith(fontSize: isCompact ? 14.sp : 13.0),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.white.withValues(alpha: 0.3);
          return Colors.white;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.white.withValues(alpha: 0.3);
          return Colors.white;
        }),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        hourMinuteTextStyle: brandFontBase.copyWith(fontSize: 40.0),
        dayPeriodTextStyle: brandFontBase.copyWith(fontSize: 14.0),
        helpTextStyle: brandFontBase.copyWith(fontSize: 12.0),
        dialTextStyle: brandFontBase.copyWith(fontSize: 12.0),

        hourMinuteTextColor: WidgetStateColor.resolveWith((states) => Colors.white),
        dialTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.white.withValues(alpha: 0.3);
          return Colors.white;
        }),

        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.crimson; 
          }
          return Colors.white.withValues(alpha: 0.05);
        }),

        dayPeriodTextColor: WidgetStateColor.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white.withValues(alpha: 0.38);
        }),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: brandFontBase.copyWith(
            fontSize: isCompact ? 14.sp : 13.0,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
          foregroundColor: AppColors.crimson,
        ),
      ),

      textTheme: TextTheme(
        labelLarge: brandFontBase.copyWith(fontSize: isCompact ? 14.sp : 13.0),
        bodyLarge: brandFontBase,
        bodySmall: brandFontBase,
        titleLarge: brandFontBase.copyWith(fontSize: isCompact ? 22.sp : 20.0),
        titleMedium: brandFontBase,
        titleSmall: brandFontBase,
      ), 
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    );
  }
}
