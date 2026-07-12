// lib/utils/flood_severity_helper.dart
// ───────────────────────────────────────────────────────────────────
// FloodSeverityHelper — single source of truth for flood severity.
// IMPORTANT: FloodSeverity enum is defined in flood_severity.dart.
// This file re-exports it so callers only need one import.
// ───────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
// Re-export the canonical enum — do NOT redefine it here.
export 'flood_severity.dart'
    show FloodSeverity, FloodSeverityLevel, FloodSeverityColor;
import 'flood_severity.dart';

/// Trend direction for a station’s water level over the last hour.
enum WaterLevelTrend { rising, falling, stable, unknown }

class FloodSeverityHelper {
  FloodSeverityHelper._();

  // ── Parse from raw string ───────────────────────────────────────────────
  static FloodSeverity fromString(String? raw) => FloodSeverity.fromString(raw);

  // ── Derive from level thresholds ───────────────────────────────────────
  static FloodSeverity fromLevels({
    required double current,
    required double warningLevel,
    required double dangerLevel,
  }) =>
      FloodSeverity.fromLevel(current, warningLevel, dangerLevel);

  // ── Color ────────────────────────────────────────────────────────────
  static Color color(FloodSeverity s) => s.color;
  static Color glowColor(FloodSeverity s) => s.glowColor;
  static Color cardFill(FloodSeverity s) => s.color.withValues(alpha: 0.08);
  static Color cardBorder(FloodSeverity s) => s.color.withValues(alpha: 0.35);

  // ── Icon ──────────────────────────────────────────────────────────────
  static IconData icon(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:
        return Icons.check_circle_outline_rounded;
      case FloodSeverity.watch:
        return Icons.visibility_rounded;
      case FloodSeverity.warning:
        return Icons.warning_amber_rounded;
      case FloodSeverity.danger:
        return Icons.dangerous_rounded;
      case FloodSeverity.extreme:
        return Icons.crisis_alert_rounded;
    }
  }

  // ── Label ──────────────────────────────────────────────────────────────
  static String label(FloodSeverity s) => s.label;

  static String labelHindi(FloodSeverity s) {
    switch (s) {
      case FloodSeverity.normal:
        return 'सामान्य';
      case FloodSeverity.watch:
        return 'सतर्क';
      case FloodSeverity.warning:
        return 'चेतावनी';
      case FloodSeverity.danger:
        return 'खतरा';
      case FloodSeverity.extreme:
        return 'अतिखतरा';
    }
  }

  // ── Trend helpers ───────────────────────────────────────────────────────
  static WaterLevelTrend trendFromDelta(double deltaMeters) {
    if (deltaMeters > 0.1) return WaterLevelTrend.rising;
    if (deltaMeters < -0.1) return WaterLevelTrend.falling;
    return WaterLevelTrend.stable;
  }

  static IconData trendIcon(WaterLevelTrend t) {
    switch (t) {
      case WaterLevelTrend.rising:
        return Icons.trending_up_rounded;
      case WaterLevelTrend.falling:
        return Icons.trending_down_rounded;
      case WaterLevelTrend.stable:
        return Icons.trending_flat_rounded;
      case WaterLevelTrend.unknown:
        return Icons.remove_rounded;
    }
  }

  static Color trendColor(WaterLevelTrend t) {
    switch (t) {
      case WaterLevelTrend.rising:
        return AppPalette.danger;
      case WaterLevelTrend.falling:
        return AppPalette.safe;
      case WaterLevelTrend.stable:
        return AppPalette.textGrey;
      case WaterLevelTrend.unknown:
        return AppPalette.textDim;
    }
  }

  static String trendLabel(WaterLevelTrend t) {
    switch (t) {
      case WaterLevelTrend.rising:
        return 'Rising';
      case WaterLevelTrend.falling:
        return 'Falling';
      case WaterLevelTrend.stable:
        return 'Stable';
      case WaterLevelTrend.unknown:
        return '--';
    }
  }
}
