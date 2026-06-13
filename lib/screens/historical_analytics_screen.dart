// lib/screens/historical_analytics_screen.dart
// OpsFlood — Historical Analytics Screen (Phase 3)
//
// Three tabs:
//   1. Timeline  — flood event list (WL/DL/HFL crossings)
//   2. Chart     — yearly peak-level bar chart with danger-level overlay
//   3. Stats     — summary KPI cards
//
// Data source: historicalDataProvider (Riverpod)
// No external dependencies beyond fl_chart + river_theme
// ---------------------------------------------------------------------------

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/historical_flood_data.dart';
import '../providers/historical_data_provider.dart';
import '../theme/river_theme.dart';

// ── helpers ─────────────────────────────────────────────────────────────────

Color _eventColor(FloodEventType t) {
  switch (t) {
    case FloodEventType.hfl:          return AppPalette.critical;
    case FloodEventType.dangerLevel:  return AppPalette.danger;
    case FloodEventType.warningLevel: return AppPalette.warning;
  }
}

// ── screen ──────────────────────────────────────────────────────────────────

class HistoricalAnalyticsScreen extends ConsumerStatefulWidget {
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
        tabBarTheme: TabBarTheme(
          labelStyle:        const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
          indicatorColor:    AppPalette.cyan,
          labelColor:        AppPalette.cyan,
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

// ── Timeline tab ─────────────────────────────────────────────────────────────

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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return _EventTile(record: r);
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  final HistoricalFloodRecord record;
  const _EventTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final color = _eventColor(record.eventType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:        t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: t.stroke.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(Icons.water_drop, color: color, size: 18),
        ),
        title: Text(
          record.stationName,
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${record.eventDate}  •  ${record.eventType.name}  •  ${record.waterLevel.toStringAsFixed(2)} m',
          style: TextStyle(color: t.textSecondary, fontSize: 12),
        ),
        trailing: Text(
          record.year.toString(),
          style: TextStyle(color: t.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

// ── Chart tab ────────────────────────────────────────────────────────────────

class _ChartTab extends StatelessWidget {
  final List<HistoricalFloodRecord> records;
  const _ChartTab({required this.records});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    // Group by year → max water level
    final Map<int, double> byYear = {};
    for (final r in records) {
      byYear[r.year] = (byYear[r.year] ?? 0).clamp(0, r.waterLevel) == 0
          ? r.waterLevel
          : (byYear[r.year]! > r.waterLevel ? byYear[r.year]! : r.waterLevel);
    }

    final years = byYear.keys.toList()..sort();

    if (years.isEmpty) {
      return Center(
          child: Text('No data for chart.',
              style: TextStyle(color: t.textSecondary)));
    }

    final bars = years.asMap().entries.map((e) {
      final y   = e.value;
      final val = byYear[y]!;
      // Danger level proxy — in real app pull from station metadata
      const dangerLevel = 8.0;
      final barColor = val >= dangerLevel ? AppPalette.danger : AppPalette.cyan;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY:       val,
            color:     barColor,
            width:     16,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yearly Peak Water Levels',
              style: TextStyle(
                  color:      t.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize:   16)),
          const SizedBox(height: 4),
          Text('Bar = peak level  •  Dashed = danger threshold',
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: bars,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: t.stroke.withValues(alpha: 0.3), strokeWidth: 1),
                  getDrawingVerticalLine:   (_) => FlLine(color: Colors.transparent),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= years.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            years[i].toString().substring(2),
                            style: TextStyle(color: t.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles:   true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: TextStyle(color: t.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y:            8.0,
                      color:        AppPalette.danger,
                      strokeWidth:  1.5,
                      dashArray:    [6, 3],
                      label:        HorizontalLineLabel(
                        show:      true,
                        alignment: Alignment.topRight,
                        style:     TextStyle(color: AppPalette.danger, fontSize: 10),
                        labelResolver: (_) => 'DL',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppPalette.cyan, label: 'Peak Level'),
              const SizedBox(width: 20),
              _Legend(color: AppPalette.danger, label: 'Danger Level', dashed: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color  color;
  final String label;
  final bool   dashed;
  const _Legend({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24, height: 3,
          decoration: BoxDecoration(
            color:        dashed ? Colors.transparent : color,
            border:       dashed ? Border.all(color: color) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color:    RiverColors.of(context).textSecondary,
                fontSize: 11)),
      ],
    );
  }
}

// ── Stats tab ────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final List<HistoricalFloodRecord> records;
  const _StatsTab({required this.records});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    int  hfl     = 0;
    int  danger  = 0;
    int  warning = 0;
    int  total   = records.length;
    double maxLevel = 0;

    for (final r in records) {
      switch (r.eventType) {
        case FloodEventType.hfl:          hfl++;     break;
        case FloodEventType.dangerLevel:  danger++;  break;
        case FloodEventType.warningLevel: warning++; break;
      }
      if (r.waterLevel > maxLevel) maxLevel = r.waterLevel;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
          icon: Icons.water_rounded,
          color: AppPalette.critical,
          label: 'HFL Events',
          value: hfl.toString(),
          t:     t,
        ),
        _StatCard(
          icon: Icons.show_chart_rounded,
          color: AppPalette.cyan,
          label: 'Total Records',
          value: total.toString(),
          t:     t,
        ),
        _StatCard(
          icon: Icons.warning_rounded,
          color: AppPalette.danger,
          label: 'Danger Crossings',
          value: danger.toString(),
          t:     t,
        ),
        _StatCard(
          icon: Icons.emergency_rounded,
          color: AppPalette.critical,
          label: 'Emergency Events',
          value: hfl.toString(),
          t:     t,
        ),
        _StatCard(
          icon: Icons.timer_rounded,
          color: AppPalette.warning,
          label: 'Warning Crossings',
          value: warning.toString(),
          t:     t,
        ),
        _StatCard(
          icon: Icons.height_rounded,
          color: AppPalette.cyan,
          label: 'Max Water Level',
          value: '${maxLevel.toStringAsFixed(2)} m',
          t:     t,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData  icon;
  final Color     color;
  final String    label;
  final String    value;
  final RiverColors t;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: t.stroke.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: TextStyle(color: t.textSecondary, fontSize: 14)),
          ),
          Text(value,
              style: TextStyle(
                  color:      t.textPrimary,
                  fontSize:   18,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
