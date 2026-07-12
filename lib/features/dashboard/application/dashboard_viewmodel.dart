import "package:flutter/material.dart";
import "../../../l10n/context_l10n.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../domain/dashboard_tile.dart";
import "../domain/dashboard_stats.dart";
import "package:equinox_flood/providers/real_time_river_provider.dart";
import "package:equinox_flood/providers/live_engine_bridge_provider.dart";

class _P {
  static const riverBlue = Color(0xFF4CB3FF);
  static const signalGreen = Color(0xFF3ACC8A);
  static const mapTeal = Color(0xFF2DD4BF);
  static const explorerCyan = Color(0xFF06B6D4);
  static const alertRed = Color(0xFFFF4D5A);
  static const sosRed = Color(0xFFFF3B5C);
  static const evacAmber = Color(0xFFFFC857);
  static const aiViolet = Color(0xFF818CF8);
  static const rainfallBlue = Color(0xFF60A5FA);
  static const sunAmber = Color(0xFFFBBF24);
}

monitoringTiles(BuildContext context) => [
      DashboardTile(
          label: context.l10n.riverMonitor,
          icon: Icons.monitor_heart_outlined,
          color: _P.riverBlue,
          route: "/monitors"),
      DashboardTile(
          label: "Live Stations",
          icon: Icons.broadcast_on_personal_rounded,
          color: _P.signalGreen,
          route: "/live-stations"),
      DashboardTile(
          label: context.l10n.biharRiverMap,
          icon: Icons.map_rounded,
          color: _P.mapTeal,
          route: "/bihar-river-map"),
      DashboardTile(
          label: "India Explorer",
          icon: Icons.travel_explore_rounded,
          color: _P.explorerCyan,
          route: "/india-river-explorer"),
    ];

alertsTiles(BuildContext context) => [
      DashboardTile(
          label: "Alerts",
          icon: Icons.notifications_active_rounded,
          color: _P.alertRed,
          route: "/alerts"),
      DashboardTile(
          label: "SOS",
          icon: Icons.health_and_safety_rounded,
          color: _P.sosRed,
          route: "/sos"),
      DashboardTile(
          label: "Evacuation",
          icon: Icons.directions_run_rounded,
          color: _P.evacAmber,
          route: "/evacuation"),
    ];

forecastTiles(BuildContext context) => [
      DashboardTile(
          label: context.l10n.aiFloodPrediction,
          icon: Icons.psychology_rounded,
          color: _P.aiViolet,
          route: "/ai-predictor"),
      DashboardTile(
          label: context.l10n.rainfall,
          icon: Icons.grain_rounded,
          color: _P.rainfallBlue,
          route: "/rainfall-forecast"),
      DashboardTile(
          label: "Weather",
          icon: Icons.wb_sunny_rounded,
          color: _P.sunAmber,
          route: "/weather"),
    ];

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final stations = ref.watch(liveEngineStationsProvider);

  int critical = 0, elevated = 0, safe = 0, noData = 0;
  for (final s in stations) {
    final cur = s.current;
    final danger = s.danger;
    final warning = s.warning;
    if (cur <= 0)
      noData++;
    else if (cur >= danger)
      critical++;
    else if (cur >= warning)
      elevated++;
    else
      safe++;
  }

  return DashboardStats(
    critical: critical,
    elevated: elevated,
    safe: safe,
    noData: noData,
    lastUpdated: stations.isEmpty ? "--" : "just now",
  );
});
