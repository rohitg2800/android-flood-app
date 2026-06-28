// lib/widgets/flood_risk_heatmap.dart
// OpsFlood — Module 13: Flood Risk Heatmap Overlay
//
// A self-contained widget that paints a colour-graded risk heatmap
// over a Flutter CustomPaint canvas (no map SDK required).
// To use over Google Maps, wrap in a GoogleMap `overlays` or
// render via tile-overlay / GroundOverlay using toImage().
//
// Usage:
//   FloodRiskHeatmap(
//     stations: stationList,   // List<HeatmapStation>
//     width:  mapWidth,
//     height: mapHeight,
//     latMin: 24.3, latMax: 27.5,
//     lngMin: 83.3, lngMax: 88.5,
//   )

import 'dart:math' as math;
import 'dart:ui'   as ui;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class HeatmapStation {
  final double lat;
  final double lng;
  /// 0.0 (safe) … 1.0 (at/above danger level)
  final double riskScore;
  final String label;
  const HeatmapStation({
    required this.lat,
    required this.lng,
    required this.riskScore,
    required this.label,
  });
}

// ---------------------------------------------------------------------------
// Risk colour ramp (green → yellow → orange → red)
// ---------------------------------------------------------------------------

Color _riskColor(double score) {
  if (score < 0.33) {
    return Color.lerp(
        const Color(0xFF4CAF50),
        const Color(0xFFFFEB3B),
        score / 0.33)!;
  } else if (score < 0.66) {
    return Color.lerp(
        const Color(0xFFFFEB3B),
        const Color(0xFFFF9800),
        (score - 0.33) / 0.33)!;
  } else {
    return Color.lerp(
        const Color(0xFFFF9800),
        const Color(0xFFFF1744),
        (score - 0.66) / 0.34)!;
  }
}

// ---------------------------------------------------------------------------
// FloodRiskHeatmap widget
// ---------------------------------------------------------------------------

class FloodRiskHeatmap extends StatelessWidget {
  final List<HeatmapStation> stations;
  final double width;
  final double height;
  final double latMin;
  final double latMax;
  final double lngMin;
  final double lngMax;
  /// Radius (in pixels) of each Gaussian blob. Default: 60.
  final double blobRadius;
  /// Overall opacity of the heatmap layer. Default: 0.55.
  final double opacity;
  /// Whether to show station labels. Default: true.
  final bool showLabels;

  const FloodRiskHeatmap({
    super.key,
    required this.stations,
    required this.width,
    required this.height,
    required this.latMin,
    required this.latMax,
    required this.lngMin,
    required this.lngMax,
    this.blobRadius  = 60.0,
    this.opacity     = 0.55,
    this.showLabels  = true,
  });

  Offset _project(double lat, double lng) {
    final x = (lng - lngMin) / (lngMax - lngMin) * width;
    final y = (1 - (lat - latMin) / (latMax - latMin)) * height;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size(width, height),
        painter: _HeatmapPainter(
          stations:   stations,
          project:    _project,
          blobRadius: blobRadius,
          showLabels: showLabels,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _HeatmapPainter extends CustomPainter {
  final List<HeatmapStation> stations;
  final Offset Function(double lat, double lng) project;
  final double blobRadius;
  final bool   showLabels;

  _HeatmapPainter({
    required this.stations,
    required this.project,
    required this.blobRadius,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stations) {
      final center = project(s.lat, s.lng);
      final color  = _riskColor(s.riskScore);

      // Gaussian radial gradient blob
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          blobRadius,
          [
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.40),
            color.withValues(alpha: 0.0),
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawCircle(center, blobRadius, paint);

      // Station dot
      canvas.drawCircle(
        center,
        5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        center,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label
      if (showLabels) {
        final tp = TextPainter(
          text: TextSpan(
            text: s.label,
            style: TextStyle(
              color:      Colors.white,
              fontSize:   10,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(
                    blurRadius: 3,
                    color: Colors.black87),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            center +
                Offset(-tp.width / 2, 7));
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.stations != stations ||
      old.blobRadius != blobRadius;
}

// ---------------------------------------------------------------------------
// Legend widget (place alongside the heatmap)
// ---------------------------------------------------------------------------

class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Flood Risk',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _legendRow(const Color(0xFF4CAF50), 'Low  (0–33%)'),
          _legendRow(const Color(0xFFFFEB3B), 'Moderate (33–66%)'),
          _legendRow(const Color(0xFFFF9800), 'High (66–85%)'),
          _legendRow(const Color(0xFFFF1744), 'Critical (>85%)'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color:  color,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10)),
          ],
        ),
      );
}
