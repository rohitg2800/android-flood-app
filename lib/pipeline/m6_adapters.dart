// lib/pipeline/m6_adapters.dart
//
// MODULE 6 — Backward-Compat Adapters (Phase 1)
// All existing callers compile unchanged. Each class delegates to Orchestrator.
// Delete this file after Phase 3.

library pipeline.adapters;

import 'dart:async';
import '../models/flood_data.dart';
import '../models/flood_station.dart';
import 'm0_canonical_model.dart' as canon;
import 'm5_orchestrator.dart';

// ── DataFetchSnapshot (legacy shape) ──────────────────────────────────────

class DataFetchSnapshot {
  final List<FloodData> stations;
  final DateTime        fetchedAt;
  final bool            isLoading;
  final String?         error;
  const DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
    required this.isLoading,
    this.error,
  });
  bool get isSuccess     => !isLoading && error == null;
  int  get liveStations  => stations.where((s) => s.status == 'LIVE').length;
  int  get totalStations => stations.length;
  int  get alertCount    => stations.where((d) => d.currentLevel >= d.warningLevel).length;
  List<FloodStation> toRiverStations() => stations.map((d) => FloodStation(
    city:         d.stationName,
    state:        d.state,
    riverName:    d.river,
    riskLevel:    d.riskLevel,
    status:       d.status,
    dataSource:   d.source,
    currentLevel: d.currentLevel,
    warningLevel: d.warningLevel,
    dangerLevel:  d.dangerLevel,
    lat:          d.latitude,
    lon:          d.longitude,
  )).toList();
}

// ── DataFetchEngine shim ──────────────────────────────────────────────────

@Deprecated('Use Orchestrator.instance directly')
class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();
  Stream<DataFetchSnapshot> get stream         => Orchestrator.instance.stream.map(_toLegacy);
  Stream<DataFetchSnapshot> get snapshotStream => stream;
  DataFetchSnapshot? get last         => latestResult;
  DataFetchSnapshot? get latestResult {
    final s = Orchestrator.instance.latest;
    return s == null ? null : _toLegacy(s);
  }
  Future<void> init()    => Orchestrator.instance.start();
  Future<void> start()   => Orchestrator.instance.start();
  Future<void> refresh() => Orchestrator.instance.forceRefresh();
  static DataFetchSnapshot _toLegacy(canon.PipelineSnapshot snap) => DataFetchSnapshot(
    stations:  snap.records.map(_recordToFloodData).toList(),
    fetchedAt: snap.generatedAt,
    isLoading: false,
  );
}

// ── PipelineFeatures (legacy shape) ──────────────────────────────────────

class PipelineFeatures {
  final double? riverLevelM;
  final double? bestDailyRainfallMm;
  final double? dangerLevelM;
  const PipelineFeatures({this.riverLevelM, this.bestDailyRainfallMm, this.dangerLevelM});
}

// ── PipelineService shim ──────────────────────────────────────────────────

@Deprecated('Use Orchestrator.instance.latest?.features() directly')
class PipelineService {
  PipelineService._();
  static final PipelineService instance = PipelineService._();
  Future<void> init() => Orchestrator.instance.start();
  PipelineFeatures? fetchFeatures(String state) {
    final feats = Orchestrator.instance.latest?.features();
    if (feats == null) return null;
    final m = feats[state.toLowerCase()];
    if (m == null) return null;
    return PipelineFeatures(
      riverLevelM:         m['riverLevelM'],
      bestDailyRainfallMm: m['bestDailyRainfallMm'],
      dangerLevelM:        m['dangerLevelM'],
    );
  }
}

// ── LiveFetchEngine shim ──────────────────────────────────────────────────

@Deprecated('Use Orchestrator.instance directly')
class LiveFetchEngine {
  LiveFetchEngine._();
  static final LiveFetchEngine instance = LiveFetchEngine._();
  Stream<canon.PipelineSnapshot> get stream => Orchestrator.instance.stream;
  canon.PipelineSnapshot? get latest        => Orchestrator.instance.latest;
  Future<void> start()   => Orchestrator.instance.start();
  Future<void> dispose() => Orchestrator.instance.dispose();
}

// ── Helper ────────────────────────────────────────────────────────────────

FloodData _recordToFloodData(canon.FloodRecord r) => FloodData(
  stationId:    r.stationKey,
  stationName:  r.stationName,
  river:        r.river,
  district:     r.stationName,
  state:        r.state,
  currentLevel: r.currentLevel ?? 0.0,
  warningLevel: r.thresholds.warningLevel ?? 0.0,
  dangerLevel:  r.thresholds.dangerLevel  ?? 0.0,
  hfl:          r.thresholds.hfl          ?? 0.0,
  riskLevel:    r.riskLevel.label,
  status:       r.riskLevel == canon.RiskLevel.normal ? 'NORMAL' : 'ALERT',
  source:       r.source.name,
  latitude:     r.lat ?? 0.0,
  longitude:    r.lon ?? 0.0,
  lastUpdated:  r.fetchedAt,
);
