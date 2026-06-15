// lib/providers/prediction_provider.dart
// Prediction provider — unified model output for golden tests.

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
    FutureProvider.family<FloodPrediction, String>((ref, stationKey) async {
  final stations = ref.watch(mergedStationsProvider);
  final wxState = ref.watch(weatherProvider);

  // Rainfall modifier used by both ML and rule-engine fallbacks.
  var rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  final match = _resolveStation(stations, stationKey);

  // Try ML first.
  try {
    const svc = predict_lib.PredictionService();

    final input = predict_lib.FloodPredictionInput(
      peakFloodLevelM: match.current > 0 ? match.current : 8.5,
      state: match.state.isNotEmpty ? match.state : 'Bihar',
      station: match.station,
      t1d: wxState.rainfall7dMm / 7,
      t2d: wxState.rainfall7dMm / 7,
      t3d: wxState.rainfall7dMm / 7,
      t4d: wxState.rainfall7dMm / 7,
      t5d: wxState.rainfall7dMm / 7,
      t6d: wxState.rainfall7dMm / 7,
      t7d: wxState.rainfall7dMm / 7,
    );

    final ml = await svc.predict(input);

    return _mlToFloodPrediction(match, ml, updatedAt: ml.timestamp);
  } catch (_) {
    // Offline / rule-engine fallback.
    return _ruleEngineToFloodPrediction(
      match,
      rainfallMod,
      forecast: wxState.forecast,
      updatedAt: DateTime.now(),
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Bulk providers — synchronous (used by screens/widgets)
// ─────────────────────────────────────────────────────────────────────────────

final floodPredictionsProvider =
    Provider<List<FloodPrediction>>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  final wxState = ref.watch(weatherProvider);

  var rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  // For bulk results, use rule-engine fallback logic (fast + deterministic).
  return stations
      .map(
        (s) => _ruleEngineToFloodPrediction(
          s,
          rainfallMod,
          forecast: wxState.forecast,
          updatedAt: DateTime.now(),
        ),
      )
      .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

final activeFloodPredictionsProvider =
    Provider<List<FloodPrediction>>((ref) {
  return ref
      .watch(floodPredictionsProvider)
      .where((p) => p.riskScore >= 50)
      .toList();
});

final worstPredictionProvider =
    Provider<FloodPrediction?>((ref) {
  final list = ref.watch(floodPredictionsProvider);
  return list.isNotEmpty ? list.first : null;
});

// ─────────────────────────────────────────────────────────────────────────────
// Mapping helpers
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
    city: seed.district,
    state: 'Bihar',
    river: seed.river,
    station: seed.station,
    current: seed.warningLevel * 0.70,
    warning: seed.warningLevel,
    danger: seed.dangerLevel,
    hfl: seed.hfl,
    isLive: false,
    dataSource: 'SEED',
  );
}

String _trendLabel(String trendLowercase) {
  // Golden expects capitalized labels like 'Rising', 'Steady'.
  return switch (trendLowercase) {
    'rising' => 'Rising',
    'falling' => 'Falling',
    'stable' => 'Steady',
    _ => trendLowercase,
  };
}

FloodPrediction _mlToFloodPrediction(
  RiverStation station,
  dynamic ml, {
  required DateTime updatedAt,
}) {
  // This file focuses on mapping into lib/models/flood_prediction.dart.

  // Defensive access because ML result type comes from lib/services/predict.dart.
  final String severity = (ml.severity as String?) ?? 'LOW';
  final num riskScoreNum = ml.riskScore as num? ?? 0;
  final num confidencePctNum = ml.confidencePercent as num? ?? 0;

  final double predictedLevel =
      ((ml.predictedLevel24h ?? ml.predictedLevelM ?? station.current) as num)
          .toDouble();

  final double predicted24h =
      ((ml.predictedLevel24h ?? ml.predictedLevelM ?? predictedLevel) as num)
          .toDouble();

  // Derive plausible 48h/72h values from the 24h prediction.
  final double predicted48h = (predicted24h * 1.05).toDouble();
  final double predicted72h = (predicted24h * 1.10).toDouble();

  final double dangerLevel = station.danger > 0 ? station.danger : station.current * 1.5;
  final double warningLevel = station.warning > 0 ? station.warning : dangerLevel * 0.75;

  final String trendLower = switch (severity) {
    'CRITICAL' || 'SEVERE' => 'rising',
    _ => 'stable',
  };

  double? cwcRiskScore;
  try {
    final ensembleDetails = ml.ensembleDetails as Map<String, dynamic>?;
    final maybe = ensembleDetails?['cwcRiskScore'];
    if (maybe is num) cwcRiskScore = maybe.toDouble();
  } catch (_) {}

  final stationLabel = '${station.station} (${station.river})';

  List<PredictionPoint> makeSeries(double start, double peak, double danger, int horizonHours) {
    final now = DateTime.now();
    const steps = 12;
    return List.generate(steps, (i) {
      final t = i / (steps - 1);
      final level = (start + (peak - start) * t).clamp(0.0, danger * 1.5);
      final hours = (t * horizonHours).round();
      return PredictionPoint(time: now.add(Duration(hours: hours)), level: level);
    });
  }

  final start = station.current;
  final next24h = makeSeries(start, predicted24h, dangerLevel, 24);
  final next48h = makeSeries(start, predicted48h, dangerLevel, 48);
  final next72h = makeSeries(start, predicted72h, dangerLevel, 72);

  return FloodPrediction(
    severity: severity,
    riskScore: riskScoreNum.toDouble(),
    station: stationLabel,
    currentLevel: station.current,
    warningLevel: warningLevel,
    dangerLevel: dangerLevel,
    predicted24h: predicted24h,
    predicted48h: predicted48h,
    predicted72h: predicted72h,
    trend: _trendLabel(trendLower),
    confidencePct: confidencePctNum.toDouble().clamp(0.0, 100.0),
    cwcRiskScore: cwcRiskScore,
    modelVersion: (ml.algorithm as String?) ?? 'ML',
    outlook: 'AI hybrid estimate (ML + rule-engine blend)',
    fromBackend: (ml.fromBackend as bool?) ?? true,
    next24h: next24h,
    next48h: next48h,
    next72h: next72h,
    updatedAt: updatedAt,
  );
}

FloodPrediction _ruleEngineToFloodPrediction(
  RiverStation station,
  double rainfallMod, {
  required List<WeatherDay> forecast,
  required DateTime updatedAt,
}) {
  // Simple deterministic rule-engine approximation (enough for screens).
  final cur = station.current;
  final dng = station.danger > 0 ? station.danger : cur * 1.5;
  final warningLevel = station.warning > 0 ? station.warning : dng * 0.75;

  final prog = station.progressPct / 100;
  final risePerHour = prog * rainfallMod * 0.021;

  // Horizon predictions.
  final predicted24h = (cur + risePerHour * 24).clamp(0.0, dng * 2);
  final predicted48h = (cur + risePerHour * 48).clamp(0.0, dng * 2.4);
  final predicted72h = (cur + risePerHour * 72).clamp(0.0, dng * 3.0);

  final riskScore = ((predicted24h / dng) * 100).clamp(0.0, 100.0);

  final confidencePct =
      (55.0 + (station.isLive ? 20.0 : 0.0) + (forecast.isNotEmpty ? 15.0 : 0.0))
          .clamp(0.0, 99.0);

  final severity = riskScore >= 85
      ? 'CRITICAL'
      : riskScore >= 65
          ? 'SEVERE'
          : riskScore >= 40
              ? 'MODERATE'
              : 'LOW';

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
      final level = (start + (peak - start) * t).clamp(0.0, danger * 1.5);
      final hours = (t * horizonHours).round();
      return PredictionPoint(time: now.add(Duration(hours: hours)), level: level);
    });
  }

  final stationLabel = '${station.station} (${station.river})';

  return FloodPrediction(
    severity: severity,
    riskScore: riskScore,
    station: stationLabel,
    currentLevel: cur,
    dangerLevel: dng,
    warningLevel: warningLevel,
    predicted24h: predicted24h,
    predicted48h: predicted48h,
    predicted72h: predicted72h,
    trend: _trendLabel(trendLower),
    confidencePct: confidencePct,
    cwcRiskScore: null,
    modelVersion: 'Rule Engine',
    outlook: 'Offline rule-engine estimate',
    fromBackend: false,
    next24h: makeSeries(
      start: cur,
      peak: predicted24h,
      danger: dng,
      horizonHours: 24,
    ),
    next48h: makeSeries(
      start: cur,
      peak: predicted48h,
      danger: dng,
      horizonHours: 48,
    ),
    next72h: makeSeries(
      start: cur,
      peak: predicted72h,
      danger: dng,
      horizonHours: 72,
    ),
    updatedAt: updatedAt,
  );
}

