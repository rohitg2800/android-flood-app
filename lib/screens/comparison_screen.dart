// lib/screens/comparison_screen.dart
// OpsFlood — Station Comparison v2.0
//
// Sources:
//   • liveLevelsProvider      → FloodData stations (CWC national + Bihar WRD)
//   • mergedStationsProvider  → RiverStation objects (CWC + Bihar live)
// All sources are merged, de-duplicated by id/city, then displayed.
// Up to 4 stations can be selected for side-by-side comparison.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../providers/flood_providers.dart';
import '../providers/real_time_river_provider.dart'; // mergedStationsProvider
import '../theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unified view-model used inside this screen
// ─────────────────────────────────────────────────────────────────────────────

class CompStation {
  final String id;
  final String name;
  final String river;
  final String state;
  final String source; // 'CWC' | 'Bihar' | 'Live'
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final List<_LevelPoint> history;

  const CompStation({
    required this.id,
    required this.name,
    required this.river,
    required this.state,
    required this.source,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.history,
  });

  double get dangerPct =>
      dangerLevel > 0 ? (currentLevel / dangerLevel).clamp(0.0, 1.5) : 0.0;

  String get trendLabel {
    if (history.length < 2) return '=';
    final delta = history.last.level - history[history.length - 2].level;
    if (delta > 0.05) return '↑';
    if (delta < -0.05) return '↓';
    return '=';
  }

  Color get riskColor {
    final pct = dangerPct;
    if (pct >= 1.0) return const Color(0xFFFF3B30);
    if (pct >= 0.85) return const Color(0xFFFF6B35);
    if (pct >= 0.70) return const Color(0xFFFFCC00);
    return const Color(0xFF34C759);
  }

  String get riskLabel {
    final pct = dangerPct;
    if (pct >= 1.0) return 'CRITICAL';
    if (pct >= 0.85) return 'SEVERE';
    if (pct >= 0.70) return 'WARNING';
    return 'NORMAL';
  }

  // Build from FloodData (liveLevelsProvider)
  // FloodData has no stationId field — use city as the dedup key.
  factory CompStation.fromFloodData(FloodData d) {
    final danger  = d.dangerLevel  > 0 ? d.dangerLevel  : d.currentLevel * 1.15;
    final warning = d.warningLevel > 0 ? d.warningLevel : d.currentLevel * 0.92;
    return CompStation(
      id:           d.city,
      name:         d.city,
      river:        d.riverName ?? 'Unknown',
      state:        d.state,
      source:       'Live',
      currentLevel: d.currentLevel,
      dangerLevel:  danger,
      warningLevel: warning,
      history:      _syntheticHistory(d.currentLevel, danger),
    );
  }

  // Build from RiverStation (mergedStationsProvider)
  // Actual RiverStation fields:
  //   current / warning / danger  (not currentLevel / warningLevel / dangerLevel)
  //   station                     (used for both id and display name)
  //   river                       (not riverName)
  //   dataSource                  (not source)
  factory CompStation.fromRiverStation(RiverStation s) {
    final current = s.current;
    final danger  = s.danger  > 0 ? s.danger  : current * 1.15;
    final warning = s.warning > 0 ? s.warning : current * 0.92;
    return CompStation(
      id:           s.station,
      name:         s.station,
      river:        s.river,
      state:        s.state,
      source:       s.dataSource ?? 'CWC',
      currentLevel: current,
      dangerLevel:  danger,
      warningLevel: warning,
      history:      _syntheticHistory(current, danger),
    );
  }

  // Synthetic 24-point history seeded from current level.
  // Replace with a real history provider when available.
  static List<_LevelPoint> _syntheticHistory(
      double current, double danger) {
    return List.generate(24, (i) {
      final frac = i / 23.0;
      final base = (current * 0.93) + (current * 0.07 * frac);
      return _LevelPoint(i.toDouble(), base);
    });
  }
}

class _LevelPoint {
  final double x;
  final double level;
  const _LevelPoint(this.x, this.level);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider: derive CompStation list from live Riverpod state
// ─────────────────────────────────────────────────────────────────────────────

/// allCompStationsProvider is a derived Riverpod Provider that watches both
/// upstream providers; the station list automatically updates whenever new
/// data arrives from the API — no manual refresh needed in the comparison screen.
final allCompStationsProvider = Provider<List<CompStation>>((ref) {
  // Source 1: FloodData live levels
  final liveList = ref.watch(liveLevelsProvider);

  // Source 2: RiverStation merged (CWC + Bihar CWC mirror)
  final riverList = ref.watch(mergedStationsProvider);

  final seen   = <String>{};
  final result = <CompStation>[];

  // FloodData first (richer metadata)
  for (final d in liveList) {
    final key = d.city.toLowerCase();
    if (seen.add(key)) result.add(CompStation.fromFloodData(d));
  }

  // RiverStation additions (skip already-seen by station name)
  for (final s in riverList) {
    final key = s.station.toLowerCase();
    if (seen.add(key)) result.add(CompStation.fromRiverStation(s));
  }

  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
});

// ─────────────────────────────────────────────────────────────────────────────
// Chart colour palette
// ─────────────────────────────────────────────────────────────────────────────

const _chartColors = [
  Color(0xFF4FC3F7), // cyan
  Color(0xFFFF6D00), // orange
  Color(0xFF69F0AE), // green
  Color(0xFFFF4081), // pink
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ComparisonScreen extends ConsumerStatefulWidget {
  static const String route = '/comparison';
  const ComparisonScreen({super.key});

  @override
  ConsumerState<ComparisonScreen> createState() =>
      _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  final _selected   = <CompStation>[];
  final _searchCtrl = TextEditingController();
  String _query        = '';
  String _sourceFilter = 'All'; // 'All' | 'Live' | 'CWC' | 'Bihar'

  List<CompStation> _filtered(List<CompStation> all) {
    return all.where((s) {
      final matchesQuery =
          s.name.toLowerCase().contains(_query.toLowerCase()) ||
          s.river.toLowerCase().contains(_query.toLowerCase()) ||
          s.state.toLowerCase().contains(_query.toLowerCase());
      final matchesSource =
          _sourceFilter == 'All' || s.source == _sourceFilter;
      return matchesQuery && matchesSource;
    }).toList();
  }

  void _toggle(CompStation s) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.any((x) => x.id == s.id)) {
        _selected.removeWhere((x) => x.id == s.id);
      } else if (_selected.length < 4) {
        _selected.add(s);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 4 stations for comparison'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final all  = ref.watch(allCompStationsProvider);
    final list = _filtered(all);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.scaffoldBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Station Comparison',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            Text('${all.length} stations available',
                style:
                    TextStyle(color: t.textSecondary, fontSize: 11)),
          ],
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 16),
              label: Text('Clear (${_selected.length})'),
              style: TextButton.styleFrom(
                  foregroundColor: AppPalette.danger),
              onPressed: () => setState(_selected.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            t: t,
            ctrl: _searchCtrl,
            query: _query,
            sourceFilter: _sourceFilter,
            onQueryChanged: (v) => setState(() => _query = v),
            onSourceChanged: (v) => setState(() => _sourceFilter = v),
          ),
          _StationPicker(
            t: t,
            stations: list,
            selected: _selected,
            onToggle: _toggle,
          ),
          if (_selected.isNotEmpty)
            _SelectedBar(t: t, selected: _selected),
          Expanded(
            child: _selected.isEmpty
                ? _EmptyState(t: t, totalCount: all.length)
                : _CompareBody(t: t, selected: _selected),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchBar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final RiverColors t;
  final TextEditingController ctrl;
  final String query;
  final String sourceFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSourceChanged;

  const _SearchBar({
    required this.t,
    required this.ctrl,
    required this.query,
    required this.sourceFilter,
    required this.onQueryChanged,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: TextStyle(color: t.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search station, river or state…',
                hintStyle:
                    TextStyle(color: t.textSecondary, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: t.textSecondary, size: 18),
                suffixIcon: query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          ctrl.clear();
                          onQueryChanged('');
                        },
                        child: Icon(Icons.close,
                            color: t.textSecondary, size: 16),
                      )
                    : null,
                filled: true,
                fillColor: t.cardBg,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: t.accent, width: 1.5),
                ),
                isDense: true,
              ),
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(width: 8),
          _SourceChip(
              t: t,
              label: 'All',
              active: sourceFilter == 'All',
              onTap: () => onSourceChanged('All')),
          const SizedBox(width: 4),
          _SourceChip(
              t: t,
              label: 'Live',
              active: sourceFilter == 'Live',
              onTap: () => onSourceChanged('Live')),
          const SizedBox(width: 4),
          _SourceChip(
              t: t,
              label: 'CWC',
              active: sourceFilter == 'CWC',
              onTap: () => onSourceChanged('CWC')),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final RiverColors t;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SourceChip({
    required this.t,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.accent.withValues(alpha: 0.15) : t.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? t.accent : t.stroke),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? t.accent : t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StationPicker — horizontal scrollable chip list
// ─────────────────────────────────────────────────────────────────────────────

class _StationPicker extends StatelessWidget {
  final RiverColors t;
  final List<CompStation> stations;
  final List<CompStation> selected;
  final ValueChanged<CompStation> onToggle;

  const _StationPicker({
    required this.t,
    required this.stations,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text('No stations match your search.',
            style:
                TextStyle(color: t.textSecondary, fontSize: 13)),
      );
    }
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s     = stations[i];
          final picked = selected.any((x) => x.id == s.id);
          final idx   = selected.indexWhere((x) => x.id == s.id);
          final color = picked
              ? _chartColors[idx % 4]
              : t.textSecondary;

          return GestureDetector(
            onTap: () => onToggle(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: picked
                    ? color.withValues(alpha: 0.15)
                    : t.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: picked ? color : t.stroke,
                    width: picked ? 1.5 : 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (picked) ...[
                    Icon(Icons.check_circle_rounded,
                        color: color, size: 13),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.riskColor,
                    ),
                  ),
                  Text(s.name,
                      style: TextStyle(
                          color: picked ? color : t.textPrimary,
                          fontSize: 12,
                          fontWeight: picked
                              ? FontWeight.w700
                              : FontWeight.w500)),
                  const SizedBox(width: 4),
                  Text(s.source,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SelectedBar — compact summary of selected stations
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedBar extends StatelessWidget {
  final RiverColors t;
  final List<CompStation> selected;
  const _SelectedBar({required this.t, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      margin:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.stroke),
      ),
      child: Row(
        children: [
          Text('Comparing: ',
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: selected.asMap().entries.map((e) {
                final color = _chartColors[e.key % 4];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 3),
                    Text(e.value.name,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final RiverColors t;
  final int totalCount;
  const _EmptyState({required this.t, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows_rounded,
              size: 64,
              color: t.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(
            'Pick up to 4 stations to compare',
            style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalCount stations loaded • scroll the chips above',
            style:
                TextStyle(color: t.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CompareBody — chart + table
// ─────────────────────────────────────────────────────────────────────────────

class _CompareBody extends StatelessWidget {
  final RiverColors t;
  final List<CompStation> selected;
  const _CompareBody({required this.t, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartCard(t: t, selected: selected),
          const SizedBox(height: 14),
          _SummaryTable(t: t, selected: selected),
          const SizedBox(height: 14),
          _DangerBars(t: t, selected: selected),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChartCard — 24-h overlay line chart
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final RiverColors t;
  final List<CompStation> selected;
  const _ChartCard({required this.t, required this.selected});

  @override
  Widget build(BuildContext context) {
    final allLevels = selected
        .expand((s) => s.history.map((p) => p.level))
        .toList();
    final minY =
        (allLevels.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
    final maxY =
        (allLevels.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 14, 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 10),
            child: Text('24-Hour Level Overlay',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: t.stroke, strokeWidth: 0.5),
                  getDrawingVerticalLine: (_) =>
                      FlLine(color: t.stroke, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 6,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}h',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 9),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 9),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: selected.asMap().entries.map((e) {
                  final color = _chartColors[e.key % 4];
                  return LineChartBarData(
                    spots: e.value.history
                        .map((p) => FlSpot(p.x, p.level))
                        .toList(),
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.06),
                    ),
                  );
                }).toList(),
                extraLinesData: ExtraLinesData(
                  horizontalLines: selected.asMap().entries.map((e) =>
                      HorizontalLine(
                        y: e.value.dangerLevel,
                        color: _chartColors[e.key % 4]
                            .withValues(alpha: 0.45),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                              color: _chartColors[e.key % 4],
                              fontSize: 8,
                              fontWeight: FontWeight.w700),
                          labelResolver: (_) =>
                              '⚠ ${e.value.name}',
                        ),
                      )).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: selected.asMap().entries.map((e) {
              final color = _chartColors[e.key % 4];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 14,
                      height: 3,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 5),
                  Text(
                    '${e.value.name} (${e.value.river})',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SummaryTable
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTable extends StatelessWidget {
  final RiverColors t;
  final List<CompStation> selected;
  const _SummaryTable({required this.t, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Status',
              style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: t.stroke))),
                children: [
                  _th(t, 'Station'),
                  _th(t, 'Level (m)'),
                  _th(t, '% Danger'),
                  _th(t, 'Trend'),
                  _th(t, 'Status'),
                ],
              ),
              ...selected.asMap().entries.map((e) {
                final s     = e.value;
                final color = _chartColors[e.key % 4];
                final pct   =
                    (s.dangerPct * 100).toStringAsFixed(0);
                return TableRow(children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(s.name,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  _td(t, s.currentLevel.toStringAsFixed(2)),
                  _td(t, '$pct%',
                      color: s.dangerPct >= 1.0
                          ? const Color(0xFFFF3B30)
                          : s.dangerPct >= 0.85
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF34C759)),
                  _td(t, s.trendLabel),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: s.riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(s.riskLabel,
                          style: TextStyle(
                              color: s.riskColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _th(RiverColors t, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      );

  Widget _td(RiverColors t, String text, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(text,
            style: TextStyle(
                color: color ?? t.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _DangerBars — visual % of danger bar for each station
// ─────────────────────────────────────────────────────────────────────────────

class _DangerBars extends StatelessWidget {
  final RiverColors t;
  final List<CompStation> selected;
  const _DangerBars({required this.t, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danger Level Progress',
              style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(height: 12),
          ...selected.asMap().entries.map((e) {
            final s        = e.value;
            final color    = _chartColors[e.key % 4];
            final fillFrac = s.dangerPct.clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              margin:
                                  const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle)),
                          Text(s.name,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          Text(s.river,
                              style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 10)),
                        ],
                      ),
                      Text(
                        '${(s.dangerPct * 100).toStringAsFixed(0)}% of danger',
                        style: TextStyle(
                            color: s.riskColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                            height: 10,
                            decoration: BoxDecoration(
                                color: t.stroke,
                                borderRadius:
                                    BorderRadius.circular(6))),
                        FractionallySizedBox(
                          widthFactor: fillFrac,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(6),
                              gradient: LinearGradient(colors: [
                                const Color(0xFF34C759),
                                s.riskColor,
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current: ${s.currentLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 10),
                      ),
                      Text(
                        'Danger: ${s.dangerLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
