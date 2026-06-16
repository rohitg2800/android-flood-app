/// lib/services/predict.dart
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flood_api.dart';
import 'pipeline_service.dart';
import 'prediction_service.dart';

export 'prediction_service.dart' show MonitoringProtocol, PredictionInput;
export 'pipeline_service.dart'   show PipelineFeatures;

const _kCacheKey = 'flood_prediction_cache';

// ─── Input ────────────────────────────────────────────────────────────────────

class FloodPredictionInput {
  final double peakFloodLevelM;
  final double eventDurationDays;
  final double timeToPeakDays;
  final double recessionTimeDays;
  final double t1d, t2d, t3d, t4d, t5d, t6d, t7d;
  final String state;
  final String? station;
  final int forecastHours;

  const FloodPredictionInput({
    required this.peakFloodLevelM,
    this.eventDurationDays = 1,
    this.timeToPeakDays    = 1,
    this.recessionTimeDays = 1,
    this.t1d = 10, this.t2d = 15, this.t3d = 20,
    this.t4d = 18, this.t5d = 12, this.t6d = 8, this.t7d = 7,
    required this.state,
    this.station,
    this.forecastHours = 24,
  });

  double get rainfall7d => t1d + t2d + t3d + t4d + t5d + t6d + t7d;

  PredictionInput toPredictionInput() => PredictionInput(
    peakFloodLevelM:   peakFloodLevelM,
    eventDurationDays: eventDurationDays,
    timeToPeakDays:    timeToPeakDays,
    recessionTimeDays: recessionTimeDays,
    t1d: t1d, t2d: t2d, t3d: t3d,
    t4d: t4d, t5d: t5d, t6d: t6d, t7d: t7d,
    state:   state,
    station: station,
  );
}

// ─── Exception ────────────────────────────────────────────────────────────────

class PredictionException implements Exception {
  final String message;
  const PredictionException(this.message);
  @override
  String toString() => 'PredictionException: $message';
}

// ─── Result ───────────────────────────────────────────────────────────────────

class FloodPrediction {
  final String severity;
  final double confidencePercent;
  final Map<String, double> probabilities;
  final String algorithm;
  final String dataSource;
  final int riskScore;
  final double dangerLevel;
  final double proximityToDangerM;
  final MonitoringProtocol monitoring;
  final Map<String, dynamic> ensembleDetails;
  final bool fromBackend;
  final DateTime timestamp;
  final double? liveRiverLevelM;
  final int forecastHours;

  const FloodPrediction({
    required this.severity,
    required this.confidencePercent,
    required this.probabilities,
    required this.algorithm,
    required this.dataSource,
    required this.riskScore,
    required this.dangerLevel,
    required this.proximityToDangerM,
    required this.monitoring,
    required this.ensembleDetails,
    required this.fromBackend,
    required this.timestamp,
    this.liveRiverLevelM,
    this.forecastHours = 24,
  });

  String get alert =>
      severity == 'CRITICAL' || severity == 'SEVERE' ? '\uD83D\uDEA8' :
      severity == 'MODERATE' ? '\u26A0\uFE0F' : '\uD83D\uDFE2';

  bool get isOfflineFallback => !fromBackend;
  String get monitoringLevel  => monitoring.level;
  String get monitoringAction => monitoring.action;

  Map<String, dynamic> toJson() => {
    'severity':           severity,
    'confidencePercent':  confidencePercent,
    'probabilities':      probabilities,
    'algorithm':          algorithm,
    'dataSource':         dataSource,
    'riskScore':          riskScore,
    'dangerLevel':        dangerLevel,
    'proximityToDangerM': proximityToDangerM,
    'fromBackend':        fromBackend,
    'timestamp':          timestamp.toIso8601String(),
    'liveRiverLevelM':    liveRiverLevelM,
    'forecastHours':      forecastHours,
  };

  factory FloodPrediction.fromJson(Map<String, dynamic> j) => FloodPrediction(
    severity:           j['severity'] as String,
    confidencePercent:  (j['confidencePercent'] as num).toDouble(),
    probabilities:      (j['probabilities'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toDouble())),
    algorithm:          j['algorithm'] as String,
    dataSource:         j['dataSource'] as String,
    riskScore:          j['riskScore'] as int,
    dangerLevel:        (j['dangerLevel'] as num).toDouble(),
    proximityToDangerM: (j['proximityToDangerM'] as num).toDouble(),
    monitoring:         const MonitoringProtocol(level: 'NORMAL', action: 'Monitor', priorityZones: []),
    ensembleDetails:    const {},
    fromBackend:        j['fromBackend'] as bool,
    timestamp:          DateTime.parse(j['timestamp'] as String),
    liveRiverLevelM:    (j['liveRiverLevelM'] as num?)?.toDouble(),
    forecastHours:      (j['forecastHours'] as int?) ?? 24,
  );

  factory FloodPrediction.fromCore(
    CoreFloodPrediction core, {
    double? liveRiverLevelM,
    String? overrideAlgorithm,
    String? overrideDataSource,
    Map<String, dynamic>? overrideEnsemble,
    int forecastHours = 24,
  }) =>
      FloodPrediction(
        severity:           core.severity,
        confidencePercent:  core.confidencePercent,
        probabilities:      core.probabilities,
        algorithm:          overrideAlgorithm  ?? core.algorithm,
        dataSource:         overrideDataSource ?? core.dataSource,
        riskScore:          core.riskScore,
        dangerLevel:        core.dangerLevel,
        proximityToDangerM: core.proximityToDangerM,
        monitoring:         core.monitoring,
        ensembleDetails:    overrideEnsemble   ?? core.ensembleDetails,
        fromBackend:        core.fromBackend,
        timestamp:          core.timestamp,
        liveRiverLevelM:    liveRiverLevelM,
        forecastHours:      forecastHours,
      );
}

// ─── Service facade ───────────────────────────────────────────────────────────

class PredictionService {
  const PredictionService();

  Future<FloodPrediction> predict(FloodPredictionInput input) async {
    final enriched   = await _enrichFromPipeline(input);
    final core       = enriched.toPredictionInput();
    final liveLevel  = await _fetchLiveLevel(enriched.station, enriched.state);

    final localResult = PredictionServiceImpl.instance
        .localRuleEnginePredict(core, liveLevel: liveLevel);

    CoreFloodPrediction? backendResult;
    try {
      backendResult = await PredictionServiceImpl.instance
          .backendPredict(core, liveLevel: liveLevel);
    } catch (_) {}

    final horizon = input.forecastHours;
    FloodPrediction result;

    if (backendResult == null) {
      result = FloodPrediction.fromCore(
        localResult,
        liveRiverLevelM:    liveLevel,
        overrideAlgorithm:  'Offline Rule-Engine',
        overrideDataSource: liveLevel != null
            ? 'CWC Live + Rule Engine (offline)'
            : 'Rule Engine (offline)',
        forecastHours: horizon,
      );
    } else {
      result = _mergeResults(
        backend:       backendResult,
        local:         localResult,
        liveLevel:     liveLevel,
        backendWeight: 0.60,
        localWeight:   0.40,
        forecastHours: horizon,
      );
    }

    await _saveCache(result, input.station ?? input.state);
    return result;
  }

  FloodPrediction predictOffline(
    FloodPredictionInput input, {
    double? liveLevel,
  }) {
    final core = PredictionServiceImpl.instance
        .localRuleEnginePredict(input.toPredictionInput(), liveLevel: liveLevel);
    return FloodPrediction.fromCore(
      core,
      liveRiverLevelM:    liveLevel,
      overrideAlgorithm:  'Offline Rule-Engine',
      overrideDataSource: 'Rule Engine (offline)',
      forecastHours:      input.forecastHours,
    );
  }

  static Future<FloodPrediction?> loadCached(String stationOrState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('${_kCacheKey}_$stationOrState');
      if (raw == null) return null;
      return FloodPrediction.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Predict] cache load error: $e');
      return null;
    }
  }

  static Future<void> _saveCache(
      FloodPrediction p, String stationOrState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_kCacheKey}_$stationOrState', jsonEncode(p.toJson()));
    } catch (e) {
      debugPrint('[Predict] cache save error: $e');
    }
  }

  Future<FloodPredictionInput> _enrichFromPipeline(
      FloodPredictionInput input) async {
    try {
      final features = await PipelineService.instance.fetchFeatures(
        state:   input.state,
        station: input.station,
      );
      if (features == null) return input;

      double peakLevel = input.peakFloodLevelM;
      double t1d       = input.t1d;

      if (peakLevel == 8.5 &&
          features.riverLevelM != null &&
          features.riverLevelM! > 0) {
        peakLevel = features.riverLevelM!;
      }
      final dailyRain = features.bestDailyRainfallMm;
      if (t1d == 10.0 && dailyRain != null && dailyRain > 0) {
        t1d = dailyRain;
      }
      if (peakLevel == input.peakFloodLevelM && t1d == input.t1d) return input;

      return FloodPredictionInput(
        peakFloodLevelM:   peakLevel,
        eventDurationDays: input.eventDurationDays,
        timeToPeakDays:    input.timeToPeakDays,
        recessionTimeDays: input.recessionTimeDays,
        t1d: t1d,
        t2d: input.t2d, t3d: input.t3d, t4d: input.t4d,
        t5d: input.t5d, t6d: input.t6d, t7d: input.t7d,
        state:         input.state,
        station:       input.station,
        forecastHours: input.forecastHours,
      );
    } catch (_) {
      return input;
    }
  }

  FloodPrediction _mergeResults({
    required CoreFloodPrediction backend,
    required CoreFloodPrediction local,
    required double backendWeight,
    required double localWeight,
    double? liveLevel,
    int forecastHours = 24,
  }) {
    const labels = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];

    Map<String, double> norm(Map<String, double> p) {
      final sum = p.values.fold(0.0, (s, v) => s + v);
      if (sum <= 0) return {for (final l in labels) l: 0.25};
      final scale = sum > 2.0 ? 100.0 : 1.0;
      return {for (final l in labels) l: (p[l] ?? 0) / scale};
    }

    final bp = norm(backend.probabilities);
    final lp = norm(local.probabilities);

    final blended = <String, double>{
      for (final l in labels)
        l: bp[l]! * backendWeight + lp[l]! * localWeight
    };

    final total  = blended.values.fold(0.0, (s, v) => s + v);
    final normed = total > 0
        ? blended.map((k, v) => MapEntry(k, v / total))
        : {for (final l in labels) l: 0.25};

    final severity   = normed.entries
        .reduce((a, b) => a.value >= b.value ? a : b).key;
    final confidence = (normed[severity]! * 100)
        .clamp(0.0, 100.0).roundToDouble();
    final riskScore  = (backend.riskScore * backendWeight +
            local.riskScore * localWeight)
        .round().clamp(0, 100);

    final finalSeverity = _saferSeverity(severity, local.severity);

    final ensemble = <String, dynamic>{
      'mode':               'hybrid_merge',
      'backend_weight':     backendWeight,
      'local_weight':       localWeight,
      'backend_severity':   backend.severity,
      'local_severity':     local.severity,
      'blended_probs':      normed,
      'backend_confidence': backend.confidencePercent,
      'local_confidence':   local.confidencePercent,
      'live_level_used':    liveLevel != null,
      'forecast_hours':     forecastHours,
      ...backend.ensembleDetails,
    };

    final merged = CoreFloodPrediction(
      severity:           finalSeverity,
      confidencePercent:  confidence,
      probabilities:      normed.map((k, v) => MapEntry(k, v * 100)),
      algorithm: 'Hybrid (Backend ML 60% + Rule Engine 40%)'
          '${forecastHours == 48 ? ' · 48h' : ''}',
      dataSource: liveLevel != null
          ? 'CWC Live + OpsFlood API + Rule Engine'
          : 'OpsFlood API + Rule Engine',
      riskScore:          riskScore,
      dangerLevel:        backend.dangerLevel,
      proximityToDangerM: backend.proximityToDangerM,
      monitoring:         backend.monitoring,
      ensembleDetails:    ensemble,
      fromBackend:        true,
      timestamp:          DateTime.now(),
    );

    return FloodPrediction.fromCore(merged,
        liveRiverLevelM: liveLevel,
        forecastHours:   forecastHours);
  }

  String _saferSeverity(String a, String b) {
    const rank = {'LOW': 0, 'MODERATE': 1, 'SEVERE': 2, 'CRITICAL': 3};
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b;
  }

  Future<double?> _fetchLiveLevel(String? station, String state) async {
    if (station == null || station.isEmpty) return null;
    try {
      final response = await FloodApi.instance.cwcStations();
      final raw = response['data'];
      if (raw is! List) return null;
      final items = raw.whereType<Map<String, dynamic>>().toList();
      final lc = station.toLowerCase();
      for (final item in items) {
        final name = (item['station'] ?? item['stationName'] ??
                item['city'] ?? '')
            .toString().toLowerCase();
        if (name.contains(lc) || lc.contains(name)) {
          final level = _sf(item['river_level'] ??
              item['riverLevel'] ?? item['current_level']);
          final warn  = _sf(item['warning_level'] ?? item['warningLevel']);
          if (level > 0) return level;
          if (warn  > 0) return warn;
        }
      }
    } catch (_) {}
    return null;
  }

  double _sf(dynamic v) =>
      (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
}
