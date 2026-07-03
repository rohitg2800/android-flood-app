// lib/providers/bihar_prediction_provider.dart  v1.2
//
// Step 5.1 — Per-city ML prediction provider backed by biharLiveProvider.
//
// v1.1: stationId now used in second-pass fallback scan (fixes unused_local_variable).
// v1.2: BUGFIX — use static kBiharGauges thresholds when live API returns null/0
//       dangerLevel or warningLevel, instead of fabricating currentLevel*1.5.
//       Fixes Patna card (and all WRD stations) showing wrong riskScore /
//       severity / predicted24h on the dashboard Risk Forecast Strip.

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_prediction.dart';
import '../models/prediction_point.dart';
import '../providers/bihar_live_provider.dart';
import '../services/offline_cache_manager.dart';
import '../providers/weather_provider.dart';
import '../services/predict.dart' as predict_lib;
import '../providers/kosi_birpur_provider.dart';
import '../services/kosi_birpur_service.dart';
import '../data/bihar_rivers.dart'; // kBiharGauges — static CWC thresholds

// ─────────────────────────────────────────────────────────────────────────────
// _staticThreshold
//
// Looks up the canonical WL / DL from kBiharGauges for a given city/station
// name (and optionally stationId).  Returns null when no match is found so
// callers can chain their own fallback.
//
// Match priority:
//   1. city contains gauge.station  OR  gauge.station contains city  (case-insensitive)
//   2. same check against stationId tokens (e.g. "BR_GANDHIGHAT_CWC" → "gandhighat")
// ─────────────────────────────────────────────────────────────────────────────
({double warningLevel, double dangerLevel})? _staticThreshold(
  String city, {
  String stationId = '',
}) {
  final cityL = city.toLowerCase();
  for (final g in kBiharGauges) {
    final gL = g.station.toLowerCase();
    if (cityL.contains(gL) || gL.contains(cityL)) {
      return (warningLevel: g.warningLevel, dangerLevel: g.dangerLevel);
    }
  }
  // Second pass: stationId tokens
  if (stationId.isNotEmpty) {
    final idL = stationId.toLowerCase();
    for (final g in kBiharGauges) {
      final gL = g.station.toLowerCase();
      if (idL.contains(gL) || gL.contains(idL)) {
        return (warningLevel: g.warningLevel, dangerLevel: g.dangerLevel);
      }
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// biharPredictionProvider
// family key: (stationId: String, cityName: String)
// ─────────────────────────────────────────────────────────────────────────────

final biharPredictionProvider =
    FutureProvider.family<FloodPrediction, (String, String)>(
        (ref, record) async {
  final stationId = record.$1;
  final cityName = record.$2;

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

  // ── 2. Extract live values — resolve DL/WL from static gauges if API
  //       returns null/0 (fixes wrong riskScore for WRD/Patna stations) ──────
  final currentLevel = station?.currentLevel ?? 0.0;
  final riverName = station?.river ?? '';
  final diff24h = station?.diff24h ?? 0.0;
  final riskLabel = station?.riskLabel ?? 'NORMAL';

  final _static = _staticThreshold(cityName, stationId: stationId);

  final dangerLevel =
      (station?.dangerLevel != null && station!.dangerLevel! > 0)
          ? station.dangerLevel!
          : (_static?.dangerLevel ??
              (currentLevel > 0 ? currentLevel * 1.5 : 10.0));

  final warningLevel =
      (station?.warningLevel != null && station!.warningLevel! > 0)
          ? station.warningLevel!
          : (_static?.warningLevel ?? dangerLevel * 0.80);

  // ── 3. Weather rainfall modifier ─────────────────────────────────────────
  final wxState = ref.watch(weatherProvider);
  final rain7d = wxState.rainfall7dMm;
  final stationRain24h = station?.rainfall24h;
  final rainfallMod = stationRain24h != null
      ? (stationRain24h / 50).clamp(0.0, 1.0)
      : (wxState.current != null ? (rain7d / 200).clamp(0.0, 1.0) : 0.3);

  // ── 4. Try ML backend first ───────────────────────────────────────────────
  try {
    const svc = predict_lib.PredictionService();
    final input = predict_lib.FloodPredictionInput(
      peakFloodLevelM: currentLevel > 0 ? currentLevel : 8.5,
      state: station?.state ?? 'Bihar',
      station: cityName,
      forecastHours: 24,
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
      cityName: cityName,
      riverName: riverName,
      currentLevel: currentLevel,
      dangerLevel: dangerLevel,
      warningLevel: warningLevel,
    );
  } catch (_) {
    // ── 5. Rule-engine fallback using LIVE values ─────────────────────────
    return _liveRuleEngine(
      cityName: cityName,
      riverName: riverName,
      currentLevel: currentLevel,
      dangerLevel: dangerLevel,
      warningLevel: warningLevel,
      diff24h: diff24h,
      riskLabel: riskLabel,
      rainfallMod: rainfallMod,
      forecast: wxState.forecast,
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// biharBulkPredictionsProvider
// Bulk list for dashboard/home, sourced from biharLiveProvider.
// Synchronous (rule-engine only — fast, no await).
// ─────────────────────────────────────────────────────────────────────────────

final biharBulkPredictionsProvider = Provider<List<FloodPrediction>>((ref) {
  final liveAsync = ref.watch(biharLiveProvider);
  final stations = liveAsync.valueOrNull?.stations ?? [];
  final wxState = ref.watch(weatherProvider);
  // Birpur override: use kosiBirpurProvider for correct local gauge levels
  final birpur = ref.watch(kosiBirpurProvider).valueOrNull;
  final cache = OfflineCacheManager.instance;

  // ── Offline fallback: only when live feed has errored (not just loading) ──
  if (stations.isEmpty && cache.initialised && !liveAsync.isLoading) {
    final cached = cache.loadPredictions(ignoreStale: false);
    if (cached != null && cached.isNotEmpty) {
      debugPrint(
          '[BulkPreds] offline — serving ${cached.length} cached predictions');
      return cached.map(_predFromMap).toList();
    }
  }

  final preds = stations.map((s) {
    // Per-station rainfall: use actual 24h reading if available,
    // else fall back to global weather provider value.
    final stationRain = s.rainfall24h;
    final stationRainfallMod = stationRain != null
        ? (stationRain / 50).clamp(0.0, 1.0) // 50mm/day → mod=1.0
        : (wxState.current != null
            ? (wxState.rainfall7dMm / 200).clamp(0.0, 1.0)
            : 0.3);

    final isBirpur = s.city.toLowerCase().contains('birpur');

    final currentLevel = isBirpur
        ? (birpur?.levelM ?? s.currentLevel ?? kBirpurNormalLevel)
        : (s.currentLevel ?? 0.0);

    // ── v1.2: resolve DL/WL from static kBiharGauges when API returns
    //    null/0 — prevents currentLevel*1.5 fabrication for WRD stations ──
    final _static = isBirpur ? null : _staticThreshold(s.city, stationId: s.id);

    final dangerLevel = isBirpur
        ? (birpur?.dangerLevel ?? kBirpurDangerLevel)
        : ((s.dangerLevel != null && s.dangerLevel! > 0)
            ? s.dangerLevel!
            : (_static?.dangerLevel ??
                ((s.currentLevel ?? 0) * 1.5).clamp(1.0, 999.0)));

    final warningLevel = isBirpur
        ? (birpur?.warningLevel ?? kBirpurWarningLevel)
        : ((s.warningLevel != null && s.warningLevel! > 0)
            ? s.warningLevel!
            : (_static?.warningLevel ?? (dangerLevel * 0.80)));

    return _liveRuleEngine(
      cityName: s.city,
      riverName: s.river,
      currentLevel: currentLevel,
      dangerLevel: dangerLevel,
      warningLevel: warningLevel,
      diff24h: s.diff24h ?? 0.0,
      riskLabel: s.riskLabel,
      rainfallMod: stationRainfallMod,
      forecast: wxState.forecast,
      stationId: s.id,
    );
  }).toList()
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

  // ── Persist to cache whenever we have fresh data ──────────────────────────
  if (preds.isNotEmpty && cache.initialised) {
    cache.savePredictions(preds.map(_predToMap).toList());
  }

  return preds;
});

// ── Cache serialisation helpers ───────────────────────────────────────────────
Map<String, dynamic> _predToMap(FloodPrediction p) => {
      'station': p.station,
      'severity': p.severity,
      'riskScore': p.riskScore,
      'currentLevel': p.currentLevel,
      'warningLevel': p.warningLevel,
      'dangerLevel': p.dangerLevel,
      'predicted24h': p.predicted24h,
      'predicted48h': p.predicted48h,
      'predicted72h': p.predicted72h,
      'trend': p.trend,
      'confidencePct': p.confidencePct,
      'modelVersion': p.modelVersion,
      'outlook': p.outlook,
      'fromBackend': p.fromBackend,
      'updatedAt': p.updatedAt.toIso8601String(),
    };

FloodPrediction _predFromMap(Map<String, dynamic> m) {
  final t =
      DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now();
  return FloodPrediction(
    station: m['station'] as String,
    severity: m['severity'] as String,
    riskScore: (m['riskScore'] as num).toDouble(),
    currentLevel: (m['currentLevel'] as num).toDouble(),
    warningLevel: (m['warningLevel'] as num).toDouble(),
    dangerLevel: (m['dangerLevel'] as num).toDouble(),
    predicted24h: (m['predicted24h'] as num).toDouble(),
    predicted48h: (m['predicted48h'] as num).toDouble(),
    predicted72h: (m['predicted72h'] as num).toDouble(),
    trend: m['trend'] as String,
    confidencePct: (m['confidencePct'] as num).toDouble(),
    modelVersion: m['modelVersion'] as String,
    outlook: m['outlook'] as String,
    fromBackend: m['fromBackend'] as bool,
    next24h: [
      PredictionPoint(time: t, level: (m['predicted24h'] as num).toDouble())
    ],
    next48h: [
      PredictionPoint(
          time: t.add(const Duration(hours: 24)),
          level: (m['predicted48h'] as num).toDouble())
    ],
    next72h: [
      PredictionPoint(
          time: t.add(const Duration(hours: 48)),
          level: (m['predicted72h'] as num).toDouble())
    ],
    updatedAt: t,
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
  String stationId = '',
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
  final levelRatio = dng > 0 ? (cur / dng) : 0.5;
  final riskScore = ((levelRatio * 70) + (rainfallMod * 30)).clamp(0.0, 100.0);
  final severity = _severityFromRisk(riskLabel, riskScore);

  final confidencePct = (60.0 +
          (diff24h != 0 ? 15.0 : 0.0) +
          (forecast.isNotEmpty ? 10.0 : 0.0) +
          (currentLevel > 0 ? 10.0 : 0.0))
      .clamp(0.0, 99.0);

  final trendStr = risePerHour > 0.005
      ? 'Rising'
      : risePerHour < -0.005
          ? 'Falling'
          : 'Steady';

  final stationLabel =
      riverName.isNotEmpty ? '$cityName ($riverName)' : cityName;

  return FloodPrediction(
    severity: severity,
    riskScore: riskScore,
    station: stationLabel,
    currentLevel: cur,
    warningLevel: warningLevel,
    dangerLevel: dng,
    predicted24h: predicted24h,
    predicted48h: predicted48h,
    predicted72h: predicted72h,
    trend: trendStr,
    confidencePct: confidencePct,
    modelVersion: 'Live Rule Engine v1.2',
    outlook: _outlookText(severity, trendStr, predicted24h, dng),
    fromBackend: false,
    next24h: _series(cur, predicted24h, dng, 24),
    next48h: _series(cur, predicted48h, dng, 48),
    next72h: _series(cur, predicted72h, dng, 72),
    updatedAt: DateTime.now(),
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
  final String severity = (ml.severity as String?) ?? 'LOW';
  final double riskScore = ((ml.riskScore as num?) ?? 0).toDouble();
  final double confidence =
      ((ml.confidencePercent as num?) ?? 0).toDouble().clamp(0.0, 100.0);
  final double predicted24h =
      ((ml.predictedLevel24h ?? ml.predictedLevelM ?? currentLevel) as num)
          .toDouble();
  final double predicted48h = predicted24h * 1.05;
  final double predicted72h = predicted24h * 1.10;
  final double dng = dangerLevel > 0 ? dangerLevel : currentLevel * 1.5;
  final String trendStr =
      severity == 'CRITICAL' || severity == 'SEVERE' ? 'Rising' : 'Steady';
  final String stationLabel =
      riverName.isNotEmpty ? '$cityName ($riverName)' : cityName;

  return FloodPrediction(
    severity: severity,
    riskScore: riskScore,
    station: stationLabel,
    currentLevel: currentLevel,
    warningLevel: warningLevel,
    dangerLevel: dng,
    predicted24h: predicted24h,
    predicted48h: predicted48h,
    predicted72h: predicted72h,
    trend: trendStr,
    confidencePct: confidence,
    modelVersion: (ml.algorithm as String?) ?? 'ML',
    outlook: 'AI hybrid estimate (ML + rule-engine blend)',
    fromBackend: (ml.fromBackend as bool?) ?? true,
    next24h: _series(currentLevel, predicted24h, dng, 24),
    next48h: _series(currentLevel, predicted48h, dng, 48),
    next72h: _series(currentLevel, predicted72h, dng, 72),
    updatedAt: DateTime.now(),
  );
}

double _riskRiseRate(String riskLabel, double rainfallMod) {
  const base = {
    'CRITICAL': 0.030,
    'SEVERE': 0.018,
    'HIGH': 0.010,
    'MODERATE': 0.006,
    'LOW': 0.002,
    'NORMAL': 0.001,
  };
  return (base[riskLabel] ?? 0.003) * (1 + rainfallMod);
}

String _severityFromRisk(String riskLabel, double riskScore) {
  if (riskLabel == 'CRITICAL') return 'CRITICAL';
  if (riskLabel == 'SEVERE') return 'SEVERE';
  if (riskScore >= 85) return 'CRITICAL';
  if (riskScore >= 65) return 'SEVERE';
  if (riskLabel == 'HIGH' || riskLabel == 'MODERATE' || riskScore >= 40)
    return 'MODERATE';
  return 'LOW';
}

String _outlookText(
    String severity, String trend, double pred24h, double danger) {
  final pct = danger > 0 ? (pred24h / danger * 100).toStringAsFixed(0) : '–';
  return switch (severity) {
    'CRITICAL' =>
      'CRITICAL risk — level forecast at $pct% of danger threshold in 24 h. $trend trend.',
    'SEVERE' =>
      'Severe risk — level forecast at $pct% of danger threshold in 24 h. $trend trend.',
    'MODERATE' =>
      'Moderate risk — forecast $pct% of danger in 24 h. Monitor closely.',
    _ => 'Low risk — forecast $pct% of danger threshold. $trend trend.',
  };
}

List<PredictionPoint> _series(
    double start, double peak, double danger, int hours) {
  const steps = 12;
  final now = DateTime.now();
  return List.generate(steps, (i) {
    final t = i / (steps - 1);
    final level = (start + (peak - start) * t).clamp(0.0, danger * 1.5);
    return PredictionPoint(
      time: now.add(Duration(hours: (t * hours).round())),
      level: level,
    );
  });
}
