// lib/widgets/ops_area_chart.dart
// fl_chart 0.69.x — tooltipBorderRadius is NOT a valid parameter on
// LineTouchTooltipData in this version; removed to fix compile error.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/river_colors.dart';

class OpsAreaChart extends StatelessWidget {
  final List<double> values;
  final Color?       lineColor;
  final Color?       fillColor;
  final double       minY;
  final double       maxY;
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

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final lc    = lineColor ?? t.river;
    final fc    = fillColor ?? lc.withValues(alpha: 0.18);
    final spots = List.generate(
        values.length, (i) => FlSpot(i.toDouble(), values[i]));

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData:     const FlGridData(show: false),
        borderData:   FlBorderData(show: false),
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
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 10));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // tooltipBorderRadius removed — not a valid param in fl_chart 0.69.x
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
            spots:            spots,
            isCurved:         true,
            color:            lc,
            barWidth:         2.5,
            dotData:          const FlDotData(show: false),
            belowBarData: BarAreaData(
              show:  true,
              color: fc,
            ),
          ),
        ],
      ),
    );
  }
}
