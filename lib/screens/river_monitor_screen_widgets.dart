// lib/screens/river_monitor_screen_widgets.dart
// Extracted sub-widgets from river_monitor_screen.dart (God-class split)
// All painters, card sub-widgets, and stateless helpers live here.
// river_monitor_screen.dart imports this file.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RipplePainter — animated ripple on the hero header
// ─────────────────────────────────────────────────────────────────────────────
class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  const RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.82;
    final cy = size.height * 0.3;
    for (int i = 0; i < 3; i++) {
      final phase   = (progress + i / 3) % 1.0;
      final radius  = 20 + phase * 100;
      final opacity = (1 - phase) * 0.18;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(RipplePainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// WavePainter — water-fill wave at card bottom
// ─────────────────────────────────────────────────────────────────────────────
class WavePainter extends CustomPainter {
  final Color  color;
  final double opacity;
  const WavePainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 20) {
      path.quadraticBezierTo(x + 10, 0, x + 20, size.height);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter old) =>
      old.color != color || old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// CylinderPainter + Cylinder3D widget
// ─────────────────────────────────────────────────────────────────────────────
class Cylinder3D extends StatelessWidget {
  final double fill;
  final Color  color;
  final double width, height;
  const Cylinder3D({
    super.key,
    required this.fill,
    required this.color,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width, height: height,
        child: CustomPaint(
          painter: _CylinderPainter(fill: fill, color: color),
        ),
      );
}

class _CylinderPainter extends CustomPainter {
  final double fill;
  final Color color;
  const _CylinderPainter({required this.fill, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final rx = w / 2;
    final ry = rx * 0.35;

    final bodyPath = Path()
      ..moveTo(0, ry)
      ..lineTo(0, h - ry)
      ..addArc(Rect.fromLTWH(0, h - ry * 2, w, ry * 2), 0, math.pi)
      ..lineTo(w, ry)
      ..addArc(Rect.fromLTWH(0, 0, w, ry * 2), 0, -math.pi)
      ..close();

    canvas.drawPath(bodyPath,
        Paint()..color = color.withOpacity(0.12)..style = PaintingStyle.fill);

    if (fill > 0) {
      final fillTop = h - ry - (h - ry * 2) * fill.clamp(0.0, 1.0);
      final fillPath = Path()
        ..moveTo(0, fillTop + ry)
        ..lineTo(0, h - ry)
        ..addArc(Rect.fromLTWH(0, h - ry * 2, w, ry * 2), 0, math.pi)
        ..lineTo(w, fillTop + ry)
        ..addArc(Rect.fromLTWH(0, fillTop, w, ry * 2), 0, -math.pi)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            colors: [color, color.withOpacity(0.6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, fillTop, w, h - fillTop))
          ..style = PaintingStyle.fill,
      );

      canvas.drawOval(
        Rect.fromLTWH(0, fillTop, w, ry * 2),
        Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawOval(
      Rect.fromLTWH(0, 0, w, ry * 2),
      Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_CylinderPainter old) =>
      old.fill != fill || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// StatTile — single stat box in the hero header row
// ─────────────────────────────────────────────────────────────────────────────
class StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RmBreachBanner — breach prediction banner inside a river card
// ─────────────────────────────────────────────────────────────────────────────
class RmBreachBanner extends StatelessWidget {
  final double? peak;
  const RmBreachBanner({super.key, this.peak});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF1744).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF1744).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.crisis_alert_rounded,
              color: Color(0xFFFF1744), size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              peak != null
                  ? 'BREACH PREDICTED within 72h  ·  Peak ${peak!.toStringAsFixed(2)} m'
                  : 'DANGER LEVEL BREACH PREDICTED within 72h',
              style: const TextStyle(
                  color: Color(0xFFFF1744),
                  fontSize: 10,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RmFillBar — animated water-fill progress bar
// ─────────────────────────────────────────────────────────────────────────────
class RmFillBar extends StatelessWidget {
  final double fillPct;
  final double fillValue; // animated 0-1
  final Color rc;
  final RiverColors t;
  const RmFillBar({
    super.key,
    required this.fillPct,
    required this.fillValue,
    required this.rc,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Fill',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '${fillPct.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: rc,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 7, color: t.divider.withOpacity(0.3)),
              FractionallySizedBox(
                widthFactor: fillValue,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [rc, rc.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RmMlScoreBar — ML risk score progress bar
// ─────────────────────────────────────────────────────────────────────────────
class RmMlScoreBar extends StatelessWidget {
  final num riskScore;
  final double? confidence;
  final RiverColors t;
  const RmMlScoreBar({
    super.key,
    required this.riskScore,
    this.confidence,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final score = riskScore.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.query_stats_rounded,
                color: Color(0xFF7B2FF7), size: 11),
            const SizedBox(width: 4),
            Text('ML Risk: ${riskScore.toStringAsFixed(0)} / 100',
                style: const TextStyle(
                    color: Color(0xFF7B2FF7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (confidence != null)
              Text('Conf ${confidence!.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (score / 100.0).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor:
                const Color(0xFF7B2FF7).withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(
              score >= 80
                  ? const Color(0xFFFF1744)
                  : score >= 60
                      ? const Color(0xFFFF6D00)
                      : const Color(0xFF7B2FF7),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RmChip — inline stat chip (level / danger / peak)
// ─────────────────────────────────────────────────────────────────────────────
class RmChip extends StatelessWidget {
  final RiverColors t;
  final IconData icon;
  final String label, value;
  final Color color;
  const RmChip({
    super.key,
    required this.t,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 9,
                    letterSpacing: 0.4)),
          ],
        ),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RmEmptyState — shown when no stations match
// ─────────────────────────────────────────────────────────────────────────────
class RmEmptyState extends StatelessWidget {
  final RiverColors t;
  final String query;
  const RmEmptyState({super.key, required this.t, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_outlined, size: 64,
                color: t.accent.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? 'No results for "$query"'
                  : 'No river data available',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty
                  ? 'Try a different search term'
                  : 'Pull down to refresh',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RmStatusBanner — offline / last-updated banner
// ─────────────────────────────────────────────────────────────────────────────
class RmStatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final RiverColors t;
  const RmStatusBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RmSummaryStrip — chip row showing counts
// ─────────────────────────────────────────────────────────────────────────────
class RmSummaryStrip extends StatelessWidget {
  final RiverColors t;
  final int total, crit, sev, norm, breach;
  const RmSummaryStrip({
    super.key,
    required this.t,
    required this.total,
    required this.crit,
    required this.sev,
    required this.norm,
    required this.breach,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _chip(t.accent,                      Icons.water,                 '$total stations'),
        if (crit   > 0) _chip(AppPalette.critical,  Icons.warning_amber_rounded, '$crit critical'),
        if (sev    > 0) _chip(AppPalette.danger,     Icons.warning_rounded,       '$sev severe'),
        if (norm   > 0) _chip(AppPalette.safe,       Icons.check_circle_outline,  '$norm normal'),
        if (breach > 0) _chip(const Color(0xFFFF1744), Icons.crisis_alert_rounded, '$breach breach↑'),
      ],
    );
  }

  Widget _chip(Color c, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: c,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
