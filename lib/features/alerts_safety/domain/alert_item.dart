enum AlertSeverity { emergency, critical, warning, info }

class AlertItem {
  final String id;
  final String title;
  final String message;
  final String station;
  final AlertSeverity severity;
  final DateTime time;

  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.station,
    required this.severity,
    required this.time,
  });

  String get severityLabel {
    switch (severity) {
      case AlertSeverity.emergency: return 'EMERGENCY';
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.warning:   return 'WARNING';
      case AlertSeverity.info:      return 'INFO';
    }
  }

  bool get isUrgent =>
      severity == AlertSeverity.emergency ||
      severity == AlertSeverity.critical;
}