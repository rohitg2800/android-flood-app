// lib/services/data_fetch_engine.dart
import 'dart:async';
import '../models/flood_data.dart';
import '../models/river_station.dart';

class DataFetchSnapshot {
  final List<FloodData> stations;
  final DateTime        fetchedAt;

  const DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
  });

  List<FloodData> toFloodDataList() => stations;

  /// Converts to List<RiverStation> for AlertEngine.evaluateMerged().
  /// RiverStation has no district/riskLevel/source params — omitted.
  /// hfl is not on FloodData; use dangerLevel * 1.3 as a safe upper bound.
  List<RiverStation> toRiverStations() => stations.map((f) => RiverStation(
    city:    f.city,
    state:   f.state,
    river:   f.riverName ?? '',
    station: f.stationId,
    current: f.currentLevel,
    warning: f.warningLevel,
    danger:  f.dangerLevel,
    hfl:     f.dangerLevel > 0 ? f.dangerLevel * 1.3 : 0,
  )).toList();
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
