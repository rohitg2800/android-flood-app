enum ForecastSeverity { critical, severe, moderate, normal }

class ForecastItem {
  final String station;
  final String river;
  final double predicted24h;
  final double predicted48h;
  final double predicted72h;
  final double riskScore;
  final ForecastSeverity severity;

  const ForecastItem({
    required this.station,
    required this.river,
    required this.predicted24h,
    required this.predicted48h,
    required this.predicted72h,
    required this.riskScore,
    required this.severity,
  });

  String get severityLabel {
    switch (severity) {
      case ForecastSeverity.critical:
        return 'CRITICAL';
      case ForecastSeverity.severe:
        return 'SEVERE';
      case ForecastSeverity.moderate:
        return 'MODERATE';
      case ForecastSeverity.normal:
        return 'NORMAL';
    }
  }
}
