// lib/widgets/risk_score_gauge.dart
import 'package:flutter/material.dart';

enum RiskZone { low, moderate, high, veryHigh, extreme }

class RiskScoreGauge extends StatelessWidget {
  final double score; // 0–100
  final String label;

  const RiskScoreGauge({super.key, required this.score, this.label = ''});

  RiskZone get _zone {
    if (score >= 90) return RiskZone.extreme;
    if (score >= 70) return RiskZone.veryHigh;
    if (score >= 50) return RiskZone.high;
    if (score >= 30) return RiskZone.moderate;
    return RiskZone.low;
  }

  Color _colorForZone(RiskZone zone) {
    switch (zone) {
      case RiskZone.low:
        return const Color(0xFF4CAF50);
      case RiskZone.moderate:
        return const Color(0xFFFFC107);
      case RiskZone.high:
        return const Color(0xFFFF9800);
      case RiskZone.veryHigh:
        return const Color(0xFFFF5722);
      case RiskZone.extreme:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForZone(_zone);
    final pct = score.clamp(0.0, 100.0) / 100;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 10,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              score.toStringAsFixed(0),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12))
        ],
      ],
    );
  }
}
