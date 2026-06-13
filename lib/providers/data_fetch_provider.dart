// lib/providers/data_fetch_provider.dart  v1.2
//
// v1.2 (Problem-3 fix, 12 Jun 2026):
//   Renamed internal criticalAlertCountProvider → mergedCriticalAlertCountProvider
//   to eliminate the name clash with alerts_badge_provider.dart.
//   No callers outside this file used the old name (all external consumers
//   of the badge count go through alerts_badge_provider.dart which now
//   watches alertCountProvider instead).
//
// v1.1 (dedup fix):
//   alertsProvider now watches mergedStationsProvider (the already-deduped
//   single-source-of-truth list) and calls AlertEngine.evaluateMerged().
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/data_fetch_engine.dart';
import '../services/alert_engine.dart';
import '../models/river_station.dart';
import 'real_time_river_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────────
// dataFetchProvider — StreamProvider<DataFetchSnapshot>
// ──────────────────────────────────────────────────────────────────────────────────
final dataFetchProvider = StreamProvider<DataFetchSnapshot>((ref) {
  final engine = DataFetchEngine.instance;
  engine.start();
  ref.onDispose(engine.stop);
  return engine.stream;
});

// ──────────────────────────────────────────────────────────────────────────────────
// Derived: list of RiverStation (feeds existing mergedStationsProvider shim)
// ──────────────────────────────────────────────────────────────────────────────────
final dataFetchStationsProvider = Provider<List<RiverStation>>((ref) {
  final snap = ref.watch(dataFetchProvider);
  return snap.when(
    data:    (s) => s.stations.map((r) => r.toRiverStation()).toList(),
    loading: ()  => const [],
    error:   (_, __) => const [],
  );
});

// ──────────────────────────────────────────────────────────────────────────────────
// alertsProvider — all active, sorted alerts
//
// v1.1: watches mergedStationsProvider (deduped) instead of the raw snapshot.
//       One station in → one alert card out.  No more duplicate cards.
// ──────────────────────────────────────────────────────────────────────────────────
final alertsProvider = Provider<List<FloodAlert>>((ref) {
  final merged = ref.watch(mergedStationsProvider);
  return AlertEngine.instance.evaluateMerged(merged);
});

// ──────────────────────────────────────────────────────────────────────────────────
// Filtered alert sub-providers
// ──────────────────────────────────────────────────────────────────────────────────
final criticalAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(alertsProvider)
        .where((a) =>
            a.severity == AlertSeverity.critical ||
            a.severity == AlertSeverity.emergency)
        .toList());

final emergencyAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(alertsProvider)
        .where((a) => a.severity == AlertSeverity.emergency)
        .toList());

final warningAlertsProvider = Provider<List<FloodAlert>>((ref) =>
    ref.watch(alertsProvider)
        .where((a) => a.severity == AlertSeverity.warning)
        .toList());

final alertCountProvider = Provider<int>((ref) =>
    ref.watch(alertsProvider).length);

// v1.2: renamed from criticalAlertCountProvider to avoid clash with
// alerts_badge_provider.dart which owns the externally-visible name.
final mergedCriticalAlertCountProvider = Provider<int>((ref) =>
    ref.watch(criticalAlertsProvider).length);

// Per-station alerts
final stationAlertsProvider =
    Provider.family<List<FloodAlert>, String>((ref, stationName) =>
        ref.watch(alertsProvider)
            .where((a) =>
                a.stationName.toLowerCase() == stationName.toLowerCase())
            .toList());

// Source health summary
final sourceStatusProvider = Provider<List<SourceStatus>>((ref) {
  final snap = ref.watch(dataFetchProvider);
  return snap.when(
    data:    (s) => s.sources,
    loading: ()  => const [],
    error:   (_, __) => const [],
  );
});

// Last fetch time
final lastFetchTimeProvider2 = Provider<DateTime?>((ref) {
  final snap = ref.watch(dataFetchProvider);
  return snap.when(
    data:    (s) => s.fetchedAt,
    loading: ()  => null,
    error:   (_, __) => null,
  );
});

// Quick KPIs for dashboard cards
final fetchSnapshotKpiProvider = Provider<_SnapshotKpi>((ref) {
  final snap = ref.watch(dataFetchProvider);
  return snap.when(
    data: (s) => _SnapshotKpi(
      total:      s.totalStations,
      live:       s.liveStations,
      critical:   s.criticalCount,
      danger:     s.dangerCount,
      warning:    s.warningCount,
      maxLevel:   s.maxLevel,
      maxStation: s.maxLevelStation,
    ),
    loading: () => _SnapshotKpi.empty(),
    error:   (_, __) => _SnapshotKpi.empty(),
  );
});

class _SnapshotKpi {
  final int    total;
  final int    live;
  final int    critical;
  final int    danger;
  final int    warning;
  final double maxLevel;
  final String maxStation;
  const _SnapshotKpi({
    required this.total,
    required this.live,
    required this.critical,
    required this.danger,
    required this.warning,
    required this.maxLevel,
    required this.maxStation,
  });
  factory _SnapshotKpi.empty() => const _SnapshotKpi(
    total: 0, live: 0, critical: 0, danger: 0, warning: 0,
    maxLevel: 0, maxStation: '—',
  );
}
