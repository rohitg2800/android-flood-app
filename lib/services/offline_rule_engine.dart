// lib/services/offline_rule_engine.dart
// OpsFlood — Module 5: Community & Offline
//
// OfflineRuleEngine  (v3 — fixed FloodAlert constructor to match alert_engine.dart v1.2)
// ─────────────────────────────────────────────────────────────────────────
// Evaluates CWC/WRD gauge readings against hard-coded threshold rules and
// produces List<FloodAlert> WITHOUT any network dependency.
//
// Rule hierarchy (highest severity wins per station):
//   1. level ≥ HFL              → emergency  / levelAboveHfl
//   2. level ≥ danger           → critical   / levelAboveDanger
//   3. level ≥ warning          → warning    / levelAboveWarning
//   4. rate-of-rise ≥ 0.30 m/h  → warning    / rapidRise
//   5. 24h rainfall ≥ 100 mm    → warning    / rainfallExtreme
//   6. 24h rainfall ≥ 64.5 mm   → info       / rainfallHeavy

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
    alerts.sort((a, b) =>
        b.severity.priority.compareTo(a.severity.priority));
    return alerts;
  }

  FloodAlert? _evalStation(StationReading r) {
    final level  = r.currentLevel;
    final hfl    = r.hfl;
    final danger = r.dangerLevel;
    final warn   = r.warningLevel;
    final ror    = r.rateOfRiseMph;
    final rain   = r.rainfall24hMm;

    if (hfl > 0 && level >= hfl) {
      return _makeAlert(r, AlertSeverity.emergency, AlertType.levelAboveHfl, hfl);
    }
    if (danger > 0 && level >= danger) {
      return _makeAlert(r, AlertSeverity.critical, AlertType.levelAboveDanger, danger);
    }
    if (warn > 0 && level >= warn) {
      return _makeAlert(r, AlertSeverity.warning, AlertType.levelAboveWarning, warn);
    }
    if (ror != null && ror >= 0.30) {
      return _makeAlert(r, AlertSeverity.warning, AlertType.rapidRise, warn);
    }
    if (rain != null && rain >= 100.0) {
      return _makeAlert(r, AlertSeverity.warning, AlertType.rainfallExtreme, 100.0);
    }
    if (rain != null && rain >= 64.5) {
      return _makeAlert(r, AlertSeverity.info, AlertType.rainfallHeavy, 64.5);
    }
    return null;
  }

  FloodAlert _makeAlert(
    StationReading r,
    AlertSeverity  severity,
    AlertType      type,
    double         threshold,
  ) {
    final now   = DateTime.now();
    final id    = '${r.stationName.toLowerCase().replaceAll(' ', '_')}_offline_${type.name}';
    final title = '${r.stationName}: ${type.displayName}';
    final body  = '${r.stationName} on ${r.river} at '
                  '${r.currentLevel.toStringAsFixed(2)} m '
                  '(threshold: ${threshold.toStringAsFixed(2)} m). '
                  '[OFFLINE rule-based alert]';
    final action = severity == AlertSeverity.emergency
        ? 'Evacuate immediately.'
        : severity == AlertSeverity.critical
            ? 'Issue Red Alert. Deploy rescue teams.'
            : 'Monitor closely. Alert downstream districts.';

    return FloodAlert(
      id:             id,
      type:           type,
      severity:       severity,
      title:          title,
      body:           body,
      stationName:    r.stationName,
      river:          r.river,
      district:       r.district,
      state:          r.state,
      currentLevel:   r.currentLevel,
      thresholdLevel: threshold,
      rateOfRiseMph:  r.rateOfRiseMph,
      rainfall24hMm:  r.rainfall24hMm,
      action:         action,
      issuedAt:       now,
      expiresAt:      now.add(const Duration(hours: 6)),
    );
  }
}
