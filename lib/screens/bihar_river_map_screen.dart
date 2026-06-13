// lib/screens/bihar_river_map_screen.dart
// OpsFlood — BiharRiverMapScreen v5.5.2
//
// Changes in v5.5.2
//   • Graceful fallback: if mapLiveIndexProvider is empty/loading,
//     fall back to wrdStationsProvider + zero live data.
//   • _resolveMerged() isolates all merge logic so the build() is clean.
//   • Uses MapStationData throughout (no more WrdStation casts).
//   • AppPalette.critical/danger/gold/safe/textGrey replace all raw hex.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../theme/river_theme.dart';
import '../providers/map_provider.dart';
import '../providers/map_live_index_provider.dart';
import '../models/map_station_data.dart';
import '../models/risk_level.dart';
import 'city_detail_screen.dart';

// ─── helpers ──────────────────────────────────────────────────────────────────

Color _riskColor(RiskLevel r) {
  switch (r) {
    case RiskLevel.critical: return const AppPalette.critical;
    case RiskLevel.severe:   return const AppPalette.danger;
    case RiskLevel.moderate: return const AppPalette.gold;
    case RiskLevel.safe:     return const AppPalette.safe;
    case RiskLevel.noData:   return const AppPalette.textGrey;
  }
}

String _riskLabel(RiskLevel r) {
  switch (r) {
    case RiskLevel.critical: return 'CRITICAL';
    case RiskLevel.severe:   return 'SEVERE';
    case RiskLevel.moderate: return 'MODERATE';
    case RiskLevel.safe:     return 'SAFE';
    case RiskLevel.noData:   return 'NO DATA';
  }
}
