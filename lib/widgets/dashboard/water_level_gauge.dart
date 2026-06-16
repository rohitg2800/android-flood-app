// lib/widgets/dashboard/water_level_gauge.dart
// ═══════════════════════════════════════════════════════════════════════════
// WaterLevelGauge  —  Data Terminal Edition
//
// ✔  Circular arc gauge with glow effect
// ✔  Consumes ThemeRegistry — fully theme-aware
// ✔  Entry animation: radial arc draws in from 0 on first render
// ✔  AnimatedContainer reacts instantly to live data changes
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/river_station.dart';
import '../../theme/theme_registry.dart';

// ─── Public widget ─────────────────────────────────────────────────────────────────
class WaterLevelGauge extends ConsumerStatefulWidget {
  const WaterLevelGauge({
    super.key,
    required this.station,
    this.size = 160.0,
    this.showLabel = true,
  });

  final RiverStation station;
  final double       size;
  final bool         showLabel;

  @override
  ConsumerState<WaterLevelGauge> createState() => _WaterLevelGaugeState();
}

class _WaterLevelGaugeState extends ConsumerState<WaterLevelGauge>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>    _arcAnim; // 0 → target pct

  double _prevPct = 0;

  @override
  void initState() {
    super.initState();
    final rc = ThemeRegistry.of(ref.read(appSkinProvider));
    _ctrl = AnimationController(
        vsync:    this,
        duration: rc.entryDuration);
    _arcAnim = Tween<double>(begin: 0, end: widget.station.progressPct)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _prevPct = widget.station.progressPct;
    Future.microtask(() { if (mounted) _ctrl.forward(); });
  }

  @override
  void didUpdateWidget(WaterLevelGauge old) {
    super.didUpdateWidget(old);
    // When live data changes, smoothly animate to new value
    final newPct = widget.station.progressPct;
    if ((newPct - _prevPct).abs() > 0.001) {
      _ctrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      _prevPct = newPct;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc      = ref.watch(themeRegistryProvider);
    final station = widget.station;
    final lvlColor = station.hasData
        ? rc.levelColor(station.current, station.warning, station.danger)
        : rc.textMuted;
    final pct = station.progressPct.clamp(0.0, 1.0);

    return Container(
      width:       widget.size,
      height:      widget.size,
      decoration:  rc.gaugeBox,
      child: AnimatedBuilder(
        animation: _arcAnim,
        builder: (_, __) => CustomPaint(
          painter: _GaugePainter(
            pct:       (_arcAnim.value * pct).clamp(0.0, 1.0),
            color:     lvlColor,
            trackColor: rc.surfaceHigh,
            glowColor:  lvlColor,
            strokeWidth: widget.size * 0.075,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Monospace level
                TweenAnimationBuilder<double>(
                  tween: Tween(end: station.current),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    v.toStringAsFixed(2),
                    style: rc.monoLg.copyWith(
                      color:    lvlColor,
                      fontSize: widget.size * 0.17,
                    ),
                  ),
                ),
                Text('metres',
                    style: rc.labelXs.copyWith(
                        color: rc.textMuted,
                        fontSize: widget.size * 0.07)),
                const SizedBox(height: 4),
                if (widget.showLabel)
                  Text(
                    station.station.toUpperCase(),
                    style: rc.labelXs.copyWith(
                      color:    rc.textSecondary,
                      fontSize: widget.size * 0.065,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gauge painter ────────────────────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.pct,
    required this.color,
    required this.trackColor,
    required this.glowColor,
    required this.strokeWidth,
  });

  final double pct;
  final Color  color;
  final Color  trackColor;
  final Color  glowColor;
  final double strokeWidth;

  static const _startAngle = math.pi * 0.75;    // 135°
  static const _sweepTotal = math.pi * 1.5;     // 270° arc

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    // — Track (background arc)
    final trackPaint = Paint()
      ..color       = trackColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepTotal, false, trackPaint);

    if (pct <= 0) return;

    // — Glow layer (wider, lower opacity)
    final glowPaint = Paint()
      ..color       = glowColor.withOpacity(0.25)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.0
      ..strokeCap   = StrokeCap.round
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
        rect, _startAngle, _sweepTotal * pct, false, glowPaint);

    // — Fill arc with gradient
    final sweep = _sweepTotal * pct;
    final gradientPaint = Paint()
      ..shader = SweepGradient(
          center:     Alignment.center,
          startAngle: _startAngle,
          endAngle:   _startAngle + sweep,
          colors: [
            color.withOpacity(0.55),
            color,
          ],
        ).createShader(rect)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, sweep, false, gradientPaint);

    // — Tip dot (bright end-cap glow)
    final tipAngle  = _startAngle + sweep;
    final tipOffset = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    final tipPaint = Paint()
      ..color      = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(tipOffset, strokeWidth * 0.6, tipPaint);
    canvas.drawCircle(tipOffset, strokeWidth * 0.35,
        Paint()..color = Colors.white.withOpacity(0.9));
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.pct != pct || old.color != color;
}
