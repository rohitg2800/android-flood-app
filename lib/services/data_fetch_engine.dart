// lib/services/data_fetch_engine.dart  v4
// DataFetchSnapshot now includes liveStations, totalStations, toRiverStations()
// FloodStation field names corrected: riverName (not river), no hfl field,
// all level fields are double? (use ?? 0)
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flood_data.dart';
import '../models/flood_station.dart';
import 'flood_api.dart';

// ─── SourceStatus ──────────────────────────────────────────────────────────
class SourceStatus {
  final String name;
  final bool healthy;
  final int? latencyMs;
  final int stationCount;
  final String? errorMessage;

  const SourceStatus({
    required this.name,
    required this.healthy,
    this.latencyMs,
    this.stationCount = 0,
    this.errorMessage,
  });

  bool get isLive => healthy;
  bool get isFailing => !healthy && errorMessage != null;
  bool get isStale => !healthy && latencyMs == null;
  String get label =>
      healthy ? 'Live' : (errorMessage != null ? 'Error' : 'Stale');
}

// ─── DataFetchSnapshot ────────────────────────────────────────────────────────
class DataFetchSnapshot {
  final List<FloodData> stations;
  final DateTime fetchedAt;
  final bool isLoading;
  final List<SourceStatus> sources;
  final String? error;

  const DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
    required this.isLoading,
    this.sources = const [],
    this.error,
  });

  bool get isSuccess => !isLoading && error == null;

  // Getters used by BackendSyncService
  int get liveStations => stations.where((s) => s.status == 'LIVE').length;
  int get totalStations => stations.length;
  int get alertCount =>
      stations.where((d) => d.currentLevel >= d.warningLevel).length;
  int get healthyCount => sources.where((s) => s.healthy).length;

  // Used by main.dart — converts FloodData back to FloodStation list
  List<FloodStation> toRiverStations() => stations
      .map((d) => FloodStation(
            city: d.stationName,
            state: d.state ?? '',
            riverName: d.riverName ?? '',
            riskLevel: d.riskLevel,
            status: d.status,
            dataSource: d.source ?? '',
            currentLevel: d.currentLevel,
            warningLevel: d.warningLevel,
            dangerLevel: d.dangerLevel,
            lat: d.latitude,
            lon: d.longitude,
          ))
      .toList();
}

/// Backward-compat alias.
typedef FetchResult = DataFetchSnapshot;

// ─── DataFetchEngine ──────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();

  static const _kInterval = Duration(minutes: 5);

  final _controller = StreamController<DataFetchSnapshot>.broadcast();
  Timer? _timer;
  DataFetchSnapshot? _latest;

  Stream<DataFetchSnapshot> get stream => _controller.stream;
  Stream<DataFetchSnapshot> get snapshotStream => _controller.stream;
  DataFetchSnapshot? get last => _latest;
  DataFetchSnapshot? get latestResult => _latest;

  SourceStatus get overallStatus => _latest == null
      ? const SourceStatus(name: 'overall', healthy: false)
      : SourceStatus(
          name: 'overall',
          healthy: _latest!.isSuccess,
          stationCount: _latest!.stations.length,
          errorMessage: _latest!.error,
        );

  void start() {
    _timer?.cancel();
    _fetch();
    _timer = Timer.periodic(_kInterval, (_) => _fetch());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _fetch();

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> _fetch() async {
    final loading = DataFetchSnapshot(
      stations: _latest?.stations ?? [],
      fetchedAt: DateTime.now(),
      isLoading: true,
      sources: _latest?.sources ?? [],
    );
    if (!_controller.isClosed) _controller.add(loading);

    try {
      final sw = Stopwatch()..start();
      final data = await FloodApi.instance.fetchLiveLevels();
      sw.stop();

      final sources = [
        SourceStatus(
          name: 'GloFAS',
          healthy: data.isNotEmpty,
          latencyMs: sw.elapsedMilliseconds,
          stationCount: data.length,
        ),
      ];

      final floodData = data.map(_stationToFloodData).toList();

      final snap = DataFetchSnapshot(
        stations: floodData,
        fetchedAt: DateTime.now(),
        isLoading: false,
        sources: sources,
      );
      _latest = snap;
      if (!_controller.isClosed) _controller.add(snap);
      if (kDebugMode) {
        debugPrint(
            '[DataFetchEngine] fetched ${data.length} stations in ${sw.elapsedMilliseconds}ms');
      }
    } catch (e) {
      final stale = _latest?.stations ?? [];
      final snap = DataFetchSnapshot(
        stations: stale,
        fetchedAt: DateTime.now(),
        isLoading: false,
        sources: [
          SourceStatus(
            name: 'GloFAS',
            healthy: false,
            errorMessage: e.toString(),
            stationCount: stale.length,
          ),
        ],
        error: e.toString(),
      );
      _latest = snap;
      if (!_controller.isClosed) _controller.add(snap);
      if (kDebugMode) debugPrint('[DataFetchEngine] fetch error: $e');
    }
  }

  static FloodData _stationToFloodData(FloodStation s) => FloodData(
        stationId: s.city,
        stationName: s.city,
        river: s.riverName, // FloodStation uses riverName, not river
        district: s.city,
        state: s.state,
        currentLevel: s.currentLevel ?? 0,
        dangerLevel: s.dangerLevel ?? 0,
        warningLevel: s.warningLevel ?? 0,
        latitude: s.lat,
        longitude: s.lon,
        hfl: 0, // FloodStation has no hfl field
        source: s.dataSource,
        lastUpdated: DateTime.now(),
      );
}
