// lib/widgets/ops_bar_chart.dart
// OpsFlood — OpsBarChart widget v1
// Vertical bar chart — used on Dashboard city risk grid & Predict screen.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class OpsBarChart extends StatelessWidget {
  final List<double>  values;
  final List<String>  labels;
  final List<Color>?  colors;      // per-bar color (optional)
  final Color         defaultColor;
  final double        maxY;
  final String        yUnit;
  final double        barWidth;
  final double        height;

  const OpsBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.colors,
    this.defaultColor = AppPalette.cyan,
    this.maxY         = 100,
    this.yUnit        = '%',
    this.barWidth     = 16,
    this.height       = 160,
  });

  Color _colorFor(int i, double v) {
    if (colors != null && i < colors!.length) return colors![i];
    if (v >= 70) return AppPalette.critical;
    if (v >= 45) return AppPalette.danger;
    if (v >= 25) return AppPalette.warning;
    return defaultColor;
  }

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppPalette.abyss3,
              // tooltipRoundedRadius was removed in fl_chart ≥0.68; use tooltipBorderRadius.
              tooltipRoundedRadius: 10,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)}$yUnit',
                TextStyle(
                  color: _colorFor(group.x, rod.toY),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i].length > 6 ? labels[i].substring(0, 6) : labels[i],
                      style: const TextStyle(
                        fontSize: 8, color: AppPalette.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppPalette.abyssStroke.withValues(alpha: 0.8),
              strokeWidth: 0.5,
              dashArray: [4, 6],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: values.asMap().entries.map((e) {
            final i = e.key;
            final v = e.value;
            final c = _colorFor(i, v);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: v,
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      c.withValues(alpha: 0.6),
                      c,
                    ],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: c.withValues(alpha: 0.05),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
