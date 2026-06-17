// lib/providers/prediction_provider.dart
// Prediction provider — unified model output.
// v2.0 (17 Jun 2026):
//   - Rule-engine severity labels aligned with gaugeRiskFromLevels():
//     CRITICAL / SEVERE / WARNING / NORMAL  (was CRITICAL/SEVERE/MODERATE/LOW)
//   - peakFloodLevelM fallback uses station.current when > 0,
//     else seed from kBiharGauges (correct absolute MSL) — prevents
//     Birpur ML getting 8.5 m instead of ~74 m.
//   - progressPct now uses station.progressPct (danger-denominator fix in v2.5)
//     so ruleEngine risePerHour scales correctly.

library equinox_flood_prediction_provider;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bihar_rivers.dart';
import '../models/flood_prediction.dart';
import '../models/prediction_point.dart';
import '../models/river_station.dart';
import '../services/predict.dart' as predict_lib;

import 'real_time_river_provider.dart';
import 'weather_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// predictionProvider — FutureProvider.family
// ─────────────────────────────────────────────────────────────────────────────

final predictionProvider =
    FutureProvider.family<FloodPrediction, (String, int)>((ref, record) async {
  final stationKey   = record.$1;
  final horizonHours = record.$2;
  final stations     = ref.watch(mergedStationsProvider);
  final wxState      = ref.watch(weatherProvider);

  var rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  final match = _resolveStation(stations, stationKey);

  try {
    const svc = predict_lib.PredictionService();

    // v2.0: use station.current when live; fall back to the gauge's WL*0.70
    // so Birpur never gets the hardcoded 8.5 m placeholder.
    final seedLevel = match.current > 0
        ? match.current
        : (match.warning > 0 ? match.warning * 0.70 : match.danger * 0.55);

    final input = predict_lib.FloodPredictionInput(
      peakFloodLevelM: seedLevel,
      state:           match.state.isNotEmpty ? match.state : 'Bihar',
      station:         match.station,
      forecastHours:   horizonHours,
      t1d: wxState.rainfall7dMm * 0.25,
      t2d: wxState.rainfall7dMm * 0.20,
      t3d: wxState.rainfall7dMm * 0.18,
      t4d: wxState.rainfall7dMm * 0.15,
      t5d: wxState.rainfall7dMm * 0.10,
      t6d: wxState.rainfall7dMm * 0.07,
      t7d: wxState.rainfall7dMm * 0.05,
    );

    final ml = await svc.predict(input);
    return _mlToFloodPrediction(match, ml, updatedAt: ml.timestamp);
  } catch (_) {
    return _ruleEngineToFloodPrediction(
      match,
      rainfallMod,
      forecast:  wxState.forecast,
      updatedAt: DateTime.now(),
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Bulk providers (synchronous, used by screens/widgets)
// ─────────────────────────────────────────────────────────────────────────────

final floodPredictionsProvider = Provider<List<FloodPrediction>>((ref) {
  final stations  = ref.watch(mergedStationsProvider);
  final wxState   = ref.watch(weatherProvider);

  var rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  return stations
      .map((s) => _ruleEngineToFloodPrediction(
            s, rainfallMod,
            forecast:  wxState.forecast,
            updatedAt: DateTime.now(),
          ))
      .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

final activeFloodPredictionsProvider = Provider<List<FloodPrediction>>((ref) =>
    ref.watch(floodPredictionsProvider).where((p) => p.riskScore >= 50).toList());

final worstPredictionProvider = Provider<FloodPrediction?>((ref) {
  final list = ref.watch(floodPredictionsProvider);
  return list.isNotEmpty ? list.first : null;
});

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

RiverStation _resolveStation(List<RiverStation> stations, String stationKey) {
  final keyLower = stationKey.toLowerCase();

  if (stations.isNotEmpty) {
    final exact = stations
        .where((s) => s.station.toLowerCase() == keyLower)
        .toList();
    if (exact.isNotEmpty) return exact.first;

    final partial = stations
        .where((s) =>
            s.station.toLowerCase().contains(keyLower) ||
            keyLower.contains(s.station.toLowerCase()))
        .toList();
    if (partial.isNotEmpty) return partial.first;

    return stations.reduce((a, b) =>
        a.progressPct > b.progressPct ? a : b);
  }

  final seed = kBiharGauges.firstWhere(
    (g) => g.station.toLowerCase() == keyLower,
    orElse: () => kBiharGauges.first,
  );

  return RiverStation(
    city:    seed.district,
    state:   'Bihar',
    river:   seed.river,
    station: seed.station,
    current: seed.warningLevel * 0.70,
    warning: seed.warningLevel,
    danger:  seed.dangerLevel,
    hfl:     seed.hfl,
    isLive:  false,
    dataSource: 'SEED',
  );
}

String _trendLabel(String trendLowercase) => switch (trendLowercase) {
  'rising'  => 'Rising',
  'falling' => 'Falling',
  'stable'  => 'Steady',
  _         => trendLowercase,
};

FloodPrediction _mlToFloodPrediction(
  RiverStation station,
  dynamic ml, {
  required DateTime updatedAt,
}) {
  final String severity      = (ml.severity as String?) ?? 'LOW';
  final num riskScoreNum     = ml.riskScore as num? ?? 0;
  final num confidencePctNum = ml.confidencePercent as num? ?? 0;

  final double predictedLevel =
      ((ml.predictedLevel24h ?? ml.predictedLevelM ?? station.current) as num)
          .toDouble();
  final double predicted24h =
      ((ml.predictedLevel24h ?? ml.predictedLevelM ?? predictedLevel) as num)
          .toDouble();
  final double predicted48h = predicted24h * 1.05;
  final double predicted72h = predicted24h * 1.10;

  final double dangerLevel  = station.danger  > 0 ? station.danger  : station.current * 1.5;
  final double warningLevel = station.warning > 0 ? station.warning : dangerLevel * 0.75;

  final String trendLower = switch (severity) {
    'CRITICAL' || 'SEVERE' => 'rising',
    _ => 'stable',
  };

  double? cwcRiskScore;
  try {
    final details = ml.ensembleDetails as Map<String, dynamic>?;
    final maybe   = details?['cwcRiskScore'];
    if (maybe is num) cwcRiskScore = maybe.toDouble();
  } catch (_) {}

  List<PredictionPoint> makeSeries(double start, double peak, double danger, int h) {
    final now = DateTime.now();
    const steps = 12;
    return List.generate(steps, (i) {
      final t = i / (steps - 1);
      return PredictionPoint(
        time:  now.add(Duration(hours: (t * h).round())),
        level: (start + (peak - start) * t).clamp(0.0, danger * 1.5),
      );
    });
  }

  final s = station.current;
  return FloodPrediction(
    severity:      severity,
    riskScore:     riskScoreNum.toDouble(),
    station:       '${station.station} (${station.river})',
    currentLevel:  s,
    warningLevel:  warningLevel,
    dangerLevel:   dangerLevel,
    predicted24h:  predicted24h,
    predicted48h:  predicted48h,
    predicted72h:  predicted72h,
    trend:         _trendLabel(trendLower),
    confidencePct: confidencePctNum.toDouble().clamp(0.0, 100.0),
    cwcRiskScore:  cwcRiskScore,
    modelVersion:  (ml.algorithm as String?) ?? 'ML',
    outlook:       'AI hybrid estimate (ML + rule-engine blend)',
    fromBackend:   (ml.fromBackend as bool?) ?? true,
    next24h:       makeSeries(s, predicted24h, dangerLevel, 24),
    next48h:       makeSeries(s, predicted48h, dangerLevel, 48),
    next72h:       makeSeries(s, predicted72h, dangerLevel, 72),
    updatedAt:     updatedAt,
  );
}

FloodPrediction _ruleEngineToFloodPrediction(
  RiverStation station,
  double rainfallMod, {
  required List<WeatherDay> forecast,
  required DateTime updatedAt,
}) {
  final cur  = station.current;
  final dng  = station.danger  > 0 ? station.danger  : cur * 1.5;
  final warn = station.warning > 0 ? station.warning : dng * 0.75;

  // progressPct now uses danger denominator (v2.5 river_station fix)
  final prog = station.progressPct; // 0.0–1.5 range
  final risePerHour = prog * rainfallMod * 0.021;

  final predicted24h = (cur + risePerHour * 24).clamp(0.0, dng * 2.0);
  final predicted48h = (cur + risePerHour * 48).clamp(0.0, dng * 2.4);
  final predicted72h = (cur + risePerHour * 72).clamp(0.0, dng * 3.0);

  final riskScore    = ((predicted24h / dng) * 100).clamp(0.0, 100.0);
  final confidencePct =
      (55.0 + (station.isLive ? 20.0 : 0.0) + (forecast.isNotEmpty ? 15.0 : 0.0))
          .clamp(0.0, 99.0);

  // v2.0: severity labels aligned with gaugeRiskFromLevels() output
  final severity = riskScore >= 85
      ? 'CRITICAL'
      : riskScore >= 65
          ? 'SEVERE'
          : riskScore >= 40
              ? 'WARNING'
              : 'NORMAL';

  final trendLower = risePerHour > 0.005
      ? 'rising'
      : risePerHour < -0.005
          ? 'falling'
          : 'stable';

  List<PredictionPoint> makeSeries({
    required double start,
    required double peak,
    required double danger,
    required int horizonHours,
  }) {
    final now = DateTime.now();
    const steps = 12;
    return List.generate(steps, (i) {
      final t = i / (steps - 1);
      return PredictionPoint(
        time:  now.add(Duration(hours: (t * horizonHours).round())),
        level: (start + (peak - start) * t).clamp(0.0, danger * 1.5),
      );
    });
  }

  return FloodPrediction(
    severity:      severity,
    riskScore:     riskScore,
    station:       '${station.station} (${station.river})',
    currentLevel:  cur,
    dangerLevel:   dng,
    warningLevel:  warn,
    predicted24h:  predicted24h,
    predicted48h:  predicted48h,
    predicted72h:  predicted72h,
    trend:         _trendLabel(trendLower),
    confidencePct: confidencePct,
    cwcRiskScore:  null,
    modelVersion:  'Rule Engine v2.0',
    outlook:       'Offline rule-engine estimate',
    fromBackend:   false,
    next24h: makeSeries(start: cur, peak: predicted24h, danger: dng, horizonHours: 24),
    next48h: makeSeries(start: cur, peak: predicted48h, danger: dng, horizonHours: 48),
    next72h: makeSeries(start: cur, peak: predicted72h, danger: dng, horizonHours: 72),
    updatedAt: updatedAt,
  );
}
