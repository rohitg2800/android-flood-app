// lib/screens/historical_analytics_screen.dart
// OpsFlood — Historical Analytics Screen
// WIRING: added static route constant

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';

enum FloodEventType { hfl, dangerLevel, warningLevel }

class HistoricalFloodRecord {
  final DateTime date;
  final String   station;
  final String   river;
  final double   peakLevel;
  final double   dangerLevel;
  final double   warningLevel;
  final FloodEventType eventType;

  const HistoricalFloodRecord({
    required this.date,
    required this.station,
    required this.river,
    required this.peakLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.eventType,
  });
}

final historicalDataProvider =
    FutureProvider<List<HistoricalFloodRecord>>((ref) async {
  return const [];
});

Color _eventColor(FloodEventType t) {
  switch (t) {
    case FloodEventType.hfl:          return AppPalette.critical;
    case FloodEventType.dangerLevel:  return AppPalette.danger;
    case FloodEventType.warningLevel: return AppPalette.warning;
  }
}

class HistoricalAnalyticsScreen extends ConsumerStatefulWidget {
  static const String route = '/historical-analytics';
  const HistoricalAnalyticsScreen({super.key});

  @override
  ConsumerState<HistoricalAnalyticsScreen> createState() =>
      _HistoricalAnalyticsScreenState();
}

class _HistoricalAnalyticsScreenState
    extends ConsumerState<HistoricalAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(historicalDataProvider);
    final t    = RiverColors.of(context);

    return Theme(
      data: Theme.of(context).copyWith(
        tabBarTheme: TabBarThemeData(
          labelStyle:           const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
          indicatorColor:       AppPalette.cyan,
          labelColor:           AppPalette.cyan,
          unselectedLabelColor: t.textSecondary,
        ),
      ),
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        appBar: AppBar(
          backgroundColor: t.cardBg,
          elevation: 0,
          title: Text('Historical Analytics',
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
          iconTheme: IconThemeData(color: t.textPrimary),
          bottom: TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'Timeline'),
              Tab(text: 'Chart'),
              Tab(text: 'Stats'),
            ],
          ),
        ),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (records) => TabBarView(
            controller: _tab,
            children: [
              _TimelineTab(records: records),
              _ChartTab(records: records),
              _StatsTab(records: records),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  final List<HistoricalFloodRecord> records;
  const _TimelineTab({required this.records});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (records.isEmpty) {
      return Center(
        child: Text('No historical data available.',
            style: TextStyle(color: t.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = records[i];
        final color = _eventColor(r.eventType);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.station} — ${r.river}',
                        style: TextStyle(color: t.textPrimary,
                            fontWeight: FontWeight.w600)),
                    Text('Peak: ${r.peakLevel.toStringAsFixed(2)} m  |  '
                        '${r.date.year}-${r.date.month.toString().padLeft(2,"0")}-${r.date.day.toString().padLeft(2,"0")}',
                        style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(r.eventType.name.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

class _ChartTab extends StatelessWidget {
  final List<HistoricalFloodRecord> records;
  const _ChartTab({required this.records});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (records.isEmpty) {
      return Center(
        child: Text('No chart data.', style: TextStyle(color: t.textSecondary)),
      );
    }
    final Map<int, double> yearPeak = {};
    for (final r in records) {
      final yr = r.date.year;
      yearPeak[yr] = (yearPeak[yr] ?? 0).clamp(0, double.infinity) < r.peakLevel
          ? r.peakLevel : yearPeak[yr]!;
    }
    final years  = yearPeak.keys.toList()..sort();
    final groups = years.asMap().entries.map((e) => BarChartGroupData(
      x: e.key,
      barRods: [
        BarChartRodData(
          toY: yearPeak[e.value]!,
          color: AppPalette.cyan,
          width: 14,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    )).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          barGroups: groups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= years.length) return const SizedBox();
                  return Text('${years[idx]}',
                      style: TextStyle(color: t.textSecondary, fontSize: 9));
                },
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final List<HistoricalFloodRecord> records;
  const _StatsTab({required this.records});

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final hflCnt = records.where((r) => r.eventType == FloodEventType.hfl).length;
    final dlCnt  = records.where((r) => r.eventType == FloodEventType.dangerLevel).length;
    final wlCnt  = records.where((r) => r.eventType == FloodEventType.warningLevel).length;
    final avgPeak = records.isEmpty ? 0.0
        : records.map((r) => r.peakLevel).reduce((a, b) => a + b) / records.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatRow(label: 'Total Events',  value: '${records.length}',               color: AppPalette.cyan,     t: t),
        _StatRow(label: 'HFL Crossings', value: '$hflCnt',                         color: AppPalette.critical, t: t),
        _StatRow(label: 'Danger Level',  value: '$dlCnt',                          color: AppPalette.danger,   t: t),
        _StatRow(label: 'Warning Level', value: '$wlCnt',                          color: AppPalette.warning,  t: t),
        _StatRow(label: 'Avg Peak',      value: '${avgPeak.toStringAsFixed(2)} m', color: AppPalette.gold,     t: t),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  final Color  color;
  final RiverColors t;
  const _StatRow({
    required this.label, required this.value,
    required this.color, required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.cardBg, borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: t.textSecondary)),
          Text(value, style: TextStyle(
              color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
