// lib/screens/analytics_dashboard_screen.dart
// OpsFlood — Module 14: Analytics Dashboard
//
// Full-screen analytics view with:
//  • 7-day station water-level sparklines (fl_chart)
//  • District-wise alert frequency bar chart
//  • Risk score trend line chart
//  • Summary stat cards (total alerts, HFL events, avg risk)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/alert_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/live_data_provider.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t        = RiverColors.of(context);
    final alerts   = ref.watch(activeAlertsProvider);
    final analytics = ref.watch(analyticsProvider);
    final live      = ref.watch(liveLevelsProvider);

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
          // ── KPI cards ──
          _kpiRow(t, alerts.length, analytics.hflCount, analytics.avgRisk),
          const SizedBox(height: 20),

          // ── Water-level sparklines ──
          _SectionHeader(title: 'Station Water Levels (7-day)', t: t),
          const SizedBox(height: 8),
          _SparklineCard(live: live, t: t),
          const SizedBox(height: 20),

          // ── Alert frequency bar ──
          _SectionHeader(title: 'District Alert Frequency', t: t),
          const SizedBox(height: 8),
          _AlertFrequencyChart(analytics: analytics, t: t),
          const SizedBox(height: 20),

          // ── Risk trend ──
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
            fontWeight: FontWeight.w700, fontSize: 15));
  }
}

// ── Sparkline card ────────────────────────────────────────────────────────────
class _SparklineCard extends StatelessWidget {
  final dynamic live;
  final RiverColors t;
  const _SparklineCard({required this.live, required this.t});

  @override
  Widget build(BuildContext context) {
    // Show up to 8 stations, each as a mini horizontal bar
    final entries = (live as Map).entries.take(8).toList();
    if (entries.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No live data', style: TextStyle(color: t.textSecondary)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: entries.map((e) {
          final fl  = e.value;
          final pct = (fl.fillPercent as double).clamp(0.0, 1.0);
          final barColor = pct > 0.85 ? AppPalette.critical
              : pct > 0.65 ? AppPalette.danger
              : pct > 0.45 ? AppPalette.warning
              : AppPalette.safe;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 110,
                    child: Text(fl.stationName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.textPrimary, fontSize: 11))),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value:           pct,
                      color:           barColor,
                      backgroundColor: t.stroke.withValues(alpha: 0.3),
                      minHeight:       7,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: barColor, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Alert frequency bar chart ─────────────────────────────────────────────────
class _AlertFrequencyChart extends StatelessWidget {
  final dynamic analytics;
  final RiverColors t;
  const _AlertFrequencyChart({required this.analytics, required this.t});

  @override
  Widget build(BuildContext context) {
    final data = analytics.districtAlertFreq as Map<String, int>;
    if (data.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No data', style: TextStyle(color: t.textSecondary)),
      );
    }
    final entries = data.entries.take(7).toList();
    final bars = entries.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY:   e.value.value.toDouble(),
            color: AppPalette.cyan,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke.withValues(alpha: 0.4)),
      ),
      child: BarChart(BarChartData(
        barGroups: bars,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: t.stroke.withValues(alpha: 0.3), strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(color: Colors.transparent),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entries[i].key.substring(0, 3),
                    style: TextStyle(color: t.textSecondary, fontSize: 9),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(color: t.textSecondary, fontSize: 9),
              ),
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      )),
    );
  }
}

// ── Risk trend line chart ─────────────────────────────────────────────────────
class _RiskTrendChart extends StatelessWidget {
  final dynamic analytics;
  final RiverColors t;
  const _RiskTrendChart({required this.analytics, required this.t});

  @override
  Widget build(BuildContext context) {
    final trend = analytics.riskTrend as List<double>;
    if (trend.isEmpty) {
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

    final spots = trend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke.withValues(alpha: 0.4)),
      ),
      child: LineChart(LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots:        spots,
            isCurved:     true,
            color:        AppPalette.danger,
            barWidth:     2,
            dotData:      const FlDotData(show: false),
            belowBarData: BarAreaData(
              show:  true,
              color: AppPalette.danger.withValues(alpha: 0.1),
            ),
          ),
        ],
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: t.stroke.withValues(alpha: 0.3), strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(color: Colors.transparent),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: TextStyle(color: t.textSecondary, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                'D${v.toInt() + 1}',
                style: TextStyle(color: t.textSecondary, fontSize: 9),
              ),
            ),
          ),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      )),
    );
  }
}
