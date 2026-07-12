// lib/services/alert_evaluator.dart
//
// OpsFlood — AlertEvaluator
//
// Pure stateless logic that maps a (city, currentValue, previousValue?) tuple
// into a ThresholdAlert. No IO. Fully unit-testable.
library;

import '../data/india_cities.dart';
import '../data/bihar_rivers.dart';
import '../models/threshold_alert.dart';

class AlertEvaluator {
  AlertEvaluator._();

  // ─── Evaluate from IndiaCity (gauge height, m MSL) ───────────────────────
  static ThresholdAlert? fromCity({
    required IndiaCity city,
    required double currentValue,
    double? previousValue,
    bool isDischarge = false,
  }) {
    if (city.dangerLevel <= 0 && city.warningLevel <= 0) return null;
    return _build(
      cityId: city.id,
      cityName: city.name,
      state: city.state,
      river: city.river,
      currentValue: currentValue,
      warningLevel: city.warningLevel,
      dangerLevel: city.dangerLevel,
      hfl: city.hfl,
      previousValue: previousValue,
      isDischarge: isDischarge,
    );
  }

  // ─── Evaluate from BiharGauge (gauge height, m MSL) ──────────────────────
  static ThresholdAlert? fromBiharGauge({
    required BiharGauge gauge,
    required double currentValue,
    double? previousValue,
  }) {
    return _build(
      cityId:
          '${gauge.river.toLowerCase().replaceAll(' ', '_')}_${gauge.station.toLowerCase().replaceAll(' ', '_')}',
      cityName: gauge.station,
      state: 'Bihar',
      river: gauge.river,
      currentValue: currentValue,
      warningLevel: gauge.warningLevel,
      dangerLevel: gauge.dangerLevel,
      hfl: gauge.hfl,
      previousValue: previousValue,
      isDischarge: false,
    );
  }

  // ─── Evaluate raw discharge (m³/s) with explicit thresholds ─────────────
  static ThresholdAlert? fromDischarge({
    required String cityId,
    required String cityName,
    required String state,
    required String river,
    required double dischargeM3s,
    required double warningDischarge,
    required double dangerDischarge,
    required double hflDischarge,
    double? previousDischarge,
  }) {
    return _build(
      cityId: cityId,
      cityName: cityName,
      state: state,
      river: river,
      currentValue: dischargeM3s,
      warningLevel: warningDischarge,
      dangerLevel: dangerDischarge,
      hfl: hflDischarge,
      previousValue: previousDischarge,
      isDischarge: true,
    );
  }

  // ─── Core build logic ────────────────────────────────────────────────────
  static ThresholdAlert? _build({
    required String cityId,
    required String cityName,
    required String state,
    required String river,
    required double currentValue,
    required double warningLevel,
    required double dangerLevel,
    required double hfl,
    double? previousValue,
    bool isDischarge = false,
  }) {
    final level = _classify(
      current: currentValue,
      warning: warningLevel,
      danger: dangerLevel,
      hfl: hfl,
    );

    // "watch" threshold: within 20% of the gap below warning level
    final warnGap = (dangerLevel - warningLevel).abs();
    final watchEdge = warningLevel - (warnGap * 0.20);
    if (currentValue < watchEdge && level == AlertLevel.normal) return null;

    final breachRef = _breachReference(level, warningLevel, dangerLevel, hfl);
    final breachMargin = currentValue - breachRef;
    final gapWD = (dangerLevel - warningLevel).abs();
    final fillPercent = gapWD > 0
        ? ((currentValue - warningLevel) / gapWD * 100).clamp(0.0, 150.0)
        : 0.0;

    final trend = _trend(currentValue, previousValue);
    final ts = DateTime.now();
    final id = '${cityId}_${level.name}_${ts.millisecondsSinceEpoch}';

    return ThresholdAlert(
      id: id,
      cityId: cityId,
      cityName: cityName,
      state: state,
      river: river,
      level: level,
      currentValue: currentValue,
      warningLevel: warningLevel,
      dangerLevel: dangerLevel,
      hfl: hfl,
      breachMargin: breachMargin,
      fillPercent: fillPercent,
      timestamp: ts,
      isDischarge: isDischarge,
      previousValue: previousValue,
      trend: trend,
    );
  }

  static AlertLevel _classify({
    required double current,
    required double warning,
    required double danger,
    required double hfl,
  }) {
    if (hfl > 0 && current >= hfl) return AlertLevel.extreme;
    if (current >= danger) return AlertLevel.danger;
    if (current >= warning) return AlertLevel.warning;
    final gap = (danger - warning).abs();
    if (current >= warning - gap * 0.20) return AlertLevel.watch;
    return AlertLevel.normal;
  }

  static double _breachReference(
      AlertLevel level, double wl, double dl, double hfl) {
    return switch (level) {
      AlertLevel.extreme => hfl,
      AlertLevel.danger => dl,
      AlertLevel.warning => wl,
      AlertLevel.watch => wl,
      AlertLevel.normal => wl,
    };
  }

  static TrendDirection _trend(double current, double? previous) {
    if (previous == null) return TrendDirection.steady;
    final delta = current - previous;
    if (delta > 0.02) return TrendDirection.rising;
    if (delta < -0.02) return TrendDirection.falling;
    return TrendDirection.steady;
  }
}
