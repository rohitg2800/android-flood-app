// lib/widgets/map/map_risk_helpers.dart
// v2.0 — 5-colour severity aligned with DangerClass + gaugeRiskFromLevels()
//
// Colour palette:
//   extreme    / EXTREME   → #E040FB  magenta  (above HFL)
//   severe     / CRITICAL  → #D32F2F  deep red (above DL)
//   aboveNormal/ DANGER    → #FF6D00  orange   (above WL)
//   normal     / NORMAL    → #388E3C  green
import 'package:flutter/material.dart';
import '../../models/river_station.dart';

// ── DangerClass-based (heatmap, legend, district sheet) ───────────────────────
Color riskColor(DangerClass dc, {double opacity = 0.35}) {
  switch (dc) {
    case DangerClass.extreme:
      return const Color(0xFFE040FB).withValues(alpha: opacity); // magenta
    case DangerClass.severe:
      return const Color(0xFFD32F2F).withValues(alpha: opacity); // deep red
    case DangerClass.aboveNormal:
      return const Color(0xFFFF6D00).withValues(alpha: opacity); // orange
    case DangerClass.normal:
      return const Color(0xFF388E3C).withValues(alpha: opacity); // green
  }
}

Color riskColorSolid(DangerClass dc) => riskColor(dc, opacity: 1.0);

// ── String-based (map_markers, popup, telemetry sheet) ────────────────────────
/// Maps any riskLevel string to a Color.
/// Accepts gaugeRiskFromLevels output AND legacy API labels.
Color riskColorFromString(String level, {double opacity = 1.0}) {
  switch (level.toUpperCase().trim()) {
    case 'EXTREME':            return Color.fromRGBO(224, 64,  251, opacity);
    case 'CRITICAL':
    case 'HIGH':               return Color.fromRGBO(211, 47,  47,  opacity);
    case 'DANGER':
    case 'SEVERE':             return Color.fromRGBO(255, 109, 0,   opacity);
    case 'WARNING':
    case 'MODERATE':           return Color.fromRGBO(251, 192, 45,  opacity);
    case 'LOW':
    case 'NORMAL':             return Color.fromRGBO(56,  142, 60,  opacity);
    default:                   return Color.fromRGBO(117, 117, 117, opacity);
  }
}

/// Human-readable labels — aligned with AlertSeverity / FloodData.riskLevel.
String riskLabel(DangerClass dc) {
  switch (dc) {
    case DangerClass.extreme:     return 'EXTREME';  // above HFL
    case DangerClass.severe:      return 'CRITICAL'; // above DL
    case DangerClass.aboveNormal: return 'WARNING';  // above WL
    case DangerClass.normal:      return 'NORMAL';
  }
}

/// Legend entries for the map overlay — ordered worst → best.
const List<({String label, Color color})> kMapLegendEntries = [
  (label: 'EXTREME',  color: Color(0xFFE040FB)),
  (label: 'CRITICAL', color: Color(0xFFD32F2F)),
  (label: 'WARNING',  color: Color(0xFFFF6D00)),
  (label: 'NORMAL',   color: Color(0xFF388E3C)),
];
