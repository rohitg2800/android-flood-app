// lib/services/data_fetch_engine.dart
// DataFetchEngine — emits DataFetchSnapshot on each successful fetch.
// snapshotStream is consumed by the alert pipeline in main.dart.
import 'dart:async';
import '../models/flood_data.dart';
import '../models/river_station.dart';

// ─── DataFetchSnapshot ────────────────────────────────────────────────────────
class DataFetchSnapshot {
  final List<FloodData> stations;
  final DateTime        fetchedAt;

  const DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
  });

  /// Used by push-notification path (alert_engine.evaluate).
  List<FloodData> toFloodDataList() => stations;

  /// Used by stream alert pipeline (alert_engine.evaluateMerged).
  /// Converts FloodData → RiverStation so evaluateMerged can process them.
  List<RiverStation> toRiverStations() => stations.map((f) => RiverStation(
    station:   f.stationId,
    river:     f.riverName ?? '',
    district:  f.district,
    state:     f.state,
    city:      f.city,
    current:   f.currentLevel,
    danger:    f.dangerLevel,
    warning:   f.warningLevel,
    riskLevel: f.riskLevel,
    source:    'LIVE',
    hfl:       f.hfl ?? 0,
  )).toList();
}

// ─── DataFetchEngine ──────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();

  final _snapshotController =
      StreamController<DataFetchSnapshot>.broadcast();

  /// Primary stream — consumed by main.dart alert pipeline.
  Stream<DataFetchSnapshot> get snapshotStream => _snapshotController.stream;

  /// Legacy alias.
  Stream<DataFetchSnapshot> get alertStream => snapshotStream;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
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
