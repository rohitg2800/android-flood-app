// lib/providers/district_heatmap_provider.dart
// PHASE 4B — Riverpod providers that power the district heatmap layer
//
// Exposes:
//   districtHeatmapVisibleProvider  — bool toggle (show/hide heatmap overlay)
//   districtSummaryProvider         — map of districtName → _DistrictSummary
//   worstDistrictProvider           — name of district with highest severity
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../providers/merged_stations_provider.dart';
import '../services/alert_engine.dart';

// ── Toggle: show / hide heatmap overlay ────────────────────────────────────
final districtHeatmapVisibleProvider = StateProvider<bool>((ref) => true);

// ── Per-district summary ────────────────────────────────────────────────────────
class DistrictSummary {
  final String district;
  final int stationCount;
  final int aboveDanger;
  final int aboveWarning;
  final AlertSeverity worstSeverity;
  final double worstLevel;
  final List<RiverStation> stations;

  const DistrictSummary({
    required this.district,
    required this.stationCount,
    required this.aboveDanger,
    required this.aboveWarning,
    required this.worstSeverity,
    required this.worstLevel,
    required this.stations,
  });
}

AlertSeverity _sev(RiverStation s) {
  if (s.hfl > 0 && s.current >= s.hfl) return AlertSeverity.emergency;
  if (s.danger > 0 && s.current >= s.danger) return AlertSeverity.emergency;
  if (s.warning > 0 && s.current >= s.warning) return AlertSeverity.critical;
  if (s.progressPct >= 0.75) return AlertSeverity.warning;
  return AlertSeverity.info;
}

final districtSummaryProvider = Provider<Map<String, DistrictSummary>>((ref) {
  final stations = ref.watch(mergedStationsProvider);

  final Map<String, List<RiverStation>> byDistrict = {};
  for (final s in stations) {
    final key = (s.city.isNotEmpty ? s.city : s.district) ?? s.river;
    byDistrict.putIfAbsent(key, () => []).add(s);
  }

  return byDistrict.map((district, list) {
    AlertSeverity worst = AlertSeverity.info;
    double worstLevel = 0;
    int aboveDanger = 0;
    int aboveWarning = 0;

    for (final s in list) {
      final sev = _sev(s);
      if (sev.priority > worst.priority) worst = sev;
      if (s.current > worstLevel) worstLevel = s.current;
      if (s.danger > 0 && s.current >= s.danger) aboveDanger++;
      if (s.warning > 0 && s.current >= s.warning) aboveWarning++;
    }

    return MapEntry(
      district,
      DistrictSummary(
        district: district,
        stationCount: list.length,
        aboveDanger: aboveDanger,
        aboveWarning: aboveWarning,
        worstSeverity: worst,
        worstLevel: worstLevel,
        stations: list,
      ),
    );
  });
});

// ── Worst district (for banner / notification badge) ──────────────────────────
final worstDistrictProvider = Provider<DistrictSummary?>((ref) {
  final summaries = ref.watch(districtSummaryProvider);
  if (summaries.isEmpty) return null;

  return summaries.values.reduce((a, b) {
    final sc = b.worstSeverity.priority.compareTo(a.worstSeverity.priority);
    if (sc != 0) return sc > 0 ? b : a;
    return b.aboveDanger > a.aboveDanger ? b : a;
  });
});
