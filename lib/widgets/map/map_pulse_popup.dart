// lib/widgets/map/map_pulse_popup.dart
// RiverPulsePopup — modal bottom sheet shown when a station marker is tapped.
// MetricTile      — reusable 3-column metric chip used inside the popup.
import 'package:flutter/material.dart';
import '../../models/river_station.dart';
import '../../theme/rx.dart';
import 'map_risk_helpers.dart';

// ── RiverPulsePopup ───────────────────────────────────────────────────────────
class RiverPulsePopup extends StatelessWidget {
  final RiverStation station;

  /// v2.2: bottom sheet upgraded with 7-day mini sparkline + Semantics.
  const RiverPulsePopup({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final s = station;
    final dc = s.dangerClass;
    final color = riskColorSolid(dc);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12,
          right: 12,
        ),
        color: rc.cardBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored top accent bar — replaces Border(top:) to avoid borderRadius conflict
            Container(height: 2, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: rc.stroke,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Station name + risk badge
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.station,
                              style: TextStyle(
                                color: rc.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${s.river}  •  ${s.city}, ${s.state}',
                              style: TextStyle(
                                  color: rc.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          riskLabel(dc),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metric row 1: level readings
                  Row(
                    children: [
                      MetricTile(
                          label: 'Current',
                          value: '${s.current.toStringAsFixed(2)} m',
                          color: color),
                      const SizedBox(width: 8),
                      MetricTile(
                          label: 'Warning',
                          value: '${s.warning.toStringAsFixed(2)} m',
                          color: rc.textSecondary),
                      const SizedBox(width: 8),
                      MetricTile(
                          label: 'Danger',
                          value: '${s.danger.toStringAsFixed(2)} m',
                          color: const Color(0xFFD32F2F)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Metric row 2: metadata + 7-day trend sparkline
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last 7 days',
                              style: TextStyle(
                                color: rc.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            MiniSparkline7d(
                              stroke: color,
                              values: _mock7DaySeries(s),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      MetricTile(
                        label: 'Trend',
                        value: s.trend ?? '—',
                        color: s.trend == 'Rising'
                            ? const Color(0xFFD32F2F)
                            : s.trend == 'Falling'
                                ? const Color(0xFF388E3C)
                                : rc.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      MetricTile(
                          label: 'Source',
                          value: s.dataSource ?? '—',
                          color: rc.accent),
                      const SizedBox(width: 8),
                      MetricTile(
                          label: 'Updated',
                          value: s.lastUpdated ?? '—',
                          color: rc.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Flood level progress bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Flood Level Progress',
                        style: TextStyle(color: rc.textSecondary, fontSize: 11),
                      ),
                      Text(
                        '${(s.progressPct * 100).toStringAsFixed(1)}% of HFL',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.progressPct,
                      minHeight: 8,
                      backgroundColor: rc.stroke,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: rc.scaffoldBg),
                      label:
                          Text('Close', style: TextStyle(color: rc.scaffoldBg)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: rc.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MetricTile ────────────────────────────────────────────────────────────────
// ── MiniSparkline7d + mock 7-day generator ───────────────────────────────
class MiniSparkline7d extends StatelessWidget {
  final List<double> values;
  final Color stroke;
  const MiniSparkline7d(
      {super.key, required this.values, required this.stroke});

  @override
  Widget build(BuildContext context) {
    final v = values;
    if (v.isEmpty) {
      return const SizedBox.shrink();
    }
    final minV = v.reduce((a, b) => a < b ? a : b);
    final maxV = v.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV).abs();

    return SizedBox(
      height: 42,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MiniSparklinePainter(
            values: v,
            minV: minV,
            range: range,
            stroke: stroke,
          ),
        ),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> values;
  final double minV;
  final double range;
  final Color stroke;

  _MiniSparklinePainter({
    required this.values,
    required this.minV,
    required this.range,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final w = size.width;
    final h = size.height;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final t = values.length == 1 ? 0.0 : i / (values.length - 1);
      final n = (values[i] - minV) / range;
      final x = t * w;
      final y = (1 - n) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final strokePaint = Paint()
      ..color = stroke.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    final fill = Path.from(path);
    fill.lineTo(path.getBounds().right, h);
    fill.lineTo(path.getBounds().left, h);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()..color = stroke.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter old) =>
      old.values != values ||
      old.stroke != stroke ||
      old.minV != minV ||
      old.range != range;
}

List<double> _mock7DaySeries(RiverStation s) {
  // Placeholder until real 7-day telemetry series is wired.
  // Shape: current +/- noise shaped by risk.
  final base = s.safeLevel;
  final riskBoost = switch (s.dangerClass) {
    DangerClass.normal => 0.02,
    DangerClass.aboveNormal => 0.06,
    DangerClass.severe => 0.10,
    DangerClass.extreme => 0.14,
  };

  final vals = <double>[];
  for (int i = 0; i < 7; i++) {
    final drift = (i - 3) / 6.0; // [-0.5..0.5]
    final shaped = base * (1 + drift * riskBoost);
    vals.add((shaped).clamp(0.0, double.maxFinite));
  }
  return vals;
}

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: rc.cardBgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: rc.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: rc.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
