/// lib/services/prediction_service.dart
/// Core prediction engine — NOT imported by screens directly.
/// Screens use lib/services/predict.dart (PredictionService facade).
///
/// Implements the Hybrid Multi-Bundle Ensemble + Rule Engine.
/// ML models (.pkl) run on the OpsFlood backend (/predict/v2);
/// the rule engine runs locally as offline fallback.
///
/// STATE MATRIX: delegated entirely to PipelineService.entryForState()
/// which is fetched from /api/state-severity at startup (1-hour TTL).
///
/// FIX: base URL now uses AppConfig.baseUrl (railway.app) instead of
/// AppConstants.baseUrl (now delegates to AppConfig.baseUrl) — consistent with
/// every other service in the app.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'ops_client.dart';
import '../config/app_config.dart';
import 'pipeline_service.dart';

// Public type alias used by predict.dart
typedef CoreFloodPrediction = FloodPrediction;

// ─── Prediction result ────────────────────────────────────────────────────────

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
  });

  String get alertEmoji => severity == 'CRITICAL' || severity == 'SEVERE'
      ? '\uD83D\uDEA8'
      : severity == 'MODERATE'
          ? '\u26A0\uFE0F'
          : '\uD83D\uDFE2';
}

class MonitoringProtocol {
  final String level;
  final String action;
  final List<String> priorityZones;
  const MonitoringProtocol({
    required this.level,
    required this.action,
    required this.priorityZones,
  });

  factory MonitoringProtocol.fromJson(Map<String, dynamic> j) =>
      MonitoringProtocol(
        level: j['level']?.toString() ?? '',
        action: j['action']?.toString() ?? '',
        priorityZones: (j['priority_zones'] as List?)?.cast<String>() ?? [],
      );
}

// ─── Input model ──────────────────────────────────────────────────────────────

class PredictionInput {
  final double peakFloodLevelM;
  final double eventDurationDays;
  final double timeToPeakDays;
  final double recessionTimeDays;
  final double t1d, t2d, t3d, t4d, t5d, t6d, t7d;
  final String state;
  final String? station;

  const PredictionInput({
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
  });

  double get rainfall7d => t1d + t2d + t3d + t4d + t5d + t6d + t7d;

  Map<String, dynamic> toJson() => {
        'Peak_Flood_Level_m': peakFloodLevelM,
        'Event_Duration_days': eventDurationDays,
        'Time_to_Peak_days': timeToPeakDays,
        'Recession_Time_day': recessionTimeDays,
        'T1d': t1d,
        'T2d': t2d,
        'T3d': t3d,
        'T4d': t4d,
        'T5d': t5d,
        'T6d': t6d,
        'T7d': t7d,
        'state': state,
        if (station != null) 'station': station,
      };
}

// ─── Core service (singleton) ─────────────────────────────────────────────────

class PredictionServiceImpl {
  PredictionServiceImpl._();
  static final PredictionServiceImpl instance = PredictionServiceImpl._();

  StateEntry _entry(String state) =>
      PipelineService.instance.entryForState(state);

  // ── Backend /predict/v2 ───────────────────────────────────────────────────
  // FIX: was AppConstants.baseUrl (onrender.com) — now AppConfig.baseUrl
  //      (railway.app) matching BackendApiService and AppConfig endpoints.
  Future<FloodPrediction> backendPredict(PredictionInput input,
      {double? liveLevel}) async {
    final body = await OpsClient.instance.post(
      '/predict/v2',
      input.toJson(),
    );
    return _fromBackendJson(body);
  }

  FloodPrediction _fromBackendJson(Map<String, dynamic> j) {
    final probs = <String, double>{};
    final rawProbs = j['probabilities'];
    if (rawProbs is Map) {
      rawProbs.forEach((k, v) => probs[k.toString()] = (v as num).toDouble());
    }
    final mon = j['monitoring'];
    final monitoring = mon is Map<String, dynamic>
        ? MonitoringProtocol.fromJson(mon)
        : _monitoringFor(j['severity']?.toString() ?? 'LOW');

    return FloodPrediction(
      severity: j['severity']?.toString() ?? 'MODERATE',
      confidencePercent: (j['confidence_percent'] as num?)?.toDouble() ?? 70,
      probabilities: probs,
      algorithm: j['algorithm']?.toString() ?? 'Backend ML',
      dataSource: j['data_source']?.toString() ?? 'CWC + ML',
      riskScore: (j['risk_score'] as num?)?.toInt() ?? 50,
      dangerLevel: (j['danger_level'] as num?)?.toDouble() ?? 12.0,
      proximityToDangerM: (j['proximity_to_danger_m'] as num?)?.toDouble() ?? 0,
      monitoring: monitoring,
      ensembleDetails:
          j['ensemble'] is Map ? j['ensemble'] as Map<String, dynamic> : {},
      fromBackend: true,
      timestamp: DateTime.now(),
    );
  }

  // ── Local Rule-Engine (offline fallback) ──────────────────────────────────
  FloodPrediction localRuleEnginePredict(PredictionInput input,
      {double? liveLevel}) {
    final entry = _entry(input.state);
    final dailyRain = [
      input.t1d,
      input.t2d,
      input.t3d,
      input.t4d,
      input.t5d,
      input.t6d,
      input.t7d
    ];
    final totalRain = dailyRain.reduce((a, b) => a + b);
    final avgRain = totalRain / 7;
    final maxDaily = dailyRain.reduce(math.max);
    final rainDelta = dailyRain.last - dailyRain.first;
    final peak = input.peakFloodLevelM;

    final peakMod = peak / math.max(entry.peakLevelM['moderate']!, 0.001);
    final peakSev = peak / math.max(entry.peakLevelM['severe']!, 0.001);
    final peakCrit = peak / math.max(entry.peakLevelM['critical']!, 0.001);
    final rainMod =
        totalRain / math.max(entry.rainfall7dMm['moderate']!, 0.001);
    final rainSev = totalRain / math.max(entry.rainfall7dMm['severe']!, 0.001);
    final rainCrit =
        totalRain / math.max(entry.rainfall7dMm['critical']!, 0.001);
    final dangerR = peak / math.max(entry.peakLevelM['critical']!, 0.001);
    final concR = maxDaily / math.max(avgRain, 1.0);
    final durR = input.eventDurationDays / 4.0;
    final flashR = math.max(0.0, (2.5 - input.timeToPeakDays) / 2.5);
    final recR = math.min(1.5, input.recessionTimeDays / 3.0);
    final trendR = math.max(
        -1.0, math.min(1.0, rainDelta / math.max(totalRain, 1.0) * 7.0));

    final scores = {
      'LOW': math.max(0.05,
          1.25 - math.max(peakMod, rainMod) - math.max(0.0, dangerR - 0.88)),
      'MODERATE':
          math.max(0.05, 0.82 * rainMod + 0.78 * peakMod + 0.12 * durR - 0.82),
      'SEVERE': math.max(
          0.05,
          0.95 * rainSev +
              0.96 * peakSev +
              0.20 * concR +
              0.12 * durR +
              0.10 * math.max(0.0, trendR) -
              1.12),
      'CRITICAL': math.max(
          0.02,
          1.08 * rainCrit +
              1.12 * peakCrit +
              0.34 * math.max(0.0, dangerR - 1.0) +
              0.18 * math.max(0.0, concR - 1.35) +
              0.18 * flashR +
              0.10 * recR +
              0.12 * math.max(0.0, trendR) -
              1.25),
    };

    if (liveLevel != null && liveLevel < entry.warningLevelM) {
      scores['SEVERE'] = 0;
      scores['CRITICAL'] = 0;
    }

    final probs = _normalise(scores);
    final severity =
        probs.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    const riskWeights = {
      'LOW': 16,
      'MODERATE': 46,
      'SEVERE': 78,
      'CRITICAL': 96
    };
    final riskScore = probs.entries
        .fold(0.0, (s, e) => s + e.value * riskWeights[e.key]!)
        .round()
        .clamp(0, 100);

    return FloodPrediction(
      severity: severity,
      confidencePercent: (probs[severity]! * 100).roundToDouble(),
      probabilities: probs.map((k, v) => MapEntry(k, v * 100)),
      algorithm: 'Local Rule-Engine (offline fallback)',
      dataSource: liveLevel != null
          ? 'CWC Live + Rule Engine'
          : 'Tactical + Rule Engine',
      riskScore: riskScore,
      dangerLevel: entry.dangerLevelM,
      proximityToDangerM:
          double.parse((entry.dangerLevelM - peak).toStringAsFixed(2)),
      monitoring: _monitoringFor(severity),
      ensembleDetails: {
        'rule_signals': {
          'peak_moderate_ratio': peakMod,
          'peak_severe_ratio': peakSev,
          'rain_moderate_ratio': rainMod,
          'danger_ratio': dangerR,
          'concentration_ratio': concR,
        },
      },
      fromBackend: false,
      timestamp: DateTime.now(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, double> _normalise(Map<String, double> raw) {
    final total = raw.values.fold(0.0, (s, v) => s + math.max(0, v));
    if (total <= 0) {
      return {'LOW': 1.0, 'MODERATE': 0, 'SEVERE': 0, 'CRITICAL': 0};
    }
    return raw.map((k, v) => MapEntry(k, math.max(0, v) / total));
  }

  MonitoringProtocol _monitoringFor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return const MonitoringProtocol(
          level: 'CRITICAL EMERGENCY',
          action: 'Evacuate vulnerable river basins immediately.',
          priorityZones: [
            'Primary Catchment',
            'Downstream Villages',
            'Low-lying urban zones'
          ],
        );
      case 'SEVERE':
        return const MonitoringProtocol(
          level: 'HIGH ALERT',
          action: 'Deploy monitoring teams & prepare contingency measures.',
          priorityZones: ['Primary Catchment', 'Downstream Villages'],
        );
      case 'MODERATE':
        return const MonitoringProtocol(
          level: 'ELEVATED ALERT',
          action: 'Deploy monitoring teams & prep pumps.',
          priorityZones: ['Drainage bottlenecks', 'Main river gauge'],
        );
      default:
        return const MonitoringProtocol(
          level: 'STANDARD PROTOCOL',
          action: 'Maintain normal surveillance.',
          priorityZones: ['None'],
        );
    }
  }
}
