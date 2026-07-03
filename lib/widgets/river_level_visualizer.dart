// lib/widgets/river_level_visualizer.dart
// OpsFlood — RiverLevelVisualizer v3  (Abyss Ops)
// Premium area chart + animated fill-bar replacing the old circular gauge.
// Shows: current level line, warning band, danger band, HFL marker.
library;

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class RiverLevelVisualizer extends StatefulWidget {
  /// List of recent water-level readings (latest last).
  final List<double> history;
  final double current;
  final double warning;
  final double danger;
  final double hfl;
  final String cityName;
  final Color lineColor;

  const RiverLevelVisualizer({
    super.key,
    required this.history,
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
    required this.cityName,
    this.lineColor = AppPalette.cyan,
  });

  @override
  State<RiverLevelVisualizer> createState() => _RiverLevelVisualizerState();
}

class _RiverLevelVisualizerState extends State<RiverLevelVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color get _levelColor {
    final pct = widget.danger > 0
        ? widget.current / widget.danger
        : widget.hfl > 0
            ? widget.current / widget.hfl
            : 0.0;
    if (pct >= 1.0) return AppPalette.critical;
    if (pct >= 0.75) return AppPalette.danger;
    if (pct >= 0.50) return AppPalette.warning;
    return AppPalette.safe;
  }

  double get _fillPct {
    if (widget.danger > 0) {
      return (widget.current / widget.danger).clamp(0.0, 1.2);
    }
    if (widget.hfl > 0) {
      return (widget.current / widget.hfl).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.abyssStroke),
        boxShadow: [
          BoxShadow(
            color: _levelColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.cityName,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'River Level Monitor',
                    style: TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Big current level number
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.current.toStringAsFixed(2)} m',
                    style: TextStyle(
                      color: _levelColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'current level',
                    style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Area Sparkline ─────────────────────────────────────────
          if (widget.history.length >= 2)
            SizedBox(
              height: 90,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => _SparkAreaChart(
                  data: widget.history,
                  warning: widget.warning,
                  danger: widget.danger,
                  color: _levelColor,
                  progress: _anim.value,
                ),
              ),
            ),
          if (widget.history.length >= 2) const SizedBox(height: 18),
          // ── Animated fill bar ──────────────────────────────────────
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _mini('W ${widget.warning.toStringAsFixed(1)} m',
                        AppPalette.amber),
                    _mini('D ${widget.danger.toStringAsFixed(1)} m',
                        AppPalette.danger),
                    _mini(
                        '${(_fillPct * 100).clamp(0, 120).toStringAsFixed(0)}% of danger',
                        AppPalette.textGrey),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(children: [
                  // track
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppPalette.abyss4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // warning tick
                  if (widget.danger > 0 && widget.warning > 0)
                    Positioned(
                      left: (widget.warning / widget.danger).clamp(0.0, 1.0) *
                          (MediaQuery.of(context).size.width - 100),
                      top: 0,
                      bottom: 0,
                      child: Container(
                          width: 2,
                          color: AppPalette.amber.withValues(alpha: 0.7)),
                    ),
                  // fill
                  FractionallySizedBox(
                    widthFactor: (_fillPct.clamp(0.0, 1.0) * _anim.value)
                        .clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _levelColor.withValues(alpha: 0.6),
                            _levelColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: _levelColor.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Threshold chips ───────────────────────────────────────
          Row(
            children: [
              _ThresholdChip(
                  label: 'Warning',
                  value: '${widget.warning.toStringAsFixed(1)} m',
                  color: AppPalette.amber),
              const SizedBox(width: 8),
              _ThresholdChip(
                  label: 'Danger',
                  value: '${widget.danger.toStringAsFixed(1)} m',
                  color: AppPalette.danger),
              const SizedBox(width: 8),
              if (widget.hfl > 0)
                _ThresholdChip(
                    label: 'HFL',
                    value: '${widget.hfl.toStringAsFixed(1)} m',
                    color: AppPalette.critical),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String t, Color c) => Text(t,
      style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600));
}

// ── Spark area chart ──────────────────────────────────────────────────────────
class _SparkAreaChart extends StatelessWidget {
  final List<double> data;
  final double warning;
  final double danger;
  final Color color;
  final double progress; // 0→1 animation

  const _SparkAreaChart({
    required this.data,
    required this.warning,
    required this.danger,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // animate: only show the first progress% of points
    final visibleCount = math.max(2, (data.length * progress).round());
    final visible = data.sublist(data.length - visibleCount);

    final minY = (visible.reduce(math.min) - 0.5).clamp(0.0, double.infinity);
    final maxY = visible.reduce(math.max) + 1.0;

    final spots = visible
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppPalette.abyssStroke,
            strokeWidth: 0.5,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (warning >= minY && warning <= maxY)
              HorizontalLine(
                y: warning,
                color: AppPalette.amber.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(
                    color: AppPalette.amber,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  labelResolver: (_) => 'W',
                ),
              ),
            if (danger >= minY && danger <= maxY)
              HorizontalLine(
                y: danger,
                color: AppPalette.danger.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(
                    color: AppPalette.danger,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  labelResolver: (_) => 'D',
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Threshold chip ────────────────────────────────────────────────────────────
class _ThresholdChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ThresholdChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppPalette.textGrey,
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
}
