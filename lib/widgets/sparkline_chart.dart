// lib/widgets/sparkline_chart.dart
// SparklineChart  —  lightweight river level trend line drawn with CustomPainter.
// Uses zero external packages (no fl_chart dependency required).
// Shows: filled area gradient, warning line, danger line, current-level dot.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/river_monitoring.dart';
import '../theme/river_theme.dart';

class SparklineChart extends StatelessWidget {
  final List<RiverLevelSnapshot> snapshots;
  final double warningLevel;
  final double dangerLevel;
  final Color color;
  final double height;
  final bool showLabels;

  const SparklineChart({
    super.key,
    required this.snapshots,
    required this.warningLevel,
    required this.dangerLevel,
    required this.color,
    this.height = 48,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshots.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(
          snapshots: snapshots,
          warningLevel: warningLevel,
          dangerLevel: dangerLevel,
          color: color,
          showLabels: showLabels,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<RiverLevelSnapshot> snapshots;
  final double warningLevel;
  final double dangerLevel;
  final Color color;
  final bool showLabels;

  const _SparkPainter({
    required this.snapshots,
    required this.warningLevel,
    required this.dangerLevel,
    required this.color,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;

    final levels = snapshots.map((s) => s.level).toList();
    final minL = levels.reduce(math.min);
    // Ensure ceiling is at least danger level so lines render in range
    final maxL =
        math.max(levels.reduce(math.max), math.max(dangerLevel, warningLevel));
    final range = (maxL - minL).abs();
    if (range == 0) return;

    double xOf(int i) => i / (snapshots.length - 1) * size.width;
    double yOf(double v) => size.height - ((v - minL) / range * size.height);

    // ── Build line path ──────────────────────────────────────────────────
    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(levels[0]));
    for (var i = 1; i < levels.length; i++) {
      // Smooth with cubic bezier
      final x0 = xOf(i - 1), y0 = yOf(levels[i - 1]);
      final x1 = xOf(i), y1 = yOf(levels[i]);
      final cx = (x0 + x1) / 2;
      linePath.cubicTo(cx, y0, cx, y1, x1, y1);
    }

    // ── Fill path (area under curve) ─────────────────────────────────────
    final fillPath = Path.from(linePath)
      ..lineTo(xOf(levels.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // ── Line stroke ──────────────────────────────────────────────────────
    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // ── Warning line ─────────────────────────────────────────────────────
    if (warningLevel >= minL && warningLevel <= maxL) {
      final wy = yOf(warningLevel);
      canvas.drawLine(
        Offset(0, wy),
        Offset(size.width, wy),
        Paint()
          ..color = AppPalette.warning.withValues(alpha: 0.55)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
      if (showLabels) _drawLabel(canvas, size, wy, 'W', AppPalette.warning);
    }

    // ── Danger line ──────────────────────────────────────────────────────
    if (dangerLevel >= minL && dangerLevel <= maxL) {
      final dy = yOf(dangerLevel);
      canvas.drawLine(
        Offset(0, dy),
        Offset(size.width, dy),
        Paint()
          ..color = AppPalette.danger.withValues(alpha: 0.55)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
      if (showLabels) _drawLabel(canvas, size, dy, 'D', AppPalette.danger);
    }

    // ── Current dot (last point) ─────────────────────────────────────────
    final lastX = xOf(levels.length - 1);
    final lastY = yOf(levels.last);
    canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()..color = color);
    canvas.drawCircle(
      Offset(lastX, lastY),
      3.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawLabel(Canvas canvas, Size size, double y, String text, Color col) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: col,
          fontSize: 7,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height - 1));
  }

  @override
  bool shouldRepaint(_SparkPainter o) =>
      o.snapshots != snapshots || o.color != color;
}
