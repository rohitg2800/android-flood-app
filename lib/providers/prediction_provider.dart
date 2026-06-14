// lib/providers/prediction_provider.dart
// v7.1 — analyzer-clean: all imports at top, UpperCamelCase typedefs,
//         no leading-underscore prefixes, no duplicate imports.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../data/bihar_rivers.dart';
import '../services/predict.dart' as predictLib
    show PredictionService, FloodPredictionInput, FloodPrediction;
import 'real_time_river_provider.dart';
import 'weather_provider.dart';

/// Alias: the FloodPrediction returned by predict.dart / prediction_service.dart.
/// Named differently to avoid collision with this file's FloodPrediction.
typedef MlFloodPrediction = predictLib.FloodPrediction;

// ─────────────────────────────────────────────────────────────────────────────
// PredictionPoint — single hourly forecast step
// ─────────────────────────────────────────────────────────────────────────────

class PredictionPoint {
  final DateTime time;
  final double   level;
  final double?  precipMm;

  const PredictionPoint({
    required this.time,
    required this.level,
    this.precipMm,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FloodPrediction — unified result model
//
// Screen-facing fields (predict_screen_impl reads these — unchanged):
//   station, river, currentLevel, dangerLevel, warningLevel, progressPct,
//   predicted24h/48h/72h, next24h/48h/72h, riskScore, confidencePct,
//   modelVersion, cwcRiskScore, trend, outlook
//
// NEW ML fields (AI panel, details screen, debugging):
//   severity, probabilities, algorithm, dataSource, fromBackend, timestamp
// ─────────────────────────────────────────────────────────────────────────────

class FloodPrediction {
  // ── Station identity ──────────────────────────────────────────────────────
  final String station;
  final String river;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final double progressPct;

  // ── Scalar level forecasts ────────────────────────────────────────────────
  final double predicted24h;
  final double predicted48h;
  final double predicted72h;

  // ── Hourly series ─────────────────────────────────────────────────────────
  final List<PredictionPoint> next24h;
  final List<PredictionPoint> next48h;
  final List<PredictionPoint> next72h;

  // ── Classic metadata (screen-facing) ─────────────────────────────────────
  final double  riskScore;
  final double  confidencePct;
  final String  modelVersion;
  final double? cwcRiskScore;
  final String  trend;
  final String  outlook;

  // ── ML / ensemble fields (NEW — optional with safe defaults) ─────────────
  final String              severity;
  final Map<String, double> probabilities;
  final String              algorithm;
  final String              dataSource;
  final bool                fromBackend;
  final DateTime            timestamp;

  FloodPrediction({
    required this.station,
    required this.river,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.progressPct,
    required this.predicted24h,
    required this.predicted48h,
    required this.predicted72h,
    required this.next24h,
    required this.next48h,
    required this.next72h,
    required this.riskScore,
    required this.confidencePct,
    required this.modelVersion,
    this.cwcRiskScore,
    required this.trend,
    required this.outlook,
    this.severity      = 'MODERATE',
    this.probabilities = const {},
    this.algorithm     = 'Hybrid ML',
    this.dataSource    = 'OpsFlood API',
    this.fromBackend   = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// _buildSeries — hourly PredictionPoint list from a rise rate
// ─────────────────────────────────────────────────────────────────────────────

List<PredictionPoint> _buildSeries(
  int hours,
  double cur,
  double risePerHour,
  double maxLevel,
  List<WeatherDay> forecast,
) {
  final now = DateTime.now();
  return List.generate(hours, (i) {
    final level = (cur + risePerHour * (i + 1)).clamp(0.0, maxLevel);
    double? precip;
    if (forecast.isNotEmpty) {
      final dayIdx = i ~/ 24;
      if (dayIdx < forecast.length) precip = forecast[dayIdx].rainMm / 24;
    }
    return PredictionPoint(
      time:     now.add(Duration(hours: i + 1)),
      level:    level,
      precipMm: precip,
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _levelPredict — local linear extrapolation (bulk providers only)
// ─────────────────────────────────────────────────────────────────────────────

FloodPrediction _levelPredict(
  RiverStation s,
  double rainfallModifier, {
  List<WeatherDay> forecast = const [],
}) {
  final cur  = s.current;
  final dng  = s.danger  > 0 ? s.danger  : cur * 1.5;
  final warn = s.warning > 0 ? s.warning : dng * 0.85;
  final prog = s.progressPct / 100;

  final risePerHour = prog * rainfallModifier * 0.021;
  final pts72 = _buildSeries(72, cur, risePerHour, dng * 1.5, forecast);
  final pts48 = pts72.sublist(0, 48);
  final pts24 = pts72.sublist(0, 24);

  final p24 = pts24.last.level;
  final p48 = pts48.last.level;
  final p72 = pts72.last.level;

  final riskScore = ((p24 / dng) * 100).clamp(0.0, 100.0);
  final conf = (55.0
      + (s.isLive            ? 20.0 : 0.0)
      + (forecast.isNotEmpty ? 15.0 : 0.0)
      + (rainfallModifier > 0 ? 10.0 : 0.0)).clamp(0.0, 99.0);

  final trend = risePerHour > 0.005
      ? 'rising'
      : risePerHour < -0.005
          ? 'falling'
          : 'stable';

  final outlook = p24 >= dng
      ? 'Expected to reach or exceed danger level within 24 h'
      : p48 >= dng
          ? 'May reach danger level within 48 h'
          : p72 >= dng
              ? 'Risk of reaching danger level between 48–72 h'
              : 'Likely to remain below danger level for 72 h';

  return FloodPrediction(
    station:       s.station,
    river:         s.river,
    currentLevel:  cur,
    dangerLevel:   dng,
    warningLevel:  warn,
    progressPct:   s.progressPct,
    predicted24h:  p24,
    predicted48h:  p48,
    predicted72h:  p72,
    next24h:       pts24,
    next48h:       pts48,
    next72h:       pts72,
    riskScore:     riskScore,
    confidencePct: conf,
    modelVersion:  'v3.2-linear',
    cwcRiskScore:  null,
    trend:         trend,
    outlook:       outlook,
    severity:      riskScore >= 85 ? 'CRITICAL'
                 : riskScore >= 65 ? 'SEVERE'
                 : riskScore >= 40 ? 'MODERATE'
                 : 'LOW',
    fromBackend:   false,
    algorithm:     'Linear Extrapolation',
    dataSource:    s.isLive ? 'Live Gauge' : 'Seed Data',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _resolveStation — station lookup (unchanged from v6)
// ─────────────────────────────────────────────────────────────────────────────

RiverStation _resolveStation(
    List<RiverStation> stations, String stationKey) {
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

    return stations.reduce(
        (a, b) => a.progressPct > b.progressPct ? a : b);
  }

  final seed = kBiharGauges.firstWhere(
    (g) => g.station.toLowerCase() == keyLower,
    orElse: () => kBiharGauges.first,
  );
  return RiverStation(
    city:       seed.district,
    state:      'Bihar',
    river:      seed.river,
    station:    seed.station,
    current:    seed.warningLevel * 0.70,
    warning:    seed.warningLevel,
    danger:     seed.dangerLevel,
    hfl:        seed.hfl,
    isLive:     false,
    dataSource: 'SEED',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _mlToFloodPrediction — map ML service result → provider FloodPrediction
// ─────────────────────────────────────────────────────────────────────────────

FloodPrediction _mlToFloodPrediction(
  RiverStation     station,
  MlFloodPrediction ml,
  List<WeatherDay>  forecast,
  double            rainfallMod,
) {
  final cur   = station.current;
  final dng   = station.danger  > 0 ? station.danger  : cur * 1.5;
  final warn  = station.warning > 0 ? station.warning : dng * 0.85;
  final prog  = station.progressPct / 100;
  final rise  = prog * rainfallMod * 0.021;
  final pts72 = _buildSeries(72, cur, rise, dng * 1.5, forecast);
  final pts48 = pts72.sublist(0, 48);
  final pts24 = pts72.sublist(0, 24);

  final String trend;
  if (ml.severity == 'CRITICAL' || ml.severity == 'SEVERE') {
    trend = 'rising';
  } else if (rise < -0.005) {
    trend = 'falling';
  } else {
    trend = 'stable';
  }

  final String outlook;
  switch (ml.severity) {
    case 'CRITICAL':
      outlook = 'Expected to reach or exceed danger level within 24 h';
    case 'SEVERE':
      outlook = 'May reach danger level within 48 h';
    case 'MODERATE':
      outlook = 'Risk of reaching danger level between 48–72 h';
    default:
      outlook = 'Likely to remain below danger level for 72 h';
  }

  return FloodPrediction(
    station:       station.station,
    river:         station.river,
    currentLevel:  cur,
    dangerLevel:   dng,
    warningLevel:  warn,
    progressPct:   station.progressPct,
    predicted24h:  pts24.last.level,
    predicted48h:  pts48.last.level,
    predicted72h:  pts72.last.level,
    next24h:       pts24,
    next48h:       pts48,
    next72h:       pts72,
    riskScore:     ml.riskScore.toDouble(),
    confidencePct: ml.confidencePercent.clamp(0, 99),
    modelVersion:  ml.fromBackend ? 'v2-backend-ml' : 'v2-rule-engine',
    cwcRiskScore:  ml.liveRiverLevelM,
    trend:         trend,
    outlook:       outlook,
    severity:      ml.severity,
    probabilities: ml.probabilities,
    algorithm:     ml.algorithm,
    dataSource:    ml.dataSource,
    fromBackend:   ml.fromBackend,
    timestamp:     ml.timestamp,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// predictionProvider — FutureProvider.family
// Calls real ML pipeline; falls back to linear extrapolation on any error.
// ─────────────────────────────────────────────────────────────────────────────

final predictionProvider =
    FutureProvider.family<FloodPrediction, String>((ref, stationKey) async {
  final stations = ref.watch(mergedStationsProvider);
  final wxState  = ref.watch(weatherProvider);

  double rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  final match = _resolveStation(stations, stationKey);

  try {
    const svc = predictLib.PredictionService();
    final input = predictLib.FloodPredictionInput(
      peakFloodLevelM: match.current > 0 ? match.current : 8.5,
      state:           match.state.isNotEmpty ? match.state : 'Bihar',
      station:         match.station,
      t1d: wxState.rainfall7dMm / 7,
      t2d: wxState.rainfall7dMm / 7,
      t3d: wxState.rainfall7dMm / 7,
      t4d: wxState.rainfall7dMm / 7,
      t5d: wxState.rainfall7dMm / 7,
      t6d: wxState.rainfall7dMm / 7,
      t7d: wxState.rainfall7dMm / 7,
    );
    final ml = await svc.predict(input);
    return _mlToFloodPrediction(match, ml, wxState.forecast, rainfallMod);
  } catch (_) {
    return _levelPredict(match, rainfallMod, forecast: wxState.forecast);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Bulk providers — synchronous linear extrapolation over all stations.
// ─────────────────────────────────────────────────────────────────────────────

final floodPredictionsProvider = Provider<List<FloodPrediction>>((ref) {
  final stations = ref.watch(mergedStationsProvider);
  final wxState  = ref.watch(weatherProvider);

  double rainfallMod = 0.3;
  if (wxState.current != null) {
    rainfallMod = (wxState.rainfall7dMm / 200).clamp(0.0, 1.0);
  }

  return stations
      .map((s) => _levelPredict(s, rainfallMod, forecast: wxState.forecast))
      .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
});

final activeFloodPredictionsProvider = Provider<List<FloodPrediction>>((ref) =>
    ref.watch(floodPredictionsProvider)
        .where((p) => p.progressPct >= 50)
        .toList());

final worstPredictionProvider = Provider<FloodPrediction?>((ref) {
  final list = ref.watch(floodPredictionsProvider);
  return list.isNotEmpty ? list.first : null;
});
