// lib/providers/bihar_prediction_provider.dart  v1.1
//
// Step 5.1 — Per-city ML prediction provider backed by biharLiveProvider.
//
// v1.1: stationId now used in second-pass fallback scan (fixes unused_local_variable).

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_prediction.dart';
import '../models/prediction_point.dart';
import '../providers/bihar_live_provider.dart';
import '../services/offline_cache_manager.dart';
import '../providers/weather_provider.dart';
import '../services/predict.dart' as predict_lib;

// ─────────────────────────────────────────────────────────────────────────────
// biharPredictionProvider
// family key: (stationId: String, cityName: String)
// ─────────────────────────────────────────────────────────────────────────────

final biharPredictionProvider =
    FutureProvider.family<FloodPrediction, (String, String)>(
        (ref, record) async {
  final stationId = record.$1;
  final cityName  = record.$2;

  // ── 1. Get live station data ──────────────────────────────────────────────
  final liveAsync = ref.watch(biharLiveProvider);
  final liveState = liveAsync.valueOrNull;

  BiharStationData? station;
  if (liveState != null) {
    // Pass 1: normalised city name lookup (O(1))
    station = liveState.byCity(cityName);

    // Pass 2: fuzzy city-name scan
    if (station == null) {
      for (final s in liveState.stations) {
        if (s.city.toLowerCase().contains(cityName.toLowerCase()) ||
            cityName.toLowerCase().contains(s.city.toLowerCase())) {
          station = s;
          break;
        }
      }
    }

    // Pass 3: stationId prefix scan (e.g. "BR_BIRPUR_CWC" → match "birpur")
    if (station == null && stationId.isNotEmpty) {
      final idLower = stationId.toLowerCase();
      for (final s in liveState.stations) {
        if (idLower.contains(s.city.toLowerCase()) ||
            s.city.toLowerCase().contains(idLower)) {
          station = s;
          break;
        }
      }
    }
  }

  // ── 2. Extract live values (with safe defaults) ───────────────────────────
  final currentLevel = station?.currentLevel ?? 0.0;
  final dangerLevel  = station?.dangerLevel  ?? (currentLevel > 0 ? currentLevel * 1.5 : 10.0);
  final warningLevel = station?.warningLevel ?? dangerLevel * 0.75;
  final diff24h      = station?.diff24h      ?? 0.0;
  final riskLabel    = station?.riskLabel    ?? 'NORMAL';
  final riverName    = station?.river        ?? '';

  // ── 3. Weather rainfall modifier ─────────────────────────────────────────
  final wxState     = ref.watch(weatherProvider);
  final rainfallMod = wxState.current != null
      ? (wxState.rainfall7dMm / 200).clamp(0.0, 1.0)
      : 0.3;
  final rain7d      = wxState.rainfall7dMm;

  // ── 4. Try ML backend first ───────────────────────────────────────────────
  try {
    const svc = predict_lib.PredictionService();
    final input = predict_lib.FloodPredictionInput(
      peakFloodLevelM: currentLevel > 0 ? currentLevel : 8.5,
      state:           station?.state ?? 'Bihar',
      station:         cityName,
      forecastHours:   24,
      t1d: rain7d * 0.25,
      t2d: rain7d * 0.20,
      t3d: rain7d * 0.18,
      t4d: rain7d * 0.15,
      t5d: rain7d * 0.10,
      t6d: rain7d * 0.07,
      t7d: rain7d * 0.05,
    );
    final ml = await svc.predict(input);
    return _mlToFloodPrediction(
      ml,
      cityName:     cityName,
      riverName:    riverName,
      currentLevel: currentLevel,
      dangerLevel:  dangerLevel,
      warningLevel: warningLevel,
    );
  } catch (_) {
    // ── 5. Rule-engine fallback using LIVE values ─────────────────────────
    return _liveRuleEngine(
      cityName:     cityName,
      riverName:    riverName,
      currentLevel: currentLevel,
      dangerLevel:  dangerLevel,
      warningLevel: warningLevel,
      diff24h:      diff24h,
      riskLabel:    riskLabel,
      rainfallMod:  rainfallMod,
      forecast:     wxState.forecast,
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// biharBulkPredictionsProvider
// Bulk list for dashboard/home, sourced from biharLiveProvider.
// Synchronous (rule-engine only — fast, no await).
// ─────────────────────────────────────────────────────────────────────────────

final biharBulkPredictionsProvider =
    Provider<List<FloodPrediction>>((ref) {
  final liveAsync   = ref.watch(biharLiveProvider);
  final stations    = liveAsync.valueOrNull?.stations ?? [];
  final wxState     = ref.watch(weatherProvider);
  final rainfallMod = wxState.current != null
      ? (wxState.rainfall7dMm / 200).clamp(0.0, 1.0)
      : 0.3;
  final cache       = OfflineCacheManager.instance;

  // ── Offline fallback: return cached data when live feed is empty ──────────
  if (stations.isEmpty && cache.initialised) {
    final cached = cache.loadPredictions(ignoreStale: true);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('[BulkPreds] offline — serving ${cached.length} cached predictions');
      return cached.map(_predFromMap).toList();
    }
  }

  final preds = stations
      .map((s) => _liveRuleEngine(
            cityName:     s.city,
            riverName:    s.river,
            currentLevel: s.currentLevel ?? 0.0,
            dangerLevel:  s.dangerLevel  ?? ((s.currentLevel ?? 0) * 1.5).clamp(1.0, 999.0),
            warningLevel: s.warningLevel ?? ((s.dangerLevel  ?? 10.0) * 0.75),
            diff24h:      s.diff24h      ?? 0.0,
            riskLabel:    s.riskLabel,
            rainfallMod:  rainfallMod,
            forecast:     wxState.forecast,
          ))
      .toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

  // ── Persist to cache whenever we have fresh data ──────────────────────────
  if (preds.isNotEmpty && cache.initialised) {
    cache.savePredictions(preds.map(_predToMap).toList());
  }

  return preds;
});

// ── Cache serialisation helpers ───────────────────────────────────────────────
Map<String, dynamic> _predToMap(FloodPrediction p) => {
  'station':       p.station,
  'severity':      p.severity,
  'riskScore':     p.riskScore,
  'currentLevel':  p.currentLevel,
  'warningLevel':  p.warningLevel,
  'dangerLevel':   p.dangerLevel,
  'predicted24h':  p.predicted24h,
  'predicted48h':  p.predicted48h,
  'predicted72h':  p.predicted72h,
  'trend':         p.trend,
  'confidencePct': p.confidencePct,
  'modelVersion':  p.modelVersion,
  'outlook':       p.outlook,
  'fromBackend':   p.fromBackend,
  'updatedAt':     p.updatedAt.toIso8601String(),
};

FloodPrediction _predFromMap(Map<String, dynamic> m) {
  final t = DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now();
  return FloodPrediction(
    station:       m['station']       as String,
    severity:      m['severity']      as String,
    riskScore:     (m['riskScore']    as num).toDouble(),
    currentLevel:  (m['currentLevel'] as num).toDouble(),
    warningLevel:  (m['warningLevel'] as num).toDouble(),
    dangerLevel:   (m['dangerLevel']  as num).toDouble(),
    predicted24h:  (m['predicted24h'] as num).toDouble(),
    predicted48h:  (m['predicted48h'] as num).toDouble(),
    predicted72h:  (m['predicted72h'] as num).toDouble(),
    trend:         m['trend']         as String,
    confidencePct: (m['confidencePct'] as num).toDouble(),
    modelVersion:  m['modelVersion']  as String,
    outlook:       m['outlook']       as String,
    fromBackend:   m['fromBackend']   as bool,
    next24h:       [PredictionPoint(time: t, level: (m['predicted24h'] as num).toDouble())],
    next48h:       [PredictionPoint(time: t.add(const Duration(hours: 24)), level: (m['predicted48h'] as num).toDouble())],
    next72h:       [PredictionPoint(time: t.add(const Duration(hours: 48)), level: (m['predicted72h'] as num).toDouble())],
    updatedAt:     t,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

FloodPrediction _liveRuleEngine({
  required String cityName,
  required String riverName,
  required double currentLevel,
  required double dangerLevel,
  required double warningLevel,
  required double diff24h,
  required String riskLabel,
  required double rainfallMod,
  required List<WeatherDay> forecast,
}) {
  final dng = dangerLevel > 0 ? dangerLevel : currentLevel * 1.5;
  final cur = currentLevel;

  // Use actual 24h diff if available, else estimate from risk + rainfall.
  final double risePerHour = diff24h != 0
      ? (diff24h / 24).clamp(-0.5, 0.5)
      : _riskRiseRate(riskLabel, rainfallMod);

  final predicted24h = (cur + risePerHour * 24).clamp(0.0, dng * 2.0);
  final predicted48h = (cur + risePerHour * 48).clamp(0.0, dng * 2.4);
  final predicted72h = (cur + risePerHour * 72).clamp(0.0, dng * 3.0);

  // Risk score: live level ratio 70% + rainfall 30%
  final levelRatio  = dng > 0 ? (cur / dng) : 0.5;
  final riskScore   = ((levelRatio * 70) + (rainfallMod * 30)).clamp(0.0, 100.0);
  final severity    = _severityFromRisk(riskLabel, riskScore);

  final confidencePct = (60.0
    + (diff24h != 0        ? 15.0 : 0.0)
    + (forecast.isNotEmpty ? 10.0 : 0.0)
    + (currentLevel > 0    ? 10.0 : 0.0)
  ).clamp(0.0, 99.0);

  final trendStr = risePerHour > 0.005
      ? 'Rising'
      : risePerHour < -0.005
          ? 'Falling'
          : 'Steady';

  final stationLabel = riverName.isNotEmpty ? '$cityName ($riverName)' : cityName;

  return FloodPrediction(
    severity:      severity,
    riskScore:     riskScore,
    station:       stationLabel,
    currentLevel:  cur,
    warningLevel:  warningLevel,
    dangerLevel:   dng,
    predicted24h:  predicted24h,
    predicted48h:  predicted48h,
    predicted72h:  predicted72h,
    trend:         trendStr,
    confidencePct: confidencePct,
    modelVersion:  'Live Rule Engine v1',
    outlook:       _outlookText(severity, trendStr, predicted24h, dng),
    fromBackend:   false,
    next24h:       _series(cur, predicted24h, dng, 24),
    next48h:       _series(cur, predicted48h, dng, 48),
    next72h:       _series(cur, predicted72h, dng, 72),
    updatedAt:     DateTime.now(),
  );
}

FloodPrediction _mlToFloodPrediction(
  dynamic ml, {
  required String cityName,
  required String riverName,
  required double currentLevel,
  required double dangerLevel,
  required double warningLevel,
}) {
  final String severity     = (ml.severity as String?) ?? 'LOW';
  final double riskScore    = ((ml.riskScore as num?) ?? 0).toDouble();
  final double confidence   = ((ml.confidencePercent as num?) ?? 0).toDouble().clamp(0.0, 100.0);
  final double predicted24h = ((ml.predictedLevel24h ?? ml.predictedLevelM ?? currentLevel) as num).toDouble();
  final double predicted48h = predicted24h * 1.05;
  final double predicted72h = predicted24h * 1.10;
  final double dng          = dangerLevel > 0 ? dangerLevel : currentLevel * 1.5;
  final String trendStr     = severity == 'CRITICAL' || severity == 'SEVERE' ? 'Rising' : 'Steady';
  final String stationLabel = riverName.isNotEmpty ? '$cityName ($riverName)' : cityName;

  return FloodPrediction(
    severity:      severity,
    riskScore:     riskScore,
    station:       stationLabel,
    currentLevel:  currentLevel,
    warningLevel:  warningLevel,
    dangerLevel:   dng,
    predicted24h:  predicted24h,
    predicted48h:  predicted48h,
    predicted72h:  predicted72h,
    trend:         trendStr,
    confidencePct: confidence,
    modelVersion:  (ml.algorithm as String?) ?? 'ML',
    outlook:       'AI hybrid estimate (ML + rule-engine blend)',
    fromBackend:   (ml.fromBackend as bool?) ?? true,
    next24h:       _series(currentLevel, predicted24h, dng, 24),
    next48h:       _series(currentLevel, predicted48h, dng, 48),
    next72h:       _series(currentLevel, predicted72h, dng, 72),
    updatedAt:     DateTime.now(),
  );
}

double _riskRiseRate(String riskLabel, double rainfallMod) {
  const base = {
    'CRITICAL': 0.030,
    'SEVERE':   0.018,
    'HIGH':     0.010,
    'MODERATE': 0.006,
    'LOW':      0.002,
    'NORMAL':   0.001,
  };
  return (base[riskLabel] ?? 0.003) * (1 + rainfallMod);
}

String _severityFromRisk(String riskLabel, double riskScore) {
  if (riskLabel == 'CRITICAL') return 'CRITICAL';
  if (riskLabel == 'SEVERE')   return 'SEVERE';
  if (riskScore >= 85)         return 'CRITICAL';
  if (riskScore >= 65)         return 'SEVERE';
  if (riskLabel == 'HIGH' || riskLabel == 'MODERATE' || riskScore >= 40)
    return 'MODERATE';
  return 'LOW';
}

String _outlookText(String severity, String trend, double pred24h, double danger) {
  final pct = danger > 0 ? (pred24h / danger * 100).toStringAsFixed(0) : '–';
  return switch (severity) {
    'CRITICAL' => 'CRITICAL risk — level forecast at $pct% of danger threshold in 24 h. $trend trend.',
    'SEVERE'   => 'Severe risk — level forecast at $pct% of danger threshold in 24 h. $trend trend.',
    'MODERATE' => 'Moderate risk — forecast $pct% of danger in 24 h. Monitor closely.',
    _          => 'Low risk — forecast $pct% of danger threshold. $trend trend.',
  };
}

List<PredictionPoint> _series(double start, double peak, double danger, int hours) {
  const steps = 12;
  final now = DateTime.now();
  return List.generate(steps, (i) {
    final t     = i / (steps - 1);
    final level = (start + (peak - start) * t).clamp(0.0, danger * 1.5);
    return PredictionPoint(
      time:  now.add(Duration(hours: (t * hours).round())),
      level: level,
    );
  });
}
