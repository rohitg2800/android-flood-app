// lib/providers/data_fetch_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'live_engine_bridge_provider.dart';
import '../services/alert_engine.dart';
import '../models/river_station.dart';
import 'merged_stations_provider.dart';

// ── stub for screens that import activeAlertsProvider directly ───────────────
final activeAlertsProvider = Provider<List<FloodAlert>>((ref) => const []);

// ── main alerts provider: synchronous, Riverpod-safe ─────────────────────────
final alertsProvider = Provider<List<FloodAlert>>((ref) {
  final stations = ref.watch(liveEngineStationsProvider);
  return AlertEngine.instance.evaluateMerged(stations);
});

/// Total count of active alerts — watched by alertsBadgeProvider.
final alertCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).length;
});

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

/// Alerts for a specific station name (case-insensitive).
final stationAlertsProvider =
    Provider.family<List<FloodAlert>, String>((ref, stationName) =>
        ref.watch(alertsProvider)
            .where((a) =>
                a.stationName.toLowerCase() == stationName.toLowerCase())
            .toList());
