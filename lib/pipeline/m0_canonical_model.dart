// lib/pipeline/m0_canonical_model.dart
//
// MODULE 0 — Canonical Model
// Single source of truth for every data structure in the unified pipeline.
// All other modules import from here only. No other model files are created;
// existing models (FloodData, FloodStation, RiverStation) are preserved and
// adapted via factory constructors / toJson bridges at the bottom.

library pipeline.canonical_model;

import 'package:flutter/foundation.dart';

// ────────────────────────────────────────────────────────────────────────────
// 0-A  RiskLevel
// ────────────────────────────────────────────────────────────────────────────

enum RiskLevel {
  normal,
  warning,
  danger,
  critical;

  static RiskLevel fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'warning':  return RiskLevel.warning;
      case 'danger':   return RiskLevel.danger;
      case 'critical': return RiskLevel.critical;
      default:         return RiskLevel.normal;
    }
  }

  String get label => name.toUpperCase();
}

// ────────────────────────────────────────────────────────────────────────────
// 0-B  DataSource
// ────────────────────────────────────────────────────────────────────────────

enum DataSource {
  wrdBihar(priority: 10),
  kosi(priority: 9),
  cwcDirect(priority: 8),
  befiqr(priority: 7),
  backend(priority: 5),
  glofas(priority: 4),
  openMeteo(priority: 3),
  rtdas(priority: 2),
  unknown(priority: 0);

  final int priority;
  const DataSource({required this.priority});

  static DataSource fromString(String? s) {
    switch ((s ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'wrdbihar': return DataSource.wrdBihar;
      case 'kosi':     return DataSource.kosi;
      case 'cwcdirect':
      case 'cwc':      return DataSource.cwcDirect;
      case 'befiqr':   return DataSource.befiqr;
      case 'backend':  return DataSource.backend;
      case 'glofas':   return DataSource.glofas;
      case 'openmeteo':return DataSource.openMeteo;
      case 'rtdas':    return DataSource.rtdas;
      default:         return DataSource.unknown;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 0-C  GaugeThresholds
// ────────────────────────────────────────────────────────────────────────────

@immutable
class GaugeThresholds {
  final double? warningLevel;
  final double? dangerLevel;
  final double? hfl;

  const GaugeThresholds({this.warningLevel, this.dangerLevel, this.hfl});

  GaugeThresholds merge(GaugeThresholds other) => GaugeThresholds(
    warningLevel: warningLevel ?? other.warningLevel,
    dangerLevel:  dangerLevel  ?? other.dangerLevel,
    hfl:          hfl          ?? other.hfl,
  );

  Map<String, dynamic> toJson() => {
    'wl': warningLevel, 'dl': dangerLevel, 'hfl': hfl,
  };
}

// ────────────────────────────────────────────────────────────────────────────
// 0-D  FloodRecord
// ────────────────────────────────────────────────────────────────────────────

@immutable
class FloodRecord {
  final String     stationKey;
  final String     stationName;
  final String     river;
  final String     state;
  final double?    lat;
  final double?    lon;
  final double?    currentLevel;
  final GaugeThresholds thresholds;
  final RiskLevel  riskLevel;
  final DataSource source;
  final DateTime   fetchedAt;
  final double?    rainfallMm;
  final double?    dischargeCms;
  final double?    predictedSeverity;
  final double?    riskScore;
  final double?    confidencePercent;

  const FloodRecord({
    required this.stationKey,
    required this.stationName,
    required this.river,
    required this.state,
    this.lat,
    this.lon,
    this.currentLevel,
    this.thresholds = const GaugeThresholds(),
    this.riskLevel  = RiskLevel.normal,
    required this.source,
    required this.fetchedAt,
    this.rainfallMm,
    this.dischargeCms,
    this.predictedSeverity,
    this.riskScore,
    this.confidencePercent,
  });

  FloodRecord mergeWith(FloodRecord other) => FloodRecord(
    stationKey:         stationKey,
    stationName:        stationName,
    river:              river,
    state:              state,
    lat:                lat ?? other.lat,
    lon:                lon ?? other.lon,
    currentLevel:       currentLevel ?? other.currentLevel,
    thresholds:         thresholds.merge(other.thresholds),
    riskLevel:          riskLevel.index >= other.riskLevel.index ? riskLevel : other.riskLevel,
    source:             source.priority >= other.source.priority ? source : other.source,
    fetchedAt:          fetchedAt.isAfter(other.fetchedAt) ? fetchedAt : other.fetchedAt,
    rainfallMm:         rainfallMm ?? other.rainfallMm,
    dischargeCms:       dischargeCms ?? other.dischargeCms,
    predictedSeverity:  predictedSeverity ?? other.predictedSeverity,
    riskScore:          riskScore ?? other.riskScore,
    confidencePercent:  confidencePercent ?? other.confidencePercent,
  );

  FloodRecord copyWith({
    RiskLevel?       riskLevel,
    GaugeThresholds? thresholds,
    double?          predictedSeverity,
    double?          riskScore,
    double?          confidencePercent,
  }) => FloodRecord(
    stationKey:        stationKey,
    stationName:       stationName,
    river:             river,
    state:             state,
    lat:               lat,
    lon:               lon,
    currentLevel:      currentLevel,
    thresholds:        thresholds ?? this.thresholds,
    riskLevel:         riskLevel  ?? this.riskLevel,
    source:            source,
    fetchedAt:         fetchedAt,
    rainfallMm:        rainfallMm,
    dischargeCms:      dischargeCms,
    predictedSeverity: predictedSeverity ?? this.predictedSeverity,
    riskScore:         riskScore         ?? this.riskScore,
    confidencePercent: confidencePercent ?? this.confidencePercent,
  );

  Map<String, dynamic> toJson() => {
    'stationKey':        stationKey,
    'stationName':       stationName,
    'river':             river,
    'state':             state,
    'lat':               lat,
    'lon':               lon,
    'currentLevel':      currentLevel,
    'thresholds':        thresholds.toJson(),
    'riskLevel':         riskLevel.label,
    'source':            source.name,
    'fetchedAt':         fetchedAt.toIso8601String(),
    'rainfallMm':        rainfallMm,
    'dischargeCms':      dischargeCms,
    'predictedSeverity': predictedSeverity,
    'riskScore':         riskScore,
    'confidencePercent': confidencePercent,
  };
}

// ────────────────────────────────────────────────────────────────────────────
// 0-E  PipelineSnapshot
// ────────────────────────────────────────────────────────────────────────────

@immutable
class PipelineSnapshot {
  final List<FloodRecord> records;
  final DateTime          generatedAt;
  final Duration          cycleTime;
  final Map<String, bool> sourceHealth;
  final List<String>      warnings;

  const PipelineSnapshot({
    required this.records,
    required this.generatedAt,
    required this.cycleTime,
    this.sourceHealth = const {},
    this.warnings     = const [],
  });

  List<Map<String, dynamic>> toStationMaps() =>
      records.map((r) => r.toJson()).toList();

  Map<String, Map<String, double?>> features() {
    final out = <String, Map<String, double?>>{};
    for (final r in records) {
      final key = r.state.toLowerCase();
      out.putIfAbsent(key, () => {
        'riverLevelM':         r.currentLevel,
        'bestDailyRainfallMm': r.rainfallMm,
        'dangerLevelM':        r.thresholds.dangerLevel,
      });
    }
    return out;
  }

  List<FloodRecord> get criticalRecords =>
      records.where((r) => r.riskLevel == RiskLevel.critical).toList();

  List<FloodRecord> get aboveDanger =>
      records.where((r) =>
          r.riskLevel == RiskLevel.danger ||
          r.riskLevel == RiskLevel.critical).toList();

  int  get totalStations => records.length;
  int  get alertingCount => aboveDanger.length;
  bool get hasAlerts     => alertingCount > 0;
}
