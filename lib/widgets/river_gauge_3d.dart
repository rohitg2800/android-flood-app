// lib/widgets/river_gauge_3d.dart
// PHASE 3 — Animated 3-D river gauge column used in RiverMonitorScreen cards
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// A compact animated vertical gauge that shows water fill level.
///
/// Usage:
/// ```dart
/// RiverGauge3D(
///   progressPct: station.progressPct,   // 0–100
///   height: 80,
///   width: 28,
/// )
/// ```
class RiverGauge3D extends StatefulWidget {
  final double progressPct; // 0–100
  final double height;
  final double width;
  final bool animate;

  const RiverGauge3D({
    super.key,
    required this.progressPct,
    this.height = 72,
    this.width = 24,
    this.animate = true,
  });

  @override
  State<RiverGauge3D> createState() => _RiverGauge3DState();
}

class _RiverGauge3DState extends State<RiverGauge3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fillAnim;
  late Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fillAnim = Tween<double>(
      begin: 0,
      end: (widget.progressPct / 100).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _waveAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(),
    );

    if (widget.animate) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(RiverGauge3D old) {
    super.didUpdateWidget(old);
    if (old.progressPct != widget.progressPct) {
      _fillAnim = Tween<double>(
        begin: _fillAnim.value,
        end: (widget.progressPct / 100).clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _fillColor {
    final pct = widget.progressPct;
    if (pct >= 100) return AppPalette.critical;
    if (pct >= 80) return AppPalette.danger;
    if (pct >= 60) return AppPalette.warning;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _fillAnim,
        builder: (_, __) => CustomPaint(
          painter: _GaugePainter(
            fill: _fillAnim.value,
            fillColor: _fillColor,
            wave: _waveAnim.value,
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fill; // 0–1
  final Color fillColor;
  final double wave; // radians for wave phase

  _GaugePainter({
    required this.fill,
    required this.fillColor,
    required this.wave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = Radius.circular(w * 0.35);

    // ── Outer shell (dark tube) ──────────────────────────────────────────
    final shellPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppPalette.abyss3,
          AppPalette.abyss2,
          AppPalette.abyss4,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      shellPaint,
    );

    // ── Tick marks ──────────────────────────────────────────────────────
    final tickPaint = Paint()
      ..color = AppPalette.abyssStroke.withValues(alpha: 0.6)
      ..strokeWidth = 0.8;
    for (int i = 1; i < 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(w * 0.6, y), Offset(w * 0.85, y), tickPaint);
    }

    // ── Water fill ──────────────────────────────────────────────────────
    if (fill > 0.01) {
      final fillTop = h * (1 - fill);

      // Wave path
      final wavePath = Path();
      wavePath.moveTo(0, fillTop);

      for (double x = 0; x <= w; x++) {
        final y = fillTop + math.sin((x / w * 2 * math.pi) + wave) * 1.5;
        wavePath.lineTo(x, y);
      }
      wavePath.lineTo(w, h);
      wavePath.lineTo(0, h);
      wavePath.close();

      // Clip to rounded rect
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      );

      final waterPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillColor.withValues(alpha: 0.55),
            fillColor.withValues(alpha: 0.90),
          ],
        ).createShader(Rect.fromLTWH(0, fillTop, w, h - fillTop));

      canvas.drawPath(wavePath, waterPaint);

      // Specular highlight stripe
      final glowPaint = Paint()
        ..color = fillColor.withValues(alpha: 0.25)
        ..strokeWidth = w * 0.12
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(w * 0.2, fillTop + 3),
        Offset(w * 0.2, h - 4),
        glowPaint,
      );

      canvas.restore();
    }

    // ── Border ring ─────────────────────────────────────────────────────
    final borderColor =
        fill >= 0.8 ? fillColor.withValues(alpha: 0.7) : AppPalette.abyssStroke;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = fill >= 0.8 ? 1.5 : 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      borderPaint,
    );

    // ── Danger line ──────────────────────────────────────────────────────
    final dangerY = h * 0.2; // top 20% = danger zone marker
    final dangerPaint = Paint()
      ..color = AppPalette.critical.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(w * 0.15, dangerY),
      Offset(w * 0.85, dangerY),
      dangerPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fill != fill || old.wave != wave || old.fillColor != fillColor;
}
