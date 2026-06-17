// lib/providers/flood_providers.dart
// v10.4 — cityLookupMapProvider: O(1) city lookup; Bihar-only refresh gate
//
// v10.3: pre-warm LiveFetchEngine on first realTimeProvider access
// v10.2: _normCityKey() collapses qualifier variants so Birpur x3 → Birpur x1
// v10.1: deduplicate liveLevelsProvider by city key.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../models/river_station.dart';
import '../services/real_time_service.dart';
import 'real_time_river_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────────
// selectedCityProvider
// ─────────────────────────────────────────────────────────────────────────────────

class SelectedCityNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String city) => state = city;
  void clear()         => state = null;
}

final selectedCityProvider =
    NotifierProvider<SelectedCityNotifier, String?>(SelectedCityNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────────
// realTimeProvider  (v10.3)
// ─────────────────────────────────────────────────────────────────────────────────

final realTimeProvider = Provider<RealTimeService>((ref) {
  final svc = RealTimeService();
  svc.startPolling();
  return svc;
});

// ─────────────────────────────────────────────────────────────────────────────────
// criticalCountProvider / isWakingUpProvider
// ─────────────────────────────────────────────────────────────────────────────────

final criticalCountProvider = Provider<int>((ref) =>
    ref.watch(mergedCriticalCountProvider));

final isWakingUpProvider = Provider<bool>((ref) {
  final loading = ref.watch(wrdIsLoadingProvider);
  final hasData = ref.watch(mergedStationsProvider).isNotEmpty;
  return loading && !hasData;
});

// ─────────────────────────────────────────────────────────────────────────────────
// cityLookupMapProvider  (v10.4)
// ─────────────────────────────────────────────────────────────────────────────────

final cityLookupMapProvider = Provider<Map<String, FloodData>>((ref) {
  final levels = ref.watch(liveLevelsProvider);
  return { for (final d in levels) _normCityKey(d.city): d };
});

// ─────────────────────────────────────────────────────────────────────────────────
// cityDataProvider / cityTrendProvider  (v10.4)
// ─────────────────────────────────────────────────────────────────────────────────

final cityDataProvider =
    Provider.family<FloodData?, String>((ref, city) {
  final map = ref.watch(cityLookupMapProvider);
  return map[_normCityKey(city)];
});

final cityTrendProvider =
    Provider.family<List<RiverLevelSnapshot>, String>((ref, city) {
  final service = ref.watch(realTimeProvider);
  return service.trendForCity(city);
});

// ─────────────────────────────────────────────────────────────────────────────────
// State-scoped alert / contact providers
// ─────────────────────────────────────────────────────────────────────────────────

final stateImdAlertsProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  final service = ref.watch(realTimeProvider);
  return service.imdAlertsForState(state);
});

final stateNdmaAdvisoriesProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  final service = ref.watch(realTimeProvider);
  return service.ndmaAdvisoriesForState(state);
});

final stateEmergencyContactsProvider =
    Provider.family<List<dynamic>, String>((ref, state) {
  final service = ref.watch(realTimeProvider);
  return service.emergencyContactsForState(state);
});

// ─────────────────────────────────────────────────────────────────────────────────
// FloodSummary
// ─────────────────────────────────────────────────────────────────────────────────

class FloodSummary {
  final int    totalStations;
  final int    criticalCount;
  final int    severeCount;
  final int    elevatedCount;
  final int    normalCount;
  final double avgProgressPct;
  final double maxLevel;
  final String maxLevelStation;
  final String dataSource;
  final DateTime updatedAt;

  const FloodSummary({
    required this.totalStations,
    required this.criticalCount,
    required this.severeCount,
    required this.elevatedCount,
    required this.normalCount,
    required this.avgProgressPct,
    required this.maxLevel,
    required this.maxLevelStation,
    required this.dataSource,
    required this.updatedAt,
  });

  int    get dangerCount   => criticalCount + severeCount;
  int    get alertCount    => criticalCount + severeCount + elevatedCount;
  double get dangerPercent => totalStations == 0 ? 0 : dangerCount / totalStations * 100;
  double get alertPercent  => totalStations == 0 ? 0 : alertCount  / totalStations * 100;
}

// ─────────────────────────────────────────────────────────────────────────────────
// floodSummaryProvider
// ─────────────────────────────────────────────────────────────────────────────────

final floodSummaryProvider = Provider<FloodSummary>((ref) {
  final stations = ref.watch(mergedStationsProvider);

  if (stations.isEmpty) {
    return FloodSummary(
      totalStations: 0, criticalCount: 0, severeCount: 0,
      elevatedCount: 0, normalCount: 0,
      avgProgressPct: 0, maxLevel: 0, maxLevelStation: '—',
      dataSource: 'loading', updatedAt: DateTime.now(),
    );
  }

  int critical = 0, severe = 0, elevated = 0, normal = 0;
  double totalPct = 0, maxLvl = 0;
  String maxStn = stations.first.station;

  for (final s in stations) {
    switch (s.dangerClass) {
      case DangerClass.extreme:     critical++;  break;
      case DangerClass.severe:      severe++;    break;
      case DangerClass.aboveNormal: elevated++;  break;
      default:                      normal++;    break;
    }
    totalPct += s.progressPct;
    if (s.current > maxLvl) { maxLvl = s.current; maxStn = s.station; }
  }

  final hasCwc = stations.any((s) => s.dataSource?.contains('CWC') ?? false);

  return FloodSummary(
    totalStations:   stations.length,
    criticalCount:   critical,
    severeCount:     severe,
    elevatedCount:   elevated,
    normalCount:     normal,
    avgProgressPct:  totalPct / stations.length,
    maxLevel:        maxLvl,
    maxLevelStation: maxStn,
    dataSource:      hasCwc ? 'CWC+WRD' : 'WRD',
    updatedAt:       DateTime.now(),
  );
});

// ─────────────────────────────────────────────────────────────────────────────────
// Scalar KPI providers
// ─────────────────────────────────────────────────────────────────────────────────

final floodTotalStationsProvider   = Provider<int>((ref) => ref.watch(floodSummaryProvider).totalStations);
final floodCriticalCountProvider   = Provider<int>((ref) => ref.watch(floodSummaryProvider).criticalCount);
final floodSevereCountProvider     = Provider<int>((ref) => ref.watch(floodSummaryProvider).severeCount);
final floodElevatedCountProvider   = Provider<int>((ref) => ref.watch(floodSummaryProvider).elevatedCount);
final floodNormalCountProvider     = Provider<int>((ref) => ref.watch(floodSummaryProvider).normalCount);
final floodDangerCountProvider     = Provider<int>((ref) => ref.watch(floodSummaryProvider).dangerCount);
final floodAlertCountProvider      = Provider<int>((ref) => ref.watch(floodSummaryProvider).alertCount);
final floodAvgProgressPctProvider  = Provider<double>((ref) => ref.watch(floodSummaryProvider).avgProgressPct);
final floodMaxLevelProvider        = Provider<double>((ref) => ref.watch(floodSummaryProvider).maxLevel);
final floodMaxLevelStationProvider = Provider<String>((ref) => ref.watch(floodSummaryProvider).maxLevelStation);
final floodDataSourceProvider      = Provider<String>((ref) => ref.watch(floodSummaryProvider).dataSource);

// ─────────────────────────────────────────────────────────────────────────────────
// Helper: RiverStation → FloodData
// ─────────────────────────────────────────────────────────────────────────────────

FloodData _riverStationToFloodData(RiverStation s) {
  return FloodData(
    stationId:    s.station,
    stationName:  s.station,
    river:        s.river ?? '',
    city:         s.city,
    district:     '',
    state:        s.state,
    riverName:    s.river,
    currentLevel: s.current,
    warningLevel: s.warning,
    dangerLevel:  s.danger,
    lastUpdated:  DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────────
// _normCityKey  (v10.2)
// ─────────────────────────────────────────────────────────────────────────────────

String _normCityKey(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'),  ' ')
    .replaceAll(RegExp(r' +'),            ' ')
    .trim();

// ─────────────────────────────────────────────────────────────────────────────────
// _deduplicateByCity  (v10.2)
// ─────────────────────────────────────────────────────────────────────────────────

List<FloodData> _deduplicateByCity(List<FloodData> raw) {
  final map = <String, FloodData>{};
  for (final fd in raw) {
    final key = fd.stationName.isNotEmpty ? fd.stationName : _normCityKey(fd.city);
    if (!map.containsKey(key)) {
      map[key] = fd;
    } else {
      final existing        = map[key]!;
      final incomingIsLive  = fd.status == 'LIVE';
      final existingIsLive  = existing.status == 'LIVE';
      if (incomingIsLive && !existingIsLive) {
        map[key] = fd;
      } else if (!incomingIsLive && existingIsLive) {
        // keep existing
      } else {
        if (fd.currentLevel > existing.currentLevel) map[key] = fd;
      }
    }
  }
  return map.values.toList();
}

// ─────────────────────────────────────────────────────────────────────────────────
// liveLevelsProvider  (v10.2)
// ─────────────────────────────────────────────────────────────────────────────────

final liveLevelsProvider = Provider<List<FloodData>>((ref) {
  final raw = ref.watch(mergedStationsProvider)
      .map(_riverStationToFloodData)
      .toList();
  return _deduplicateByCity(raw);
});

// ─────────────────────────────────────────────────────────────────────────────────
// Loading / offline / timestamp providers
// ─────────────────────────────────────────────────────────────────────────────────

final isLoadingProvider = Provider<bool>((ref) =>
    ref.watch(wrdIsLoadingProvider) && ref.watch(mergedStationsProvider).isEmpty);

final isOfflineProvider = Provider<bool>((ref) =>
    ref.watch(wrdErrorProvider) != null);

final lastFetchTimeProvider = Provider<DateTime?>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  if (stations.isEmpty) return null;
  final raw = stations.first.lastUpdated;
  if (raw == null || raw.isEmpty) return DateTime.now();
  final parts = raw.split(':');
  if (parts.length < 2) return DateTime.now();
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, h, m);
});

// ─────────────────────────────────────────────────────────────────────────────────
// IMD / NDMA global stubs
// ─────────────────────────────────────────────────────────────────────────────────

final imdAlertsProvider = Provider<List<Map<String, dynamic>>>((ref) => const []);
final ndmaAdvisoriesProvider = Provider<List<Map<String, dynamic>>>((ref) => const []);
