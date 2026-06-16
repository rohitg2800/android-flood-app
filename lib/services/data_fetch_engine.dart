// lib/services/data_fetch_engine.dart  v3
// Defines:
//   SourceStatus  — per-source health class (name, healthy, latencyMs, stationCount, errorMessage)
//   DataFetchSnapshot — snapshot broadcast by DataFetchEngine
//   FetchResult   — kept for backward compat (alias of DataFetchSnapshot)
//   DataFetchEngine — periodic fetcher; exposes stream, snapshotStream, last, latestResult
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flood_data.dart';
import 'flood_api.dart';

// ─── SourceStatus ─────────────────────────────────────────────────────────────
/// Per-data-source health record used by SystemStats and DashboardFooter.
class SourceStatus {
  final String  name;
  final bool    healthy;
  final int?    latencyMs;
  final int     stationCount;
  final String? errorMessage;

  const SourceStatus({
    required this.name,
    required this.healthy,
    this.latencyMs,
    this.stationCount = 0,
    this.errorMessage,
  });

  bool   get isLive    => healthy;
  bool   get isFailing => !healthy && errorMessage != null;
  bool   get isStale   => !healthy && latencyMs == null;
  String get label     => healthy ? 'Live' : (errorMessage != null ? 'Error' : 'Stale');

  @override
  String toString() => 'SourceStatus($name, healthy=$healthy)';
}

// ─── DataFetchSnapshot ────────────────────────────────────────────────────────
/// Snapshot emitted by DataFetchEngine every fetch cycle.
class DataFetchSnapshot {
  final List<FloodData>    stations;
  final DateTime           fetchedAt;
  final bool               isLoading;
  final List<SourceStatus> sources;
  final String?            error;

  const DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
    required this.isLoading,
    this.sources = const [],
    this.error,
  });

  bool get isSuccess    => !isLoading && error == null;
  int  get alertCount   => stations.where((d) => d.currentLevel >= d.warningLevel).length;
  int  get healthyCount => sources.where((s) => s.healthy).length;
}

/// Backward-compat alias.
typedef FetchResult = DataFetchSnapshot;

// ─── DataFetchEngine ──────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();

  static const _kInterval = Duration(minutes: 5);

  final _controller = StreamController<DataFetchSnapshot>.broadcast();
  Timer?             _timer;
  DataFetchSnapshot? _latest;

  // ─ Public API ───────────────────────────────────────────────────────────────

  /// Broadcast stream of [DataFetchSnapshot] events.
  Stream<DataFetchSnapshot> get stream         => _controller.stream;
  /// Alias used by widgets that import `snapshotStream`.
  Stream<DataFetchSnapshot> get snapshotStream => _controller.stream;

  /// Latest snapshot; null before first fetch.
  DataFetchSnapshot? get last          => _latest;
  DataFetchSnapshot? get latestResult  => _latest;

  SourceStatus get overallStatus => _latest == null
      ? const SourceStatus(name: 'overall', healthy: false)
      : SourceStatus(
          name:         'overall',
          healthy:      _latest!.isSuccess,
          stationCount: _latest!.stations.length,
          errorMessage: _latest!.error,
        );

  /// Start periodic fetching every 5 minutes.
  void start() {
    _timer?.cancel();
    _fetch();
    _timer = Timer.periodic(_kInterval, (_) => _fetch());
  }

  /// Stop periodic fetching.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Force an immediate refresh.
  Future<void> refresh() => _fetch();

  /// Dispose the engine (call on app teardown).
  void dispose() {
    stop();
    _controller.close();
  }

  // ─ Internals ────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    final loading = DataFetchSnapshot(
      stations:  _latest?.stations ?? [],
      fetchedAt: DateTime.now(),
      isLoading: true,
      sources:   _latest?.sources ?? [],
    );
    if (!_controller.isClosed) _controller.add(loading);

    try {
      final sw    = Stopwatch()..start();
      final data  = await FloodApi.instance.fetchLiveLevels();
      sw.stop();

      // Build a synthetic per-source status from the live result.
      final sources = [
        SourceStatus(
          name:         'GloFAS',
          healthy:      data.isNotEmpty,
          latencyMs:    sw.elapsedMilliseconds,
          stationCount: data.length,
        ),
      ];

      // Convert FloodStation → FloodData (best-effort shim)
      final floodData = data.map((s) => FloodData(
        stationId:    s.city,
        stationName:  s.city,
        river:        s.river,
        district:     s.city,
        state:        s.state,
        currentLevel: s.currentLevel,
        dangerLevel:  s.dangerLevel,
        warningLevel: s.warningLevel,
        latitude:     s.lat,
        longitude:    s.lon,
        hfl:          s.hfl,
        source:       'GloFAS',
        lastUpdated:  DateTime.now(),
      )).toList();

      final snap = DataFetchSnapshot(
        stations:  floodData,
        fetchedAt: DateTime.now(),
        isLoading: false,
        sources:   sources,
      );
      _latest = snap;
      if (!_controller.isClosed) _controller.add(snap);
      if (kDebugMode) debugPrint('[DataFetchEngine] fetched ${data.length} stations in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      final stale = _latest?.stations ?? [];
      final snap  = DataFetchSnapshot(
        stations:  stale,
        fetchedAt: DateTime.now(),
        isLoading: false,
        sources: [
          SourceStatus(
            name:         'GloFAS',
            healthy:      false,
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
}
