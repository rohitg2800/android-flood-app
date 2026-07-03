// lib/widgets/universe_splash_painter.dart
// Universe-theme boot animation — generative deep-space starfield.
// _Star is exported (public) so splash_screen.dart can use it.

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Public star model ────────────────────────────────────────────────────────
// Must be public (no leading _) so splash_screen.dart can declare List<StarParticle>.

class StarParticle {
  StarParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.layer,
    required this.twinkleOffset,
  });

  double x, y;
  final double radius;
  final double opacity;
  final int layer; // 0=far (slow), 1=mid, 2=near (fast)
  final double twinkleOffset;
}

// ─── Factory ──────────────────────────────────────────────────────────────────

List<StarParticle> buildStarField(int count, Size size) {
  final rng = math.Random(42);
  return List.generate(count, (_) {
    final layer = rng.nextInt(3);
    return StarParticle(
      x: rng.nextDouble() * size.width,
      y: rng.nextDouble() * size.height,
      radius: 0.4 +
          rng.nextDouble() *
              (layer == 2
                  ? 1.8
                  : layer == 1
                      ? 1.2
                      : 0.7),
      opacity: 0.3 + rng.nextDouble() * 0.7,
      layer: layer,
      twinkleOffset: rng.nextDouble() * math.pi * 2,
    );
  });
}

// ─── CustomPainter ────────────────────────────────────────────────────────────

class UniversePainter extends CustomPainter {
  UniversePainter({
    required this.animation,
    required this.stars,
    required this.coreGlow,
    required this.fadeOut,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<StarParticle> stars;
  final Animation<double> coreGlow;
  final double fadeOut; // 0=visible → 1=transparent

  static const _bgColor = Color(0xFF030508);
  static const _coreColor1 = Color(0xFF00FFB2);
  static const _coreColor2 = Color(0xFF004FFF);
  static const _coreColor3 = Color(0xFF9B00FF);

  // Parallax drift speed per layer
  static const _layerSpeed = [0.003, 0.007, 0.013];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final master = 1.0 - fadeOut;

    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _bgColor.withValues(alpha: master),
    );
    if (master < 0.01) return;

    final cx = size.width * 0.5;
    final cy = size.height * 0.46;

    // Starfield with parallax
    for (final s in stars) {
      final drift = _layerSpeed[s.layer] * t * size.width;
      final sx = (s.x + drift) % size.width;
      final twinkle = 0.6 + 0.4 * math.sin(t * math.pi * 6 + s.twinkleOffset);
      final alpha = (s.opacity * twinkle * master).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(sx, s.y),
        s.radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // Galactic core
    final pulse = coreGlow.value;
    final coreR = size.width * (0.18 + 0.04 * pulse);
    final glowR = size.width * (0.38 + 0.06 * pulse);

    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _coreColor1.withValues(alpha: 0.12 * master),
            _coreColor3.withValues(alpha: 0.05 * master),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR)),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      coreR * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _coreColor2.withValues(alpha: 0.20 * master),
            _coreColor1.withValues(alpha: 0.08 * master),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: coreR * 1.6)),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95 * master),
            _coreColor1.withValues(alpha: 0.70 * master),
            _coreColor2.withValues(alpha: 0.30 * master),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: coreR)),
    );

    _drawLensFlare(canvas, Offset(cx, cy), master);
  }

  void _drawLensFlare(Canvas canvas, Offset center, double alpha) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 * alpha)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const len = 40.0;
    canvas.drawLine(center.translate(-len, 0), center.translate(len, 0), paint);
    canvas.drawLine(center.translate(0, -len), center.translate(0, len), paint);
    canvas.drawLine(center.translate(-len * .7, -len * .7),
        center.translate(len * .7, len * .7), paint);
    canvas.drawLine(center.translate(len * .7, -len * .7),
        center.translate(-len * .7, len * .7), paint);
  }

  @override
  bool shouldRepaint(UniversePainter old) =>
      old.fadeOut != fadeOut || old.animation.value != animation.value;
}
