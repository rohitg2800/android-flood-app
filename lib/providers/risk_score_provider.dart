// lib/providers/risk_score_provider.dart
// v2 — uses mergedStationsProvider (was using stale FloodData / prediction)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import 'real_time_river_provider.dart';

// ─── RiskScore value object ───────────────────────────────────────────────────
class RiskScore {
  final double overall; // 0-100
  final double floodRisk; // 0-100 (based on dangerClass distribution)
  final double infrastructureRisk; // 0-100 (stations above danger)
  final double populationRisk; // 0-100 (critical stations weighted)
  final String label; // 'LOW' | 'MODERATE' | 'HIGH' | 'EXTREME'
  final String summary; // one-liner for dashboard
  final int criticalCount;
  final int severeCount;
  final int totalStations;

  const RiskScore({
    required this.overall,
    required this.floodRisk,
    required this.infrastructureRisk,
    required this.populationRisk,
    required this.label,
    required this.summary,
    required this.criticalCount,
    required this.severeCount,
    required this.totalStations,
  });
}

// ─── Compute risk from live merged stations ───────────────────────────────────
final riskScoreProvider = Provider<RiskScore>((ref) {
  final stations = ref.watch(mergedStationsProvider);

  if (stations.isEmpty) {
    return const RiskScore(
      overall: 0,
      floodRisk: 0,
      infrastructureRisk: 0,
      populationRisk: 0,
      label: 'LOADING',
      summary: 'Connecting to live data…',
      criticalCount: 0,
      severeCount: 0,
      totalStations: 0,
    );
  }

  final total = stations.length;
  final critical =
      stations.where((s) => s.dangerClass == DangerClass.extreme).length;
  final severe =
      stations.where((s) => s.dangerClass == DangerClass.severe).length;
  final elevated =
      stations.where((s) => s.dangerClass == DangerClass.aboveNormal).length;

  // Flood risk: weighted by severity
  final floodRisk =
      ((critical * 100 + severe * 70 + elevated * 40) / (total * 100) * 100)
          .clamp(0.0, 100.0);

  // Infrastructure: % of stations at or above danger level
  final infraRisk = ((critical + severe) / total * 100).clamp(0.0, 100.0);

  // Population: heavily weighted by extreme stations
  final popRisk =
      ((critical * 2 + severe) / (total * 2 + 1) * 100).clamp(0.0, 100.0);

  // Overall: weighted average
  final overall =
      (floodRisk * 0.5 + infraRisk * 0.3 + popRisk * 0.2).clamp(0.0, 100.0);

  String label;
  String summary;
  if (overall >= 70) {
    label = 'EXTREME';
    summary =
        '$critical stations at extreme flood level. Immediate action required.';
  } else if (overall >= 45) {
    label = 'HIGH';
    summary =
        '${critical + severe} stations at danger level across Bihar rivers.';
  } else if (overall >= 20) {
    label = 'MODERATE';
    summary = '$elevated stations above warning level. Monitor closely.';
  } else {
    label = 'LOW';
    summary =
        'Most stations (${stations.where((s) => s.dangerClass == DangerClass.normal).length}) within safe range.';
  }

  return RiskScore(
    overall: overall,
    floodRisk: floodRisk,
    infrastructureRisk: infraRisk,
    populationRisk: popRisk,
    label: label,
    summary: summary,
    criticalCount: critical,
    severeCount: severe,
    totalStations: total,
  );
});

// Convenience scalar
final overallRiskScoreProvider =
    Provider<double>((ref) => ref.watch(riskScoreProvider).overall);

final riskLabelProvider =
    Provider<String>((ref) => ref.watch(riskScoreProvider).label);
