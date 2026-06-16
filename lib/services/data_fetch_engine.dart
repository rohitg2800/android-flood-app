// lib/services/data_fetch_engine.dart  v4.1
// StationReading lives in lib/models/station_reading.dart (canonical).
// This file only defines DataFetchSnapshot + DataFetchEngine.
//
// v4.1 — added _lastSnapshot field + `last` getter so callers
//         (e.g. kosi_birpur_provider) can access the most recent snapshot
//         synchronously without subscribing to the stream.
import 'dart:async';
import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../models/station_reading.dart';

export '../models/station_reading.dart'; // re-export so existing imports compile

// ─── DataFetchSnapshot ─────────────────────────────────────────────────────────
class DataFetchSnapshot {
  final List<FloodData>   stations;
  final DateTime          fetchedAt;
  final bool              isLoading;
  final int               liveStations;
  final int               totalStations;
  final Map<String, int>  sources;

  DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
    this.isLoading      = false,
    int?              liveStations,
    int?              totalStations,
    Map<String, int>? sources,
  })  : totalStations = totalStations ?? stations.length,
        liveStations  = liveStations  ?? stations.where((s) => s.status == 'LIVE').length,
        sources       = sources        ?? _buildSourceMap(stations);

  static Map<String, int> _buildSourceMap(List<FloodData> ss) {
    final m = <String, int>{};
    for (final s in ss) {
      final k = s.source;
      m[k] = (m[k] ?? 0) + 1;
    }
    return Map.unmodifiable(m);
  }

  List<FloodData>    toFloodDataList()  => stations;

  List<RiverStation> toRiverStations() => stations.map((f) => RiverStation(
    city:    f.city,
    state:   f.state,
    river:   f.riverName ?? f.river,
    station: f.stationId,
    current: f.currentLevel,
    warning: f.warningLevel,
    danger:  f.dangerLevel,
    hfl:     f.hfl,
  )).toList();

  factory DataFetchSnapshot.loading() => DataFetchSnapshot(
    stations:  const [],
    fetchedAt: DateTime.now(),
    isLoading: true,
  );
}

// ─── DataFetchEngine ──────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();

  final _snapshotController =
      StreamController<DataFetchSnapshot>.broadcast();

  // v4.1: cache the most-recent snapshot for synchronous callers
  DataFetchSnapshot? _lastSnapshot;

  /// The most recently emitted snapshot, or null before the first fetch.
  DataFetchSnapshot? get last => _lastSnapshot;

  Stream<DataFetchSnapshot> get snapshotStream => _snapshotController.stream;
  Stream<DataFetchSnapshot> get alertStream    => snapshotStream;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    final loading = DataFetchSnapshot.loading();
    _lastSnapshot = loading;
    _snapshotController.add(loading);
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(const Duration(minutes: 15), _fetch);
  }

  Future<void> _fetch() async {
    if (!_running) return;
    try {
      final snap = DataFetchSnapshot(
        stations:  const [],
        fetchedAt: DateTime.now(),
      );
      _lastSnapshot = snap;
      _snapshotController.add(snap);
    } catch (_) {}
    _scheduleNext();
  }

  void stop() => _running = false;
}
