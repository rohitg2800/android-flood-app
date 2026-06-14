// lib/providers/prediction_provider.dart
// v7 — wires real ML pipeline (PredictionService) into the Riverpod graph.
//
// WHAT CHANGED FROM v6
// • predictionProvider now calls PredictionService.predict() which runs:
//     1. PipelineService pre-fill (live river level + rainfall)
//     2. POST /predict/v2 backend ML
//     3. Local Rule-Engine fallback (60/40 hybrid or 100% offline)
// • FloodPrediction extended with ML fields while keeping every field
//   that predict_screen_impl.dart reads (no screen changes required).
// • _predict() kept as a private helper used only by bulk providers
//   (floodPredictionsProvider / activeFloodPredictionsProvider) which
//   run synchronously over many stations and cannot await per-station.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../data/bihar_rivers.dart';
import '../services/predict.dart';
import 'real_time_river_provider.dart';
import 'weather_provider.dart';

export '../services/predict.dart' show PredictionService, FloodPredictionInput;

// ─────────────────────────────────────────────────────────────────────────────
// PredictionPoint — single hourly forecast step (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class PredictionPoint {
  final DateTime time;
  final double   level;    // metres
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
// Screen-facing fields (predict_screen_impl reads these):
//   station, river, currentLevel, dangerLevel, warningLevel, progressPct,
//   predicted24h/48h/72h, next24h/48h/72h, riskScore, confidencePct,
//   modelVersion, cwcRiskScore, trend, outlook
//
// NEW ML fields (for AI panel, details screen, debugging):
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
  final double  riskScore;      // 0–100
  final double  confidencePct;  // 0–99
  final String  modelVersion;
  final double? cwcRiskScore;
  final String  trend;          // 'rising' | 'stable' | 'falling'
  final String  outlook;

  // ── ML / ensemble fields (NEW) ────────────────────────────────────────────
  final String              severity;      // LOW | MODERATE | SEVERE | CRITICAL
  final Map<String, double> probabilities; // {LOW:%, MODERATE:%, ...}
  final String              algorithm;     // e.g. 'Hybrid (Backend ML 60% + Rule Engine 40%)'
  final String              dataSource;    // e.g. 'CWC Live + OpsFlood API + Rule Engine'
  final bool                fromBackend;
  final DateTime            timestamp;

  const FloodPrediction({
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
  }) : timestamp = timestamp ?? const _FakeDateTimeNow();
}

// Dart const workaround: DateTime.now() is not const.
// We store a sentinel and expose a real getter.
class _FakeDateTimeNow implements DateTime {
  const _FakeDateTimeNow();
  // Delegate every member to DateTime.now() at call time.
  @override dynamic noSuchMethod(Invocation i) => DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// _buildSeries — generate hourly PredictionPoint list from a rise rate
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
    final level    = (cur + risePerHour * (i + 1)).clamp(0.0, maxLevel);
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
// _levelPredict — local linear extrapolation (used by bulk providers only)
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
    station:      s.station,
    river:        s.river,
    currentLevel: cur,
    dangerLevel:  dng,
    warningLevel: warn,
    progressPct:  s.progressPct,
    predicted24h: p24,
    predicted48h: p48,
    predicted72h: p72,
    next24h:      pts24,
    next48h:      pts48,
    next72h:      pts72,
    riskScore:    riskScore,
    confidencePct: conf,
    modelVersion: 'v3.2-linear',
    cwcRiskScore: null,
    trend:        trend,
    outlook:      outlook,
    severity:     riskScore >= 85 ? 'CRITICAL'
                : riskScore >= 65 ? 'SEVERE'
                : riskScore >= 40 ? 'MODERATE'
                : 'LOW',
    fromBackend:  false,
    algorithm:    'Linear Extrapolation',
    dataSource:   s.isLive ? 'Live Gauge' : 'Seed Data',
    timestamp:    DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _resolveStation — station lookup logic (unchanged from v6)
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

  // No live data — seed from static gauge list.
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
// _mlToFloodPrediction — map PredictionService result → FloodPrediction
//
// The ML service returns severity/probabilities/riskScore.  We layer those
// on top of the level-series fields (still computed locally from the live
// gauge reading) so predict_screen_impl sees all the fields it needs.
// ─────────────────────────────────────────────────────────────────────────────

FloodPrediction _mlToFloodPrediction(
  RiverStation      station,
  services_FloodPrediction ml,
  List<WeatherDay>  forecast,
  double            rainfallMod,
) {
  // Build level series from live gauge (ML doesn't return hourly levels).
  final cur     = station.current;
  final dng     = station.danger  > 0 ? station.danger  : cur * 1.5;
  final warn    = station.warning > 0 ? station.warning : dng * 0.85;
  final prog    = station.progressPct / 100;
  final rise    = prog * rainfallMod * 0.021;
  final pts72   = _buildSeries(72, cur, rise, dng * 1.5, forecast);
  final pts48   = pts72.sublist(0, 48);
  final pts24   = pts72.sublist(0, 24);

  // Derive trend from ML severity + live level trend.
  final String trend;
  if (ml.severity == 'CRITICAL' || ml.severity == 'SEVERE') {
    trend = 'rising';
  } else if (rise < -0.005) {
    trend = 'falling';
  } else {
    trend = 'stable';
  }

  // Derive outlook from ML severity.
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
    station:      station.station,
    river:        station.river,
    currentLevel: cur,
    dangerLevel:  dng,
    warningLevel: warn,
    progressPct:  station.progressPct,
    predicted24h: pts24.last.level,
    predicted48h: pts48.last.level,
    predicted72h: pts72.last.level,
    next24h:      pts24,
    next48h:      pts48,
    next72h:      pts72,
    riskScore:    ml.riskScore.toDouble(),
    confidencePct: ml.confidencePercent.clamp(0, 99),
    modelVersion:  ml.fromBackend ? 'v2-backend-ml' : 'v2-rule-engine',
    cwcRiskScore:  ml.liveRiverLevelM,
    trend:         trend,
    outlook:       outlook,
    // ML fields
    severity:      ml.severity,
    probabilities: ml.probabilities,
    algorithm:     ml.algorithm,
    dataSource:    ml.dataSource,
    fromBackend:   ml.fromBackend,
    timestamp:     ml.timestamp,
  );
}

// Alias to avoid name collision with this file's FloodPrediction.
typedef services_FloodPrediction = predict_FloodPrediction;

// ignore: library_prefixes
import 'package:flutter_riverpod/flutter_riverpod.dart' as _rv;
// Import predict.dart under an alias to access its FloodPrediction.
import '../services/predict.dart' as _predict_lib
    show PredictionService, FloodPredictionInput, FloodPrediction;
typedef predict_FloodPrediction = _predict_lib.FloodPrediction;

// ─────────────────────────────────────────────────────────────────────────────
// predictionProvider(String stationKey) — FutureProvider.family
//
// Now calls the real ML pipeline.  Falls back gracefully to linear
// extrapolation if the pipeline or backend throws.
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

  // ── Try ML pipeline ───────────────────────────────────────────────────────
  try {
    final svc   = const _predict_lib.PredictionService();
    final input = _predict_lib.FloodPredictionInput(
      peakFloodLevelM:   match.current > 0 ? match.current : 8.5,
      state:             match.state.isNotEmpty ? match.state : 'Bihar',
      station:           match.station,
      // Rainfall: distribute 7d total across daily buckets.
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
    // Offline or backend unavailable — fall back to linear extrapolation.
    return _levelPredict(match, rainfallMod, forecast: wxState.forecast);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Bulk providers — synchronous, use linear extrapolation over all stations.
// Cannot await per-station ML calls; ML is only for single-station screen.
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
