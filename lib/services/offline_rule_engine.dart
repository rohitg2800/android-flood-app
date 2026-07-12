// lib/services/offline_rule_engine.dart  v4
// Fixed: FloodAlert() constructor updated to match alert_engine.dart v5
// (uses message instead of body; optional fields passed correctly)
import '../models/station_reading.dart';
import 'alert_engine.dart';

class OfflineRuleEngine {
  OfflineRuleEngine._();
  static final OfflineRuleEngine instance = OfflineRuleEngine._();

  List<FloodAlert> evaluate(List<StationReading> readings) {
    final alerts = <FloodAlert>[];
    for (final r in readings) {
      final alert = _evalStation(r);
      if (alert != null) alerts.add(alert);
    }
    alerts.sort((a, b) => b.severity.priority.compareTo(a.severity.priority));
    return alerts;
  }

  FloodAlert? _evalStation(StationReading r) {
    final level = r.currentLevel;
    final hfl = r.hfl;
    final danger = r.dangerLevel;
    final warn = r.warningLevel;
    final ror = r.rateOfRiseMph;
    final rain = r.rainfall24hMm;

    if (hfl > 0 && level >= hfl)
      return _makeAlert(
          r, AlertSeverity.emergency, AlertType.levelAboveHfl, hfl);
    if (danger > 0 && level >= danger)
      return _makeAlert(
          r, AlertSeverity.critical, AlertType.levelAboveDanger, danger);
    if (warn > 0 && level >= warn)
      return _makeAlert(
          r, AlertSeverity.warning, AlertType.levelAboveWarning, warn);
    if (ror != null && ror >= 0.30)
      return _makeAlert(r, AlertSeverity.warning, AlertType.rapidRise, warn);
    if (rain != null && rain >= 100.0)
      return _makeAlert(
          r, AlertSeverity.warning, AlertType.rainfallExtreme, 100.0);
    if (rain != null && rain >= 64.5)
      return _makeAlert(r, AlertSeverity.info, AlertType.rainfallHeavy, 64.5);
    return null;
  }

  FloodAlert _makeAlert(
    StationReading r,
    AlertSeverity severity,
    AlertType type,
    double threshold,
  ) {
    final now = DateTime.now();
    final id =
        '${r.stationName.toLowerCase().replaceAll(' ', '_')}_offline_${type.name}';
    final title = '${r.stationName}: ${type.displayName}';
    final msg = '${r.stationName} on ${r.river} at '
        '${r.currentLevel.toStringAsFixed(2)} m '
        '(threshold: ${threshold.toStringAsFixed(2)} m). '
        '[OFFLINE rule-based alert]';
    final action = severity == AlertSeverity.emergency
        ? 'Evacuate immediately.'
        : severity == AlertSeverity.critical
            ? 'Issue Red Alert. Deploy rescue teams.'
            : 'Monitor closely. Alert downstream districts.';

    return FloodAlert(
      id: id,
      type: type,
      severity: severity,
      title: title,
      message: msg,
      body: msg,
      stationName: r.stationName,
      station: r.stationName,
      river: r.river,
      district: r.district,
      state: r.state,
      currentLevel: r.currentLevel,
      dangerLevel: r.dangerLevel,
      warningLevel: r.warningLevel,
      hfl: r.hfl,
      thresholdLevel: threshold,
      rateOfRiseMph: r.rateOfRiseMph,
      rainfall24hMm: r.rainfall24hMm,
      action: action,
      issuedAt: now,
      expiresAt: now.add(const Duration(hours: 6)),
    );
  }
}
