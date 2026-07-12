// lib/utils/flood_severity.dart
// Canonical definition of FloodSeverity enum + color helpers.
// flood_severity_helper.dart re-exports this — do not redefine enum there.
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

enum FloodSeverity {
  normal,
  watch,
  warning,
  danger,
  extreme;

  // Legacy alias so state_matrix_screen.dart compiles without changes
  static const FloodSeverity critical = FloodSeverity.extreme;

  String get label {
    switch (this) {
      case FloodSeverity.normal:
        return 'Normal';
      case FloodSeverity.watch:
        return 'Watch';
      case FloodSeverity.warning:
        return 'Warning';
      case FloodSeverity.danger:
        return 'Danger';
      case FloodSeverity.extreme:
        return 'Extreme';
    }
  }

  String get shortLabel {
    switch (this) {
      case FloodSeverity.normal:
        return 'NRM';
      case FloodSeverity.watch:
        return 'WCH';
      case FloodSeverity.warning:
        return 'WRN';
      case FloodSeverity.danger:
        return 'DNG';
      case FloodSeverity.extreme:
        return 'EXT';
    }
  }

  Color get color {
    switch (this) {
      case FloodSeverity.normal:
        return AppPalette.safe;
      case FloodSeverity.watch:
        return AppPalette.cyan;
      case FloodSeverity.warning:
        return AppPalette.warning;
      case FloodSeverity.danger:
        return AppPalette.danger;
      case FloodSeverity.extreme:
        return AppPalette.critical;
    }
  }

  Color get glowColor {
    switch (this) {
      case FloodSeverity.normal:
        return AppPalette.safeGlow;
      case FloodSeverity.watch:
        return AppPalette.cyanGlow;
      case FloodSeverity.warning:
        return AppPalette.warnGlow;
      case FloodSeverity.danger:
        return AppPalette.dangerGlow;
      case FloodSeverity.extreme:
        return AppPalette.critGlow;
    }
  }

  bool get requiresAction => index >= FloodSeverity.warning.index;
  bool get isCritical => index >= FloodSeverity.danger.index;

  static FloodSeverity fromLevel(
      double current, double warning, double danger) {
    if (current >= danger * 1.15) return FloodSeverity.extreme;
    if (current >= danger) return FloodSeverity.danger;
    if (current >= warning * 1.1) return FloodSeverity.warning;
    if (current >= warning * 0.9) return FloodSeverity.watch;
    return FloodSeverity.normal;
  }

  static FloodSeverity fromString(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'NORMAL':
      case 'SAFE':
        return FloodSeverity.normal;
      case 'WATCH':
        return FloodSeverity.watch;
      case 'WARNING':
      case 'WARN':
        return FloodSeverity.warning;
      case 'DANGER':
      case 'FLOOD':
        return FloodSeverity.danger;
      case 'EXTREME':
      case 'CRITICAL':
        return FloodSeverity.extreme;
      default:
        return FloodSeverity.normal;
    }
  }
}

/// Static color helpers — both instance method and static field access patterns
class FloodSeverityColor {
  const FloodSeverityColor._();

  static const Color normal = AppPalette.safe;
  static const Color watch = AppPalette.cyan;
  static const Color warning = AppPalette.warning;
  static const Color danger = AppPalette.danger;
  static const Color extreme = AppPalette.critical;
  // Offline alias — used by legacy callers
  static const Color offline = AppPalette.textGrey;

  static Color forSeverity(FloodSeverity s) => s.color;
  static Color glowForSeverity(FloodSeverity s) => s.glowColor;
  static Color forLevel(double current, double warnLvl, double dangerLvl) =>
      FloodSeverity.fromLevel(current, warnLvl, dangerLvl).color;
}

// ── Backward-compat aliases ─────────────────────────────────────────────────
// FloodSeverityLevel is used by station_status_provider.dart as a typedef.
typedef FloodSeverityLevel = FloodSeverity;

/// Extension on FloodSeverityLevel / FloodSeverity used by
/// station_status_provider.dart: FloodSeverityLevelExtension.fromString(raw)
extension FloodSeverityLevelExtension on FloodSeverity {
  static FloodSeverity fromString(String? raw) => FloodSeverity.fromString(raw);
}
