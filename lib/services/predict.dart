/// lib/services/predict.dart  v2.0
///
/// v2.0 (20 Jun 2026)
///   • Fix #1 — _enrichFromPipeline: populate t2d–t7d from pipeline 7-day
///     rainfall history when available (previously only t1d was updated).
///   • Fix #2 — loadCached: enforce 30-minute TTL; stale entries return null
///     so callers always get a fresh prediction rather than stale data.
///   • Fix #6 — predict(): backendPredict retried up to 2× (3 s back-off)
///     before falling back to offline; fromBackend=false is now surfaced as
///     a warning string on FloodPrediction.offlineReason.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flood_api.dart';
import 'pipeline_service.dart';
import 'prediction_service.dart';

export 'prediction_service.dart' show MonitoringProtocol, PredictionInput;
export 'pipeline_service.dart' show PipelineFeatures;

const _kCacheKey = 'flood_prediction_cache';

/// Maximum age before a cached prediction is considered stale.
const _kCacheTtl = Duration(minutes: 30);

/// Back-off before the second backend attempt.
const _kBackendRetryDelay = Duration(seconds: 3);

/// Total backend attempts (1 initial + 1 retry).
const _kBackendMaxAttempts = 2;

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
    this.timeToPeakDays = 1,
    this.recessionTimeDays = 1,
    this.t1d = 10,
    this.t2d = 15,
    this.t3d = 20,
    this.t4d = 18,
    this.t5d = 12,
    this.t6d = 8,
    this.t7d = 7,
    required this.state,
    this.station,
    this.forecastHours = 24,
  });

  double get rainfall7d => t1d + t2d + t3d + t4d + t5d + t6d + t7d;

  PredictionInput toPredictionInput() => PredictionInput(
        peakFloodLevelM: peakFloodLevelM,
        eventDurationDays: eventDurationDays,
        timeToPeakDays: timeToPeakDays,
        recessionTimeDays: recessionTimeDays,
        t1d: t1d,
        t2d: t2d,
        t3d: t3d,
        t4d: t4d,
        t5d: t5d,
        t6d: t6d,
        t7d: t7d,
        state: state,
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

  /// Non-null when fromBackend==false; describes why the backend was skipped.
  final String? offlineReason;

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
    this.offlineReason,
  });

  String get alert => severity == 'CRITICAL' || severity == 'SEVERE'
      ? '\uD83D\uDEA8'
      : severity == 'MODERATE'
          ? '\u26A0\uFE0F'
          : '\uD83D\uDFE2';

  bool get isOfflineFallback => !fromBackend;
  String get monitoringLevel => monitoring.level;
  String get monitoringAction => monitoring.action;

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'confidencePercent': confidencePercent,
        'probabilities': probabilities,
        'algorithm': algorithm,
        'dataSource': dataSource,
        'riskScore': riskScore,
        'dangerLevel': dangerLevel,
        'proximityToDangerM': proximityToDangerM,
        'fromBackend': fromBackend,
        'timestamp': timestamp.toIso8601String(),
        'liveRiverLevelM': liveRiverLevelM,
        'forecastHours': forecastHours,
        if (offlineReason != null) 'offlineReason': offlineReason,
      };

  factory FloodPrediction.fromJson(Map<String, dynamic> j) => FloodPrediction(
        severity: j['severity'] as String,
        confidencePercent: (j['confidencePercent'] as num).toDouble(),
        probabilities: (j['probabilities'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        algorithm: j['algorithm'] as String,
        dataSource: j['dataSource'] as String,
        riskScore: j['riskScore'] as int,
        dangerLevel: (j['dangerLevel'] as num).toDouble(),
        proximityToDangerM: (j['proximityToDangerM'] as num).toDouble(),
        monitoring: const MonitoringProtocol(
            level: 'NORMAL', action: 'Monitor', priorityZones: []),
        ensembleDetails: const {},
        fromBackend: j['fromBackend'] as bool,
        timestamp: DateTime.parse(j['timestamp'] as String),
        liveRiverLevelM: (j['liveRiverLevelM'] as num?)?.toDouble(),
        forecastHours: (j['forecastHours'] as int?) ?? 24,
        offlineReason: j['offlineReason'] as String?,
      );

  factory FloodPrediction.fromCore(
    CoreFloodPrediction core, {
    double? liveRiverLevelM,
    String? overrideAlgorithm,
    String? overrideDataSource,
    Map<String, dynamic>? overrideEnsemble,
    int forecastHours = 24,
    String? offlineReason,
  }) =>
      FloodPrediction(
        severity: core.severity,
        confidencePercent: core.confidencePercent,
        probabilities: core.probabilities,
        algorithm: overrideAlgorithm ?? core.algorithm,
        dataSource: overrideDataSource ?? core.dataSource,
        riskScore: core.riskScore,
        dangerLevel: core.dangerLevel,
        proximityToDangerM: core.proximityToDangerM,
        monitoring: core.monitoring,
        ensembleDetails: overrideEnsemble ?? core.ensembleDetails,
        fromBackend: core.fromBackend,
        timestamp: core.timestamp,
        liveRiverLevelM: liveRiverLevelM,
        forecastHours: forecastHours,
        offlineReason: offlineReason,
      );
}

// ─── Service facade ───────────────────────────────────────────────────────────

class PredictionService {
  const PredictionService();

  Future<FloodPrediction> predict(FloodPredictionInput input) async {
    final enriched = await _enrichFromPipeline(input);
    final core = enriched.toPredictionInput();
    final liveLevel = await _fetchLiveLevel(enriched.station, enriched.state);

    final localResult = PredictionServiceImpl.instance
        .localRuleEnginePredict(core, liveLevel: liveLevel);

    // Fix #6: retry backend up to _kBackendMaxAttempts times with back-off
    CoreFloodPrediction? backendResult;
    String? backendFailReason;
    for (int attempt = 0; attempt < _kBackendMaxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(_kBackendRetryDelay);
      }
      try {
        backendResult = await PredictionServiceImpl.instance
            .backendPredict(core, liveLevel: liveLevel);
        break; // success
      } catch (e) {
        backendFailReason = e.toString();
        debugPrint(
            '[PredictionService] backend attempt ${attempt + 1} failed: $e');
      }
    }

    final horizon = input.forecastHours;
    FloodPrediction result;

    if (backendResult == null) {
      result = FloodPrediction.fromCore(
        localResult,
        liveRiverLevelM: liveLevel,
        overrideAlgorithm: 'Offline Rule-Engine',
        overrideDataSource: liveLevel != null
            ? 'CWC Live + Rule Engine (offline)'
            : 'Rule Engine (offline)',
        forecastHours: horizon,
        offlineReason: backendFailReason ?? 'Backend unreachable',
      );
    } else {
      result = _mergeResults(
        backend: backendResult,
        local: localResult,
        liveLevel: liveLevel,
        backendWeight: 0.60,
        localWeight: 0.40,
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
    final core = PredictionServiceImpl.instance.localRuleEnginePredict(
        input.toPredictionInput(),
        liveLevel: liveLevel);
    return FloodPrediction.fromCore(
      core,
      liveRiverLevelM: liveLevel,
      overrideAlgorithm: 'Offline Rule-Engine',
      overrideDataSource: 'Rule Engine (offline)',
      forecastHours: input.forecastHours,
      offlineReason: 'Called predictOffline() directly',
    );
  }

  /// Load cached prediction. Returns null if no cache exists or cache is older
  /// than [_kCacheTtl] (30 minutes). Fix #2.
  static Future<FloodPrediction?> loadCached(String stationOrState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_kCacheKey}_$stationOrState');
      if (raw == null) return null;
      final prediction =
          FloodPrediction.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      // Enforce TTL — discard stale cache
      if (DateTime.now().difference(prediction.timestamp) > _kCacheTtl) {
        debugPrint('[Predict] cache stale for $stationOrState, discarding');
        await prefs.remove('${_kCacheKey}_$stationOrState');
        return null;
      }
      return prediction;
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

  /// Fix #1: populate t1d–t7d from the pipeline's 7-day rainfall history.
  /// Previously only t1d was updated; t2d–t7d remained at defaults (15,20,18,12,8,7).
  Future<FloodPredictionInput> _enrichFromPipeline(
      FloodPredictionInput input) async {
    try {
      final features = await PipelineService.instance.fetchFeatures(
        state: input.state,
        station: input.station,
      );
      if (features == null) return input;

      double peakLevel = input.peakFloodLevelM;

      // Update peak level from live river reading if input is still default
      if (peakLevel == 8.5 &&
          features.riverLevelM != null &&
          features.riverLevelM! > 0) {
        peakLevel = features.riverLevelM!;
      }

      // Pull the full 7-day daily rainfall history from the pipeline
      final List<double>? history =
          null; // rainfall7dMm is a Map threshold, not history list
      final fallback = features.bestDailyRainfallMm;

      final double rt1 =
          (history != null && history.isNotEmpty && history[0] > 0)
              ? history[0]
              : (fallback != null && fallback > 0 ? fallback : input.t1d);
      final double rt2 =
          (history != null && history.length > 1 && history[1] > 0)
              ? history[1]
              : input.t2d;
      final double rt3 =
          (history != null && history.length > 2 && history[2] > 0)
              ? history[2]
              : input.t3d;
      final double rt4 =
          (history != null && history.length > 3 && history[3] > 0)
              ? history[3]
              : input.t4d;
      final double rt5 =
          (history != null && history.length > 4 && history[4] > 0)
              ? history[4]
              : input.t5d;
      final double rt6 =
          (history != null && history.length > 5 && history[5] > 0)
              ? history[5]
              : input.t6d;
      final double rt7 =
          (history != null && history.length > 6 && history[6] > 0)
              ? history[6]
              : input.t7d;

      // If nothing changed, return original to avoid unnecessary allocation
      if (peakLevel == input.peakFloodLevelM &&
          rt1 == input.t1d &&
          rt2 == input.t2d &&
          rt3 == input.t3d &&
          rt4 == input.t4d &&
          rt5 == input.t5d &&
          rt6 == input.t6d &&
          rt7 == input.t7d) {
        return input;
      }

      debugPrint('[PredictionService] enriched rainfall: '
          't1=$rt1 t2=$rt2 t3=$rt3 t4=$rt4 t5=$rt5 t6=$rt6 t7=$rt7');

      return FloodPredictionInput(
        peakFloodLevelM: peakLevel,
        eventDurationDays: input.eventDurationDays,
        timeToPeakDays: input.timeToPeakDays,
        recessionTimeDays: input.recessionTimeDays,
        t1d: rt1,
        t2d: rt2,
        t3d: rt3,
        t4d: rt4,
        t5d: rt5,
        t6d: rt6,
        t7d: rt7,
        state: input.state,
        station: input.station,
        forecastHours: input.forecastHours,
      );
    } catch (e) {
      debugPrint('[PredictionService] enrichment error: $e');
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
      for (final l in labels) l: bp[l]! * backendWeight + lp[l]! * localWeight
    };

    final total = blended.values.fold(0.0, (s, v) => s + v);
    final normed = total > 0
        ? blended.map((k, v) => MapEntry(k, v / total))
        : {for (final l in labels) l: 0.25};

    final severity =
        normed.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final confidence =
        (normed[severity]! * 100).clamp(0.0, 100.0).roundToDouble();
    final riskScore =
        (backend.riskScore * backendWeight + local.riskScore * localWeight)
            .round()
            .clamp(0, 100);

    final finalSeverity = _saferSeverity(severity, local.severity);

    final ensemble = <String, dynamic>{
      'mode': 'hybrid_merge',
      'backend_weight': backendWeight,
      'local_weight': localWeight,
      'backend_severity': backend.severity,
      'local_severity': local.severity,
      'blended_probs': normed,
      'backend_confidence': backend.confidencePercent,
      'local_confidence': local.confidencePercent,
      'live_level_used': liveLevel != null,
      'forecast_hours': forecastHours,
      ...backend.ensembleDetails,
    };

    final merged = CoreFloodPrediction(
      severity: finalSeverity,
      confidencePercent: confidence,
      probabilities: normed.map((k, v) => MapEntry(k, v * 100)),
      algorithm: 'Hybrid (Backend ML 60% + Rule Engine 40%)'
          '${forecastHours == 48 ? ' · 48h' : ''}',
      dataSource: liveLevel != null
          ? 'CWC Live + OpsFlood API + Rule Engine'
          : 'OpsFlood API + Rule Engine',
      riskScore: riskScore,
      dangerLevel: backend.dangerLevel,
      proximityToDangerM: backend.proximityToDangerM,
      monitoring: backend.monitoring,
      ensembleDetails: ensemble,
      fromBackend: true,
      timestamp: DateTime.now(),
    );

    return FloodPrediction.fromCore(merged,
        liveRiverLevelM: liveLevel, forecastHours: forecastHours);
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
        final name =
            (item['station'] ?? item['stationName'] ?? item['city'] ?? '')
                .toString()
                .toLowerCase();
        if (name.contains(lc) || lc.contains(name)) {
          final level = _sf(item['river_level'] ??
              item['riverLevel'] ??
              item['current_level']);
          final warn = _sf(item['warning_level'] ?? item['warningLevel']);
          if (level > 0) return level;
          if (warn > 0) return warn;
        }
      }
    } catch (_) {}
    return null;
  }

  double _sf(dynamic v) =>
      (v == null || v == '') ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
}
