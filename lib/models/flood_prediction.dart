import 'package:flutter/foundation.dart';

import 'prediction_point.dart';

/// Unified prediction model consumed by:
/// - lib/screens/predict_screen_impl.dart
/// - lib/screens/city_detail_screen.dart
/// - lib/widgets/ai_prediction_panel.dart
///
/// The backend ML pipeline also has its own result type in
/// lib/services/predict.dart. This model is the UI-facing contract.
@immutable
class FloodPrediction {
  /// One of: LOW | MODERATE | SEVERE | CRITICAL
  final String severity;

  /// ML risk score (0..100).
  final double riskScore;

  /// Human-readable station label.
  final String station;

  /// Current river level (meters).
  final double currentLevel;

  /// Forecast danger threshold (meters).
  final double dangerLevel;

  /// Forecast warning threshold (meters).
  final double warningLevel;

  /// Predicted level for next 24/48/72 hours (meters).
  final double predicted24h;
  final double predicted48h;
  final double predicted72h;

  /// Trend label: 'rising' | 'steady' | 'falling'
  final String trend;

  /// Confidence between 0..100.
  final double confidencePct;

  /// Optional CWC risk score (0..100) if available.
  final double? cwcRiskScore;

  /// Backend algorithm/model version.
  final String modelVersion;

  /// Human-readable outlook.
  final String outlook;

  /// Whether this prediction came from backend ML.
  /// If false, it's an offline/rule-engine fallback.
  final bool fromBackend;

  /// Convenience: whether this prediction is offline.
  bool get isOffline => !fromBackend;

  /// Progress percentage of danger (0..100) used by UI gauges/cards.
  ///
  /// Backward-compat for older call sites that expected `progressPct`.
  double get progressPct => riskScore.clamp(0.0, 100.0);


  /// Sparkline series points for rendering.
  final List<PredictionPoint> next24h;
  final List<PredictionPoint> next48h;
  final List<PredictionPoint> next72h;

  final DateTime updatedAt;

  const FloodPrediction({
    required this.severity,
    required this.riskScore,
    required this.station,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.predicted24h,
    required this.predicted48h,
    required this.predicted72h,
    required this.trend,
    required this.confidencePct,
    required this.cwcRiskScore,
    required this.modelVersion,
    required this.outlook,
    required this.fromBackend,
    required this.next24h,
    required this.next48h,
    required this.next72h,
    required this.updatedAt,
  });

  /// Backward-compat aliases for older call sites.
  @Deprecated('Use station')
  String get stationName => station;

  @Deprecated('Use predicted24h')
  double get predictedLevel => predicted24h;

  @Deprecated('Use confidencePct/100')
  double get confidence => (confidencePct / 100).clamp(0.0, 1.0);

  @override
  String toString() {
    return 'FloodPrediction(severity: $severity, station: $station, currentLevel: $currentLevel, '
        'pred24h: $predicted24h, dangerLevel: $dangerLevel, warningLevel: $warningLevel, '
        'trend: $trend, confidencePct: $confidencePct, fromBackend: $fromBackend, updatedAt: $updatedAt)';
  }
}


