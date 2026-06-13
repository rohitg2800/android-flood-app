// lib/screens/analytics_dashboard_screen.dart
// OpsFlood — Module 14: Analytics Dashboard

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alert_provider.dart';
import '../services/alert_engine.dart';

// ── Minimal AnalyticsData model ───────────────────────────────────────────────
class AnalyticsData {
  final int    hflCount;
  final double avgRisk;
  final List<FlSpot> riskTrend;
  final Map<String, int> districtAlerts;
  const AnalyticsData({
    required this.hflCount,
    required this.avgRisk,
    required this.riskTrend,
    required this.districtAlerts,
  });
}

// ── Stub providers — replace with real implementations when available ─────────
final activeAlertsProvider = Provider<List<FloodAlert>>((ref) => const []);
final analyticsProvider    = Provider<AnalyticsData>((ref) => const AnalyticsData(
  hflCount: 0, avgRisk: 0.0, riskTrend: [], districtAlerts: {},
));
final liveLevelsProvider   = Provider<List<dynamic>>((ref) => const []);

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t         = RiverColors.of(context);
    final alerts    = ref.watch(activeAlertsProvider);
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.cardBg,
        elevation: 0,
        title: Text('Analytics Dashboard',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kpiRow(t, alerts.length, analytics.hflCount, analytics.avgRisk),
          const SizedBox(height: 20),
          _SectionHeader(title: 'System Risk Trend', t: t),
          const SizedBox(height: 8),
          _RiskTrendChart(analytics: analytics, t: t),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _kpiRow(RiverColors t, int alertCount, int hflCount, double avgRisk) {
    return Row(
      children: [
        Expanded(child: _Kpi(label: 'Active Alerts', value: '$alertCount',
            color: AppPalette.warning, t: t)),
        const SizedBox(width: 12),
        Expanded(child: _Kpi(label: 'HFL Events', value: '$hflCount',
            color: AppPalette.critical, t: t)),
        const SizedBox(width: 12),
        Expanded(child: _Kpi(label: 'Avg Risk', value: avgRisk.toStringAsFixed(1),
            color: AppPalette.cyan, t: t)),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final Color  color;
  final RiverColors t;
  const _Kpi({required this.label, required this.value,
      required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color,
              fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final RiverColors t;
  const _SectionHeader({required this.title, required this.t});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(color: t.textPrimary,
            fontSize: 15, fontWeight: FontWeight.w700));
  }
}

class _RiskTrendChart extends StatelessWidget {
  final AnalyticsData analytics;
  final RiverColors t;
  const _RiskTrendChart({required this.analytics, required this.t});

  @override
  Widget build(BuildContext context) {
    if (analytics.riskTrend.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No trend data', style: TextStyle(color: t.textSecondary)),
      );
    }
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: analytics.riskTrend,
              isCurved: true,
              color: AppPalette.cyan,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
