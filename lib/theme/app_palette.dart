// lib/theme/app_palette.dart
// Thin re-export of AppPalette from river_theme.dart.
// Also adds the surface / surface2 / textPrimary aliases that
// monitors_screen.dart expects.
library;

// ── Dart directive ordering: exports MUST precede imports ───────────────
export 'river_theme.dart' show AppPalette, RiverColors;

// ── Imports ───────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'river_theme.dart';

// ── Top-level colour constants ────────────────────────────────────────────
// These extend AppPalette’s surface tokens as plain const Color values
// (Dart does not allow adding statics to a class via extensions).

/// Card background  (≈ AppPalette.abyss2 = 0xFF251800)
const Color kPaletteSurface = AppPalette.abyss2;

/// Elevated card / progress-bar track  (≈ AppPalette.abyss3 = 0xFF312200)
const Color kPaletteSurface2 = AppPalette.abyss3;

/// Primary text colour  (≈ AppPalette.textWhite = 0xFFFFF8E7)
const Color kPaletteTextPrimary = AppPalette.textWhite;
