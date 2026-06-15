// lib/services/data_fetch_engine.dart
// v3 (15 Jun 2026) — restore StationReading class (was lost in a prior merge).
//   StationReading is the flat type used by ActiveAlertController.push().
//   DataFetchSnapshot carries List<FloodData> (separate path).
import 'dart:async';
import '../models/flood_data.dart';
import '../models/river_station.dart';

// ─── StationReading ───────────────────────────────────────────────────────────────
/// Flat reading fed into ActiveAlertController.push().
/// Mirrors every field that active_alert_controller.dart reads from `s`.
class StationReading {
  final String  stationName;
  final String  river;
  final String  district;
  final double  currentLevel;
  final double  warningLevel;
  final double  dangerLevel;
  final double  hfl;
  final bool    isLive;
  final String  source;           // 'CWC' | 'RTDAS' | 'SEED' | 'LIVE'
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
    this.isLive        = false,
    this.source        = 'LIVE',
    this.rateOfRiseMph,
    this.rainfall24hMm,
  });

  /// Convert from RiverStation — used by alerts_parent_bridge_provider.
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

  /// Convert from FloodData.
  factory StationReading.fromFloodData(FloodData f) => StationReading(
    stationName:   f.stationName,
    river:         f.riverName ?? f.river,
    district:      f.district,
    currentLevel:  f.currentLevel,
    warningLevel:  f.warningLevel,
    dangerLevel:   f.dangerLevel,
    hfl:           f.hfl,          // non-nullable double getter (v5)
    isLive:        f.status == 'LIVE',
    source:        f.source,
    rateOfRiseMph: f.rateOfRiseMph,
    rainfall24hMm: f.rainfall24hMm,
  );
}

// ─── DataFetchSnapshot ──────────────────────────────────────────────────────────
class DataFetchSnapshot {
  final List<FloodData>    stations;
  final DateTime           fetchedAt;
  final bool               isLoading;
  final int                liveStations;
  final int                totalStations;
  final Map<String, int>   sources;

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
    hfl:     f.hfl,   // non-nullable double (v5 getter)
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

  Stream<DataFetchSnapshot> get snapshotStream => _snapshotController.stream;
  Stream<DataFetchSnapshot> get alertStream    => snapshotStream;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
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
