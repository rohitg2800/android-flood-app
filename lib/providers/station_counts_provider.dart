// lib/providers/station_counts_provider.dart  v1.1
//
// v1.1 — align severity buckets with gaugeRiskFromLevels() (single SOT).
//
// BEFORE (v1.0): called FloodSeverity.fromLevel(current, warning, danger).
//   • No hfl parameter → extreme bucket fired at danger*1.15, NOT at hfl.
//   • Strip counts diverged from map / alert engine / KPI grid which all
//     use RiverStation.dangerClass (delegates to gaugeRiskFromLevels).
//
// AFTER (v1.1): calls gaugeRiskFromLevels(current, warning, danger, hfl)
//   then maps the 4-level result → FloodSeverity (5-level) for the strip.
//
// gaugeRiskFromLevels() tier rules (see bihar_rivers.dart):
//   current >= hfl     → 'EXTREME'   → FloodSeverity.extreme
//   current >= danger  → 'CRITICAL'  → FloodSeverity.danger
//   current >= warning → 'DANGER'    → FloodSeverity.warning
//   otherwise (but >= warning*0.9)   → FloodSeverity.watch   [strip-only]
//   otherwise                        → FloodSeverity.normal
//
// The watch bucket uses the same 0.9× warning threshold as FloodSeverity.fromLevel
// so the strip continues to distinguish approaching-warning stations visually,
// while extreme / danger / warning thresholds now match the rest of the app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/bihar_rivers.dart';
import '../utils/flood_severity.dart';
import 'real_time_river_provider.dart';

// ── Severity mapping helper ────────────────────────────────────────────────────
//
// Converts the 4-level gaugeRiskFromLevels() string into the 5-level
// FloodSeverity enum used by StationStatusStrip.
//
// Watch is a strip-only refinement of NORMAL: the station is below its
// warning level but within 90% of it — worth showing in cyan so operators
// notice stations approaching the threshold.

FloodSeverity _toFloodSeverity({
  required double current,
  required double warning,
  required double danger,
  required double hfl,
}) {
  final label = gaugeRiskFromLevels(
    current: current,
    warning: warning,
    danger: danger,
    hfl: hfl,
  );
  switch (label) {
    case 'EXTREME':
      return FloodSeverity.extreme;
    case 'CRITICAL':
      return FloodSeverity.danger;
    case 'DANGER':
      return FloodSeverity.warning;
    default:
      // NORMAL — check watch sub-bucket (approaching warning level)
      if (warning > 0 && current >= warning * 0.9) return FloodSeverity.watch;
      return FloodSeverity.normal;
  }
}

// ── Count map ──────────────────────────────────────────────────────────────────

final stationCountsProvider = Provider<Map<FloodSeverity, int>>((ref) {
  final stations = ref.watch(mergedStationsProvider);

  final counts = <FloodSeverity, int>{
    FloodSeverity.normal: 0,
    FloodSeverity.watch: 0,
    FloodSeverity.warning: 0,
    FloodSeverity.danger: 0,
    FloodSeverity.extreme: 0,
  };

  for (final s in stations) {
    final sev = _toFloodSeverity(
      current: s.current,
      warning: s.warning,
      danger: s.danger,
      hfl: s.hfl,
    );
    counts[sev] = (counts[sev] ?? 0) + 1;
  }

  return counts;
});

// ── Last-synced helper ─────────────────────────────────────────────────────────
//
// Returns the most-recent DateTime found across all station.lastUpdated fields,
// or null when no stations are loaded yet.

final stationLastSyncedProvider = Provider<DateTime?>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  if (stations.isEmpty) return null;

  DateTime? latest;
  final now = DateTime.now();
  for (final s in stations) {
    if (s.lastUpdated == null) continue;
    // lastUpdated is stored as 'HH:mm' — combine with today's date.
    final parts = s.lastUpdated!.split(':');
    if (parts.length < 2) continue;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) continue;
    final dt = DateTime(now.year, now.month, now.day, h, m);
    if (latest == null || dt.isAfter(latest)) latest = dt;
  }
  return latest;
});

// ── Loading flag ───────────────────────────────────────────────────────────────

final stationIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(wrdIsLoadingProvider);
});
