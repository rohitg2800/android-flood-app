// lib/theme/app_theme.dart
// Shim — delegates to the canonical RiverColors / AppPalette design system.
// All files that import this get AppTheme.dark, AppTheme.light, and the
// AppPalette colour constants via re-export.
library;

export 'river_theme.dart';

import 'package:flutter/material.dart';
import 'river_theme.dart';

/// Top-level convenience wrapper so `AppTheme.dark` works in MaterialApp.
abstract final class AppTheme {
  static ThemeData get dark => RiverColors.darkTheme();
  static ThemeData get light => RiverColors.lightTheme();

  // ── Colour aliases (mirror AppPalette for legacy call-sites) ─────────────
  static const Color bgDeep = AppPalette.abyss0;
  static const Color surface = AppPalette.abyss2;
  static const Color cyan = AppPalette.cyan;
  static const Color warning = AppPalette.warning;
  static const Color danger = AppPalette.danger;
  static const Color textPrimary = AppPalette.textWhite;
  static const Color textMuted = AppPalette.textGrey;
  static const Color textFaint = AppPalette.textDim;
}
