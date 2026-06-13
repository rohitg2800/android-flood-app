// lib/providers/data_fetch_provider.dart  v1.3
//
// v1.3 (13 Jun 2026) — blank-screen fix:
//   DataFetchEngine.stream is a broadcast stream.  When DataFetchEngine.start()
//   is called in main.dart's addPostFrameCallback it immediately emits the seed
//   snapshot via _ctrl.add(_last!).  But the StreamProvider hasn't subscribed
//   yet at that instant, so the seed emission is silently dropped and the
//   provider stays in AsyncLoading forever — all screens show nothing.
//
//   Fix: replace the bare engine.stream with a Stream.multi that synchronously
//   prepends engine.last as the first event the moment a new listener attaches,
//   then forwards every subsequent broadcast event.  This guarantees the seed
//   (or the most recent live snapshot) is always delivered regardless of when
//   the provider is first read.
//
//   Also removed the duplicate engine.start() call — main.dart owns lifecycle.
//
// v1.2: renamed internal criticalAlertCountProvider to avoid badge clash.
// v1.1: alertsProvider watches mergedStationsProvider for dedup.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/data_fetch_engine.dart';
import '../services/alert_engine.dart';
import '../models/river_station.dart';
import 'real_time_river_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// _engineStream — broadcast-safe stream that always seeds the latest snapshot
// to every new listener synchronously before forwarding live events.
// ──────────────────────────────────────────────────────────────────────────────
Stream<DataFetchSnapshot> _engineStream(DataFetchEngine engine) {
  return Stream.multi((controller) {
    // 1. Immediately push the most-recent snapshot (seed or live) so the
    //    StreamProvider never enters AsyncLoading with nothing to show.
    final seed = engine.last;
    if (seed != null) controller.add(seed);

    // 2. Forward every future emission from the broadcast stream.
    final sub = engine.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone:  controller.close,
    );

    // 3. Clean up when the Riverpod provider is disposed.
    controller.onCancel = sub.cancel;
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// dataFetchProvider — StreamProvider<DataFetchSnapshot>
// ──────────────────────────────────────────────────────────────────────────────
final dataFetchProvider = StreamProvider<DataFetchSnapshot>((ref) {
  final engine = DataFetchEngine.instance;
  // NOTE: engine.start() is intentionally NOT called here.
  // main.dart calls it via addPostFrameCallback after runApp().
  // Calling it here as well caused double-start races on hot restart.
  return _engineStream(engine);
});

// ──────────────────────────────────────────────────────────────────────────────
// Derived: list of RiverStation
// ──────────────────────────────────────────────────────────────────────────────
final dataFetchStationsProvider = Provider<List<RiverStation>>((ref) {
  final snap = ref.watch(dataFetchProvider);
  return snap.when(
    data:    (s) => s.stations.map((r) => r.toRiverStation()).toList(),
    loading: ()  => const [],
    error:   (_, __) => const [],
  );
});

// ──────────────────────────────────────────────────────────────────────────────
// alertsProvider — all active, sorted alerts
// ──────────────────────────────────────────────────────────────────────────────
final alertsProvider = Provider<List<FloodAlert>>((ref) {
  final merged = ref.watch(mergedStationsProvider);
  return AlertEngine.instance.evaluateMerged(merged);
});

// ──────────────────────────────────────────────────────────────────────────────
// Filtered alert sub-providers
// ──────────────────────────────────────────────────────────────────────────────
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
