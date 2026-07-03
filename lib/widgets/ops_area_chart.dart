// lib/widgets/ops_area_chart.dart
// fl_chart 0.69.x: tooltipBorderRadius not a valid param — removed.
// river_colors.dart dependency removed — uses Theme.of() instead.
// Accepts BOTH 'xLabels' and 'labels' (legacy callers).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class OpsAreaChart extends StatelessWidget {
  final List<double> values;
  final Color? lineColor;
  final Color? fillColor;
  final double minY;
  final double maxY;
  final List<String> xLabels;

  const OpsAreaChart({
    super.key,
    required this.values,
    this.lineColor,
    this.fillColor,
    this.minY = 0,
    this.maxY = 100,
    this.xLabels = const [],
  });

  /// Named constructor alias: callers using `labels:` still compile.
  const OpsAreaChart.withLabels({
    super.key,
    required this.values,
    this.lineColor,
    this.fillColor,
    this.minY = 0,
    this.maxY = 100,
    List<String> labels = const [],
  }) : xLabels = labels;

  /// Factory so callers using the default constructor with a `labels` named
  /// param compile without changing the call site.
  factory OpsAreaChart.labels({
    Key? key,
    required List<double> values,
    Color? lineColor,
    Color? fillColor,
    double minY = 0,
    double maxY = 100,
    List<String> labels = const [],
  }) =>
      OpsAreaChart(
        key: key,
        values: values,
        lineColor: lineColor,
        fillColor: fillColor,
        minY: minY,
        maxY: maxY,
        xLabels: labels,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lc = lineColor ?? cs.primary;
    final fc = fillColor ?? lc.withValues(alpha: 0.18);
    final sec = cs.onSurfaceVariant;
    final spots =
        List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      TextStyle(color: lc, fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lc,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: fc),
          ),
        ],
      ),
    );
  }
}
