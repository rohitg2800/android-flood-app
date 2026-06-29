// lib/widgets/sparkline_card.dart  Step 4.6
// 7-day gauge history sparkline using fl_chart.
// Shows 24 h / 72 h / 7 day toggle.
// Draws a dashed red reference line at the station's danger level.
// Data comes from LocalCacheService.instance.loadGaugeHistory(stationId).

import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/local_cache_service.dart';
import '../theme/river_theme.dart';

enum _Range { h24, h72, d7 }

class SparklineCard extends StatefulWidget {
  final String stationId;
  final double dangerLevel;
  final Color  accentColor;
  const SparklineCard({
    super.key,
    required this.stationId,
    required this.dangerLevel,
    required this.accentColor,
  });

  @override
  State<SparklineCard> createState() => _SparklineCardState();
}

class _SparklineCardState extends State<SparklineCard> {
  _Range _range = _Range.h24;
  List<(DateTime, double)> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hist =
        await LocalCacheService.instance.loadGaugeHistory(widget.stationId);
    if (mounted) setState(() { _all = hist; _loading = false; });
  }

  List<(DateTime, double)> get _filtered {
    if (_all.isEmpty) return [];
    final cutoff = switch (_range) {
      _Range.h24 => DateTime.now().subtract(const Duration(hours: 24)),
      _Range.h72 => DateTime.now().subtract(const Duration(hours: 72)),
      _Range.d7  => DateTime.now().subtract(const Duration(days: 7)),
    };
    return _all.where((e) => e.$1.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t       = RiverColors.of(context);
    final color   = widget.accentColor;
    final data    = _filtered;
    final hasData = data.length >= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'Level History',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              // Toggle chips
              _ToggleBar(
                selected: _range,
                onSelect: (r) => setState(() => _range = r),
                t: t,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart or placeholder
          SizedBox(
            height: 130,
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(color)),
                    ),
                  )
                : !hasData
                    ? Center(
                        child: Text(
                          'No history yet — syncs every 15 min',
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 12),
                        ),
                      )
                    : _Chart(
                        data:        data,
                        dangerLevel: widget.dangerLevel,
                        color:       color,
                        t:           t,
                      ),
          ),

          // Danger level legend
          if (hasData) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 16, height: 2,
                  color: AppPalette.critical.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Danger: ${widget.dangerLevel.toStringAsFixed(2)} m',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Chart widget ───────────────────────────────────────────────────────────────

class _Chart extends StatelessWidget {
  final List<(DateTime, double)> data;
  final double      dangerLevel;
  final Color       color;
  final RiverColors t;
  const _Chart({
    required this.data,
    required this.dangerLevel,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final base   = data.first.$1.millisecondsSinceEpoch.toDouble();
    final spots  = data.map((e) => FlSpot(
      (e.$1.millisecondsSinceEpoch - base) / 3600000.0,  // hours offset
      e.$2,
    )).toList();

    final maxY   = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY   = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final padY   = (maxY - minY).clamp(0.5, double.infinity) * 0.2;
    final chartMaxY = (maxY + padY).clamp(maxY, maxY + padY);
    final chartMinY = (minY - padY).clamp(0.0, minY);

    return LineChart(
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (chartMaxY - chartMinY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.divider.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: (chartMaxY - chartMinY) / 3,
              getTitlesWidget: (val, _) => Text(
                val.toStringAsFixed(1),
                style: TextStyle(color: t.textSecondary, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        // Danger level reference line
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y:          dangerLevel,
              color:      AppPalette.critical.withValues(alpha: 0.65),
              strokeWidth: 1.5,
              dashArray:  [4, 4],
              label: HorizontalLineLabel(
                show: false, // shown in legend below chart
              ),
            ),
          ],
        ),
        // Touch tooltip
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.cardBg.withValues(alpha: 0.9),
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                '${s.y.toStringAsFixed(2)} m',
                TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots:           spots,
            isCurved:        true,
            color:           color,
            barWidth:        2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length <= 12, // only show dots for sparse data
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color:  color,
                strokeWidth: 1.5,
                strokeColor: t.cardBg,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.01)],
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve:    Curves.easeInOut,
    );
  }
}

// ── Toggle bar ──────────────────────────────────────────────────────────────────

class _ToggleBar extends StatelessWidget {
  final _Range   selected;
  final void Function(_Range) onSelect;
  final RiverColors t;
  final Color       color;
  const _ToggleBar({
    required this.selected, required this.onSelect,
    required this.t,        required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip('24h', _Range.h24),
        const SizedBox(width: 4),
        _Chip('72h', _Range.h72),
        const SizedBox(width: 4),
        _Chip('7d',  _Range.d7),
      ],
    );
  }

  Widget _Chip(String label, _Range range) {
    final active = selected == range;
    return GestureDetector(
      onTap: () => onSelect(range),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color : t.divider.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: active ? color : t.textSecondary,
              fontSize: 10,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500),
        ),
      ),
    );
  }
}
