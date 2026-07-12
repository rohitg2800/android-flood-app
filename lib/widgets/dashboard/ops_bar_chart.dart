// lib/widgets/dashboard/ops_bar_chart.dart
// ═══════════════════════════════════════════════════════════════════════════
// OpsBarChart  —  Data Terminal Edition
//
// ✔  Consumes ThemeRegistry — fully theme-aware
// ✔  fl_chart BarChart with glow bars
// ✔  Entry animation: bars grow from zero height
// ✔  Danger/Warning threshold line overlays
// ═══════════════════════════════════════════════════════════════════════════

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/river_station.dart';
import '../../theme/theme_registry.dart';

// Data point passed in
class BarDataPoint {
  final String label; // x-axis label (e.g. station name or date)
  final double value; // water level or risk score
  final double? warning; // optional warning threshold
  final double? danger; // optional danger threshold

  const BarDataPoint({
    required this.label,
    required this.value,
    this.warning,
    this.danger,
  });
}

class OpsBarChart extends ConsumerStatefulWidget {
  const OpsBarChart({
    super.key,
    required this.data,
    required this.title,
    this.yAxisLabel = 'm',
    this.height = 220,
    this.showThresholdLines = true,
  });

  final List<BarDataPoint> data;
  final String title;
  final String yAxisLabel;
  final double height;
  final bool showThresholdLines;

  @override
  ConsumerState<OpsBarChart> createState() => _OpsBarChartState();
}

class _OpsBarChartState extends ConsumerState<OpsBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _growAnim; // 0 → 1

  @override
  void initState() {
    super.initState();
    final rc = ThemeRegistry.of(ref.read(appSkinProvider));
    _ctrl = AnimationController(
        vsync: this,
        duration: rc.entryDuration + const Duration(milliseconds: 100));
    _growAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.microtask(() {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc = ref.watch(themeRegistryProvider);

    if (widget.data.isEmpty) {
      return _EmptyState(rc: rc, title: widget.title);
    }

    final maxY = widget.data
            .map((d) => <double>[
                  d.value,
                  d.warning ?? 0,
                  d.danger ?? 0,
                ].reduce((a, b) => a > b ? a : b))
            .reduce((a, b) => a > b ? a : b) *
        1.15;

    return Container(
      decoration: rc.terminalBox,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(rc: rc, title: widget.title),
          const SizedBox(height: 14),
          SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _growAnim,
              builder: (_, __) => BarChart(
                _buildBarData(
                  rc: rc,
                  growFactor: _growAnim.value,
                  maxY: maxY,
                ),
                swapAnimationDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartData _buildBarData({
    required SkinTokens rc,
    required double growFactor,
    required double maxY,
  }) {
    final groups = widget.data.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;
      final barColor = d.danger != null && d.value >= d.danger!
          ? rc.danger
          : d.warning != null && d.value >= d.warning!
              ? rc.warning
              : rc.safe;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: d.value * growFactor,
            width: 14,
            borderRadius: BorderRadius.only(
              topLeft: rc.chipRadius.topLeft,
              topRight: rc.chipRadius.topRight,
            ),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                barColor.withValues(alpha: 0.55),
                barColor,
              ],
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: rc.surfaceHigh,
            ),
          ),
        ],
      );
    }).toList();

    // Threshold horizontal lines
    final thresholdLines = <HorizontalLine>[];
    if (widget.showThresholdLines) {
      final warnings =
          widget.data.where((d) => d.warning != null).map((d) => d.warning!);
      final dangers =
          widget.data.where((d) => d.danger != null).map((d) => d.danger!);

      if (warnings.isNotEmpty) {
        final avgWarn = warnings.reduce((a, b) => a + b) / warnings.length;
        thresholdLines.add(HorizontalLine(
          y: avgWarn,
          color: rc.warning.withValues(alpha: 0.55),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true,
            style: rc.labelXs.copyWith(color: rc.warning),
            labelResolver: (_) => 'WARN',
            alignment: Alignment.topRight,
          ),
        ));
      }
      if (dangers.isNotEmpty) {
        final avgDang = dangers.reduce((a, b) => a + b) / dangers.length;
        thresholdLines.add(HorizontalLine(
          y: avgDang,
          color: rc.danger.withValues(alpha: 0.55),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true,
            style: rc.labelXs.copyWith(color: rc.danger),
            labelResolver: (_) => 'DNGR',
            alignment: Alignment.topRight,
          ),
        ));
      }
    }

    return BarChartData(
      maxY: maxY,
      barGroups: groups,
      extraLinesData: ExtraLinesData(horizontalLines: thresholdLines),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color: rc.divider,
          strokeWidth: 1,
          dashArray: [3, 5],
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: rc.divider, width: 1),
          left: BorderSide(color: rc.divider, width: 1),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, _) => Text(
              v.toStringAsFixed(0),
              style: rc.monoSm.copyWith(fontSize: 9),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= widget.data.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.data[i].label.length > 6
                      ? widget.data[i].label.substring(0, 6)
                      : widget.data[i].label,
                  style: rc.labelXs,
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => rc.surfaceMid,
          tooltipRoundedRadius: 6,
          getTooltipItem: (group, gi, rod, ri) {
            final d = widget.data[group.x];
            return BarTooltipItem(
              '${d.label}\n',
              rc.labelSm.copyWith(color: rc.textPrimary),
              children: [
                TextSpan(
                  text: '${rod.toY.toStringAsFixed(2)} ${widget.yAxisLabel}',
                  style: rc.monoMd,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({required this.rc, required this.title});
  final SkinTokens rc;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: rc.accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: rc.accentGlow,
            ),
          ),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: rc.labelSm.copyWith(color: rc.textPrimary)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.rc, required this.title});
  final SkinTokens rc;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
        height: 120,
        decoration: rc.terminalBox,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, color: rc.textMuted, size: 28),
              const SizedBox(height: 8),
              Text('NO DATA  —  ${title.toUpperCase()}', style: rc.labelSm),
            ],
          ),
        ),
      );
}
