import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // prevents instantiation

  static const Color white    = Color(0xFFFFFFFF); 
  static const Color black    = Color(0xFF000000);
  
  // ── Backgrounds ──────────────────────────────────────
 
  static const Color background     = Color(0xFF000000);
  static const Color surface        = Color(0xFF0D0D0D);
  static const Color surfaceLight   = Color(0xFF141414);

  // ── Primary Accent ────────────────────────────────────
  static const Color crimson        = Color(0xFF8B1A2F); // primary red
  static const Color crimsonLight   = Color(0xFFB02240); // hover / lighter shade
  static const Color crimsonDark    = Color(0xFF6A1224); // pressed state

  // ── Text ─────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFFFFFFF); // headings, labels
  static const Color textSecondary  = Color(0xFFCCCCCC); // subtitles, hints
  static const Color textMuted      = Color(0xFFFFFFFF); // placeholders

  // ── Input Fields ──────────────────────────────────────
  static const Color inputFill      = Color(0xFFFFFFFF);
  static const Color inputHint      = Color(0xFFAAAAAA);
  static const Color inputBorder    = Color(0xFF8B1A2F); // focused border

  // ── Social ────────────────────────────────────────────
  static const Color google         = Color(0xFFFFFFFF);
  static const Color facebook       = Color(0xFF3B5998);

  // ── Dividers & Borders ────────────────────────────────
  static const Color divider        = Color(0xFF444444);
  static const Color border         = Color(0xFF272727);

  // ── Status ────────────────────────────────────────────
  static const Color success        = Color(0xFF69F0AE); // greenAccent
  static const Color warning        = Color(0xFFF39C12);
  static const Color error          = Color(0xFFE74C3C);
}
