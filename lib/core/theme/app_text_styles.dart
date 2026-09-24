import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ELITE TYPOGRAPHY SYSTEM
/// 
/// Provides a unified set of styles with a baseline size.
/// Use the `.adaptive(context)` extension to scale these styles perfectly
/// across Phones, Foldables, and Tablets.
class AppTextStyles {
  AppTextStyles._(); 

  static const String _font = 'Impact';

  // ── Display / Hero ────────────────────────────────────
  static TextStyle get displayLarge => const TextStyle(
        fontFamily: _font,
        fontSize: 48.0,
        color: AppColors.textPrimary,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get displayMedium => const TextStyle(
        fontFamily: _font,
        fontSize: 36.0,
        color: AppColors.textPrimary,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      );

  // ── Headings ──────────────────────────────────────────
  static TextStyle get h1 => const TextStyle(
        fontFamily: _font,
        fontSize: 32.0,
        color: AppColors.textPrimary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get h2 => const TextStyle(
        fontFamily: _font,
        fontSize: 26.0,
        color: AppColors.textPrimary,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get h3 => const TextStyle(
        fontFamily: _font,
        fontSize: 22.0,
        color: AppColors.textPrimary,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w500,
      );

  // ── Section Labels ────────────────────────────────────
  static TextStyle get labelLarge => const TextStyle(
        fontFamily: _font,
        fontSize: 16.0,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelMedium => const TextStyle(
        fontFamily: _font,
        fontSize: 14.0,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelSmall => const TextStyle(
        fontFamily: _font,
        fontSize: 12.0,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  // ── Body ──────────────────────────────────────────────
  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: _font,
        fontSize: 16.0,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
        height: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: _font,
        fontSize: 14.0,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
        height: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamily: _font,
        fontSize: 12.0,
        color: AppColors.textMuted,
        letterSpacing: 0.1,
        height: 1.5,
        fontWeight: FontWeight.w500,
      );

  // ── Buttons ───────────────────────────────────────────
  static TextStyle get buttonPrimary => const TextStyle(
        fontFamily: _font,
        fontSize: 18.0,
        color: AppColors.textPrimary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get buttonSecondary => const TextStyle(
        fontFamily: _font,
        fontSize: 16.0,
        color: AppColors.textPrimary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get buttonDark => const TextStyle(
        fontFamily: _font,
        fontSize: 16.0,
        color: Colors.black87,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      );

  // ── Input Fields ──────────────────────────────────────
  static TextStyle get inputText => const TextStyle(
        fontFamily: _font,
        fontSize: 14.0,
        color: Colors.black87,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get inputHint => const TextStyle(
        fontFamily: _font,
        fontSize: 14.0,
        color: AppColors.inputHint,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  // ── Captions & Links ──────────────────────────────────
  static TextStyle get caption => const TextStyle(
        fontFamily: _font,
        fontSize: 13.0,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get link => const TextStyle(
        fontFamily: _font,
        fontSize: 13.0,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get dividerLabel => const TextStyle(
        fontFamily: _font,
        fontSize: 13.0,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w500,
      );

  // ── Workout / Stats specific ───────────────────────────
  static TextStyle get statNumber => const TextStyle(
        fontFamily: _font,
        fontSize: 42.0,
        color: AppColors.crimson,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get statLabel => const TextStyle(
        fontFamily: _font,
        fontSize: 11.0,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get timerDisplay => const TextStyle(
        fontFamily: _font,
        fontSize: 64.0,
        color: AppColors.textPrimary,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
      );
}

/// THE ELITE ADAPTIVE EXTENSION
/// 
/// Automatically scales font size based on the device shortest side.
/// Includes dampening logic to keep text elegant on Tablets and Foldables.
extension AdaptiveTextStyle on TextStyle {
  TextStyle adaptive(BuildContext context) {
    final double shortestSide = MediaQuery.of(context).size.shortestSide;
    double baseSize = fontSize ?? 14.0;
    
    // DESIGN BASELINE: iPhone width is approx 375dp
    double scale = shortestSide / 375.0;
    
    // ELITE HIGH-DENSITY DAMPENING: 
    // We only take 5% of the growth above baseline. 
    // This creates an ultra-sharp, high-density look on Tablets/Foldables
    // where the text remains close to phone-scale while the screen grows.
    if (shortestSide >= 480) {
      scale = 1.0 + (scale - 3) * 0.1;
    }
    
    // ACCESSIBILITY: Multiplies by the user's system font preference.
    final double finalSize = (baseSize * scale) * MediaQuery.textScalerOf(context).scale(1.0);
    
    return copyWith(fontSize: finalSize);
  }
}
