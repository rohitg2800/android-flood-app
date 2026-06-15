// lib/services/data_fetch_engine.dart
// v2 (15 Jun 2026) — add missing DataFetchSnapshot fields used by
//   backend_sync_service.dart and active_alert_controller.dart:
//     isLoading, liveStations, totalStations, sources.
//
// All new fields have defaults so existing callsites
// DataFetchSnapshot(stations: ..., fetchedAt: ...) compile unchanged.

import 'dart:async';
import '../models/flood_data.dart';
import '../models/river_station.dart';

class DataFetchSnapshot {
  final List<FloodData>   stations;
  final DateTime          fetchedAt;

  /// True while a network fetch is in progress. Used by sync_status_banner
  /// and active_alert_controller to show a loading indicator.
  final bool              isLoading;

  /// Count of stations whose status == 'LIVE' (updated < 2 h ago).
  /// Used by backend_sync_service `live_count` telemetry key.
  final int               liveStations;

  /// Total number of stations in this snapshot.
  /// Used by backend_sync_service `total_count` telemetry key.
  final int               totalStations;

  /// source-id → station count map.  e.g. {'CWC': 42, 'IMD': 11}.
  /// Built from FloodData.source; used by backend_sync sourceCountMap
  /// and active_alert_controller sources breakdown.
  final Map<String, int>  sources;

  DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
    this.isLoading    = false,
    int?  liveStations,
    int?  totalStations,
    Map<String, int>? sources,
  })  : totalStations = totalStations ?? stations.length,
        liveStations  = liveStations  ?? stations.where((s) => s.status == 'LIVE').length,
        sources       = sources       ?? _buildSourceMap(stations);

  static Map<String, int> _buildSourceMap(List<FloodData> stations) {
    final m = <String, int>{};
    for (final s in stations) {
      final key = s.source ?? 'UNKNOWN';
      m[key] = (m[key] ?? 0) + 1;
    }
    return Map.unmodifiable(m);
  }

  List<FloodData> toFloodDataList() => stations;

  /// Converts to List<RiverStation> for AlertEngine.evaluateMerged().
  /// Uses FloodData.hfl (v5) when available; falls back to dangerLevel * 1.3.
  List<RiverStation> toRiverStations() => stations.map((f) => RiverStation(
    city:    f.city,
    state:   f.state,
    river:   f.riverName ?? f.river,
    station: f.stationId,
    current: f.currentLevel,
    warning: f.warningLevel,
    danger:  f.dangerLevel,
    hfl:     (f.hfl != null && f.hfl! > 0)
                 ? f.hfl!
                 : (f.dangerLevel > 0 ? f.dangerLevel * 1.3 : 0),
  )).toList();

  /// Convenience: loading sentinel with no stations.
  factory DataFetchSnapshot.loading() => DataFetchSnapshot(
    stations:  const [],
    fetchedAt: DateTime.now(),
    isLoading: true,
  );
}

class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();

  final _snapshotController =
      StreamController<DataFetchSnapshot>.broadcast();

  Stream<DataFetchSnapshot> get snapshotStream => _snapshotController.stream;
  Stream<DataFetchSnapshot> get alertStream    => snapshotStream;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    // Emit loading sentinel immediately so UI shows spinner
    _snapshotController.add(DataFetchSnapshot.loading());
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(const Duration(minutes: 15), _fetch);
  }

  Future<void> _fetch() async {
    if (!_running) return;
    try {
      _snapshotController.add(DataFetchSnapshot(
        stations:  const [],
        fetchedAt: DateTime.now(),
      ));
    } catch (_) {}
    _scheduleNext();
  }

  void stop() => _running = false;
}
