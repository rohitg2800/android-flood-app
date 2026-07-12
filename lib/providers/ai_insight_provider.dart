// lib/providers/ai_insight_provider.dart
// OpsFlood — AiInsight provider v4
//
// This file owns:
//   • DataSourceHealth   enum  (live / offline)
//   • RiverTrend         model (per-river velocity + danger%)
//   • AiInsight          model (ALL fields consumed by ai_prediction_screen)
//   • AiInsightNotifier  (builds AiInsight from merged providers)
//   • aiInsightProvider  (AsyncNotifierProvider<AiInsight>)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/kosi_birpur_provider.dart';
import '../services/kosi_birpur_service.dart';

// ────────────────────────────────────────────────────────────────────────────────
// DataSourceHealth
// ────────────────────────────────────────────────────────────────────────────────

enum DataSourceHealth { live, offline }

// ────────────────────────────────────────────────────────────────────────────────
// RiverTrend — velocity + danger% per river/station pair
// ────────────────────────────────────────────────────────────────────────────────

class RiverTrend {
  final String river;
  final String station;
  final double velocityMperHr; // positive = rising, negative = falling
  final double dangerPct; // currentLevel / dangerLevel * 100

  const RiverTrend({
    required this.river,
    required this.station,
    required this.velocityMperHr,
    required this.dangerPct,
  });
}

// ────────────────────────────────────────────────────────────────────────────────
// AiInsight — rich model matching every field used by AiPredictionScreen
// ────────────────────────────────────────────────────────────────────────────────

class AiInsight {
  // ── Identity / status ────────────────────────────────────────────────────
  final String
      overallRisk; // 'LOW' | 'MODERATE' | 'HIGH' | 'EXTREME' | 'LOADING'
  final double confidence; // 0–100
  final int stationCount;
  final int criticalCount; // stations at/above dangerLevel
  final int severeCount; // stations above warningLevel but below dangerLevel
  final int alertCount; // criticalCount + severeCount
  final double dangerPercent; // criticalCount / stationCount * 100
  final DateTime lastFetched;

  // ── Source health ────────────────────────────────────────────────────────
  final Map<String, DataSourceHealth> sources;

  // ── Kosi @ Birpur ────────────────────────────────────────────────────────
  final double kosiLevel; // metres AMSL (0 = unavailable)
  final double kosiDanger; // 214.00 AMSL

  // ── River trends ──────────────────────────────────────────────────────────
  final List<RiverTrend> riverTrends;

  // ── Station list (FloodData objects for StationRiskRow) ──────────────────
  final List<FloodData> stations;

  // ── Weather / rainfall drivers ────────────────────────────────────────────
  final double tempC;
  final double humidity;
  final double rainfallNow; // current-hour precipitation mm
  final double rainfall7dMm;
  final double rainfallIndex;

  // ── Forecast ──────────────────────────────────────────────────────────────
  final List<WeatherDay> forecast;
  final double forecastRainTotal;

  // ── ML model metadata ─────────────────────────────────────────────────────
  final String modelVersion;
  final double mlConfidence;
  final bool mlBackendLive;

  // ── Legacy / compat ─────────────────────────────────────────────────────────
  /// Kept so any old call site that used the v3 fields still compiles.
  String get summary => overallRisk;
  String get riskLevel => overallRisk;
  String get actionAdvice => _actionFor(overallRisk);
  String get sourceSummary => sources.entries
      .map((e) => '${e.key} ${e.value == DataSourceHealth.live ? "✓" : "✗"}')
      .join('  ');

  const AiInsight({
    required this.overallRisk,
    required this.confidence,
    required this.stationCount,
    required this.criticalCount,
    required this.severeCount,
    required this.alertCount,
    required this.dangerPercent,
    required this.lastFetched,
    required this.sources,
    required this.kosiLevel,
    required this.kosiDanger,
    required this.riverTrends,
    required this.stations,
    required this.tempC,
    required this.humidity,
    required this.rainfallNow,
    required this.rainfall7dMm,
    required this.rainfallIndex,
    required this.forecast,
    required this.forecastRainTotal,
    required this.modelVersion,
    required this.mlConfidence,
    required this.mlBackendLive,
  });

  /// Loading / error placeholder — never null.
  factory AiInsight.empty() => AiInsight(
        overallRisk: 'LOADING',
        confidence: 0,
        stationCount: 0,
        criticalCount: 0,
        severeCount: 0,
        alertCount: 0,
        dangerPercent: 0,
        lastFetched: DateTime.now(),
        sources: const {
          'CWC': DataSourceHealth.offline,
          'WRD': DataSourceHealth.offline,
          'IMD': DataSourceHealth.offline,
          'KOSI': DataSourceHealth.offline,
        },
        kosiLevel: 0,
        kosiDanger: kBirpurDangerLevel,
        riverTrends: const [],
        stations: const [],
        tempC: 0,
        humidity: 0,
        rainfallNow: 0,
        rainfall7dMm: 0,
        rainfallIndex: 0,
        forecast: const [],
        forecastRainTotal: 0,
        modelVersion: '–',
        mlConfidence: 0,
        mlBackendLive: false,
      );

  static String _actionFor(String risk) {
    switch (risk.toUpperCase()) {
      case 'EXTREME':
        return 'Evacuate low-lying areas immediately.';
      case 'HIGH':
        return 'Prepare evacuation kits. Monitor CWC alerts.';
      case 'MODERATE':
        return 'Stay alert. Avoid riverbanks.';
      default:
        return 'Conditions normal. Routine monitoring.';
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// AiInsightNotifier
// ────────────────────────────────────────────────────────────────────────────────

class AiInsightNotifier extends AsyncNotifier<AiInsight> {
  @override
  Future<AiInsight> build() async {
    final stations = ref.watch(mergedStationsProvider);
    final weather = ref.watch(weatherProvider);
    final kosiAsync = ref.watch(kosiBirpurProvider);

    if (stations.isEmpty) return AiInsight.empty();

    // ── Station KPIs ───────────────────────────────────────────────────────────
    int critical = 0, severe = 0;
    for (final s in stations) {
      if (s.dangerClass == DangerClass.extreme ||
          s.dangerClass == DangerClass.severe) {
        critical++;
      } else if (s.dangerClass == DangerClass.aboveNormal) {
        severe++;
      }
    }
    final total = stations.length;
    final alerts = critical + severe;

    // ── Overall risk ────────────────────────────────────────────────────────────
    final String overallRisk;
    if (critical >= 5 || (critical > 0 && critical / total > 0.15)) {
      overallRisk = 'EXTREME';
    } else if (critical > 0 || severe >= 5) {
      overallRisk = 'HIGH';
    } else if (severe > 0 || alerts > 0) {
      overallRisk = 'MODERATE';
    } else {
      overallRisk = 'LOW';
    }

    // ── Confidence (heuristic based on data completeness) ─────────────────────
    final hasCwc = stations.any((s) => s.dataSource?.contains('CWC') ?? false);
    final hasWrd = stations.any((s) => s.dataSource?.contains('WRD') ?? false);
    final hasWeather = weather.status == WeatherStatus.loaded;
    final kosiOk = kosiAsync.asData?.value?.source != 'SEED';
    double conf = 55;
    if (hasCwc) conf += 15;
    if (hasWrd) conf += 10;
    if (hasWeather) conf += 15;
    if (kosiOk) conf += 5;
    conf = conf.clamp(0, 99);

    // ── FloodData list for station rows ─────────────────────────────────────────
    final floodList = stations.map(_toFloodData).toList();

    // ── River trends ────────────────────────────────────────────────────────────
    final riverMap = <String, List<RiverStation>>{};
    for (final s in stations) {
      riverMap.putIfAbsent(s.river, () => []).add(s);
    }
    final trends = <RiverTrend>[];
    for (final entry in riverMap.entries) {
      if (trends.length >= 6) break;
      final list = entry.value;
      final maxStn =
          list.reduce((a, b) => a.progressPct > b.progressPct ? a : b);
      final dangerPct = maxStn.danger > 0
          ? (maxStn.current / maxStn.danger * 100).clamp(0.0, 120.0)
          : maxStn.progressPct;
      final vel = dangerPct > 70
          ? 0.08
          : dangerPct > 50
              ? 0.02
              : -0.01;
      trends.add(RiverTrend(
        river: entry.key,
        station: maxStn.station,
        velocityMperHr: vel,
        dangerPct: dangerPct,
      ));
    }
    trends.sort((a, b) => b.dangerPct.compareTo(a.dangerPct));

    // ── Kosi ────────────────────────────────────────────────────────────────────
    final kosiReading = kosiAsync.asData?.value;
    final kosiLevel = kosiReading?.levelM ?? 0.0;
    final kosiDanger = kosiReading?.dangerLevel ?? kBirpurDangerLevel;

    // ── Source health map ─────────────────────────────────────────────────────
    final sourceMap = <String, DataSourceHealth>{
      'CWC': hasCwc ? DataSourceHealth.live : DataSourceHealth.offline,
      'WRD': hasWrd ? DataSourceHealth.live : DataSourceHealth.offline,
      'IMD': hasWeather ? DataSourceHealth.live : DataSourceHealth.offline,
      'KOSI': kosiOk ? DataSourceHealth.live : DataSourceHealth.offline,
    };

    // ── Weather ─────────────────────────────────────────────────────────────────
    final tempC = weather.tempC;
    final humidity = weather.humidity.toDouble();
    final rainfallNow = weather.precipMm;
    final rain7d = weather.rainfall7dMm;
    final forecast = weather.forecast;
    final rainTotal = forecast.fold(0.0, (s, d) => s + d.rainMm);

    return AiInsight(
      overallRisk: overallRisk,
      confidence: conf,
      stationCount: total,
      criticalCount: critical,
      severeCount: severe,
      alertCount: alerts,
      dangerPercent: total > 0 ? critical / total * 100 : 0,
      lastFetched: DateTime.now(),
      sources: sourceMap,
      kosiLevel: kosiLevel,
      kosiDanger: kosiDanger,
      riverTrends: trends,
      stations: floodList,
      tempC: tempC,
      humidity: humidity,
      rainfallNow: rainfallNow,
      rainfall7dMm: rain7d,
      rainfallIndex: weather.rainfallIndex,
      forecast: forecast,
      forecastRainTotal: rainTotal,
      modelVersion: '3.2',
      mlConfidence: conf,
      mlBackendLive: false,
    );
  }
}

final aiInsightProvider = AsyncNotifierProvider<AiInsightNotifier, AiInsight>(
  AiInsightNotifier.new,
);

// ────────────────────────────────────────────────────────────────────────────────
// Helper: RiverStation → FloodData
// ────────────────────────────────────────────────────────────────────────────────

FloodData _toFloodData(RiverStation s) {
  return FloodData(
    stationId: s.station,
    stationName: s.station,
    river: s.river,
    district: s.city,
    currentLevel: s.current,
    warningLevel: s.warning,
    dangerLevel: s.danger,
    city: s.station,
    state: s.state,
    lastUpdated: DateTime.now(),
  );
}
