// lib/services/data_fetch_engine.dart
import 'dart:async';
import '../models/flood_data.dart';
import '../models/river_station.dart';

// ─── StationReading ───────────────────────────────────────────────────────────
/// Flat reading used by ActiveAlertController.push().
/// Mirrors the fields read inside active_alert_controller.dart.
class StationReading {
  final String  stationName;
  final String  river;
  final String  district;
  final double  currentLevel;
  final double  warningLevel;
  final double  dangerLevel;
  final double  hfl;
  final bool    isLive;
  final String  source;         // 'CWC' | 'RTDAS' | 'SEED' | 'LIVE'
  final double? rateOfRiseMph;
  final double? rainfall24hMm;

  const StationReading({
    required this.stationName,
    required this.river,
    required this.district,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    this.isLive       = false,
    this.source       = 'LIVE',
    this.rateOfRiseMph,
    this.rainfall24hMm,
  });

  /// Convert from RiverStation (used by alerts_parent_bridge_provider).
  factory StationReading.fromRiverStation(RiverStation s) => StationReading(
    stationName:   s.station,
    river:         s.river,
    district:      s.city,
    currentLevel:  s.current,
    warningLevel:  s.warning,
    dangerLevel:   s.danger,
    hfl:           s.hfl,
    isLive:        s.isLive,
    source:        s.dataSource ?? 'LIVE',
    rateOfRiseMph: null,
    rainfall24hMm: s.rainfallLastHour,
  );
}

// ─── DataFetchSnapshot ────────────────────────────────────────────────────────
class DataFetchSnapshot {
  final List<FloodData> stations;
  final DateTime        fetchedAt;
  final List<String>    sources;    // source tags present in this snapshot
  final bool            isLoading;

  const DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
    this.sources   = const [],
    this.isLoading = false,
  });

  int get liveStations  => stations.where((s) => s.source != 'SEED').length;
  int get totalStations => stations.length;

  List<FloodData>    toFloodDataList()  => stations;

  List<RiverStation> toRiverStations() => stations.map((f) => RiverStation(
    city:    f.city,
    state:   f.state,
    river:   f.riverName ?? '',
    station: f.stationId,
    current: f.currentLevel,
    warning: f.warningLevel,
    danger:  f.dangerLevel,
    hfl:     f.hfl,
  )).toList();
}

// ─── DataFetchEngine ──────────────────────────────────────────────────────────
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
