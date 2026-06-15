// lib/widgets/ops_area_chart.dart
// fl_chart 0.69.x: tooltipBorderRadius removed (invalid param).
// river_colors.dart dependency removed — uses Theme.of() instead.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class OpsAreaChart extends StatelessWidget {
  final List<double> values;
  final Color?       lineColor;
  final Color?       fillColor;
  final double       minY;
  final double       maxY;
  // Named 'xLabels' here; callers that used 'labels' need updating too —
  // we accept BOTH names via a factory but simplest fix is one canonical param.
  final List<String> xLabels;

  const OpsAreaChart({
    super.key,
    required this.values,
    this.lineColor,
    this.fillColor,
    this.minY = 0,
    this.maxY = 100,
    this.xLabels = const [],
    // Accept 'labels' as alias by shadowing through a named constructor —
    // not possible in const; callers must migrate to xLabels. See below.
  });

  // Named constructor alias so callers using OpsAreaChart(labels: ...) compile.
  const OpsAreaChart.withLabels({
    super.key,
    required this.values,
    this.lineColor,
    this.fillColor,
    this.minY = 0,
    this.maxY = 100,
    List<String> labels = const [],
  }) : xLabels = labels;

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final lc  = lineColor ?? cs.primary;
    final fc  = fillColor ?? lc.withValues(alpha: 0.18);
    final sec = cs.onSurfaceVariant;
    final spots = List.generate(
        values.length, (i) => FlSpot(i.toDouble(), values[i]));

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData:   const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:   const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles:  const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles:    const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: xLabels.isNotEmpty,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= xLabels.length) {
                  return const SizedBox.shrink();
                }
                return Text(xLabels[idx],
                    style: TextStyle(color: sec, fontSize: 10));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      s.y.toStringAsFixed(2),
                      TextStyle(
                          color: lc, fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots:        spots,
            isCurved:     true,
            color:        lc,
            barWidth:     2.5,
            dotData:      const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: fc),
          ),
        ],
      ),
    );
  }
}
