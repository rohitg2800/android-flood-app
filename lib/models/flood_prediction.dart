// lib/models/flood_prediction.dart
// OpsFlood — FloodPrediction model
//
// v2: added `river` getter derived from station label
import 'prediction_point.dart';

class FloodPrediction {
  const FloodPrediction({
    required this.severity,
    required this.riskScore,
    required this.station,
    required this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    required this.predicted24h,
    required this.predicted48h,
    required this.predicted72h,
    required this.trend,
    required this.confidencePct,
    required this.modelVersion,
    required this.outlook,
    required this.fromBackend,
    required this.next24h,
    required this.next48h,
    required this.next72h,
    required this.updatedAt,
    this.cwcRiskScore,
  });

  final String   severity;       // 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL'
  final double   riskScore;      // 0–100
  final String   station;        // e.g. "Birpur (Kosi)"
  final double   currentLevel;
  final double   warningLevel;
  final double   dangerLevel;
  final double   predicted24h;
  final double   predicted48h;
  final double   predicted72h;
  final String   trend;          // 'Rising' | 'Falling' | 'Steady'
  final double   confidencePct;  // 0–100
  final double?  cwcRiskScore;
  final String   modelVersion;
  final String   outlook;
  final bool     fromBackend;
  final List<PredictionPoint> next24h;
  final List<PredictionPoint> next48h;
  final List<PredictionPoint> next72h;
  final DateTime updatedAt;

  // ── Derived getters ────────────────────────────────────────────────────────────

  /// Extract river name from station label "StationName (RiverName)".
  /// Falls back to the full station string if no parentheses found.
  String get river {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(station);
    return match?.group(1) ?? station;
  }

  double get progressPct =>
      dangerLevel > 0 ? (currentLevel / dangerLevel * 100).clamp(0, 150) : 0;

  bool get isCritical  => severity == 'CRITICAL';
  bool get isSevere    => severity == 'SEVERE' || isCritical;
  bool get isModerate  => severity == 'MODERATE';

  @override
  String toString() =>
      'FloodPrediction($station, $severity, risk=$riskScore)';
}
