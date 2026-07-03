// lib/widgets/dashboard/risk_color_helper.dart
// Shared helper — maps a risk-level string to its semantic colour.
import '../../theme/river_theme.dart';
import 'package:flutter/material.dart';

Color riskColor(String lvl) {
  switch (lvl.toUpperCase()) {
    case 'CRITICAL':
      return AppPalette.critical;
    case 'SEVERE':
      return AppPalette.danger;
    case 'MODERATE':
      return AppPalette.warning;
    default:
      return AppPalette.safe;
  }
}
