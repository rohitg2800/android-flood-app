// lib/widgets/dashboard/hero_section.dart
// Extracted from dashboard_screen.dart — arc gauge + status counters + ticker.
import 'package:flutter/material.dart';
import '../../models/flood_data.dart';

class HeroSection extends StatelessWidget {
  final Animation<double> arcAnim;
  final Animation<double> pulseAnim;
  final double overallRisk;
  final int critical;
  final int severe;
  final int moderate;
  final int safe;
  final int total;
  final List<FloodData> alertCities;
  final int tickerIdx;

  const HeroSection({
    super.key,
    required this.arcAnim,
    required this.pulseAnim,
    required this.overallRisk,
    required this.critical,
    required this.severe,
    required this.moderate,
    required this.safe,
    required this.total,
    required this.alertCities,
    required this.tickerIdx,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Risk gauge
          AnimatedBuilder(
            animation: arcAnim,
            builder: (_, __) => _RiskGauge(
              progress: arcAnim.value,
              risk: overallRisk,
            ),
          ),
          const SizedBox(height: 16),
          // Status counters row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CountChip(label: 'CRITICAL', count: critical, color: Colors.red),
              _CountChip(label: 'SEVERE', count: severe, color: Colors.orange),
              _CountChip(
                  label: 'MODERATE', count: moderate, color: Colors.amber),
              _CountChip(label: 'LOW', count: safe, color: Colors.green),
            ],
          ),
          // Alert ticker
          if (alertCities.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AlertTicker(
                cities: alertCities, idx: tickerIdx, pulseAnim: pulseAnim)
          ],
        ],
      ),
    );
  }
}

class _RiskGauge extends StatelessWidget {
  final double progress;
  final double risk;
  const _RiskGauge({required this.progress, required this.risk});

  @override
  Widget build(BuildContext context) {
    final pct = (risk * progress).clamp(0, 100);
    final color = pct >= 75
        ? Colors.red
        : pct >= 50
            ? Colors.orange
            : pct >= 25
                ? Colors.amber
                : Colors.green;
    return Column(
      children: [
        Text(
          '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w800, color: color),
        ),
        Text('Overall Basin Risk',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54)),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Colors.white54, letterSpacing: 0.5)),
      ],
    );
  }
}

class _AlertTicker extends StatelessWidget {
  final List<FloodData> cities;
  final int idx;
  final Animation<double> pulseAnim;
  const _AlertTicker(
      {required this.cities, required this.idx, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final city = cities[idx % cities.length];
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) =>
          Opacity(opacity: 0.6 + 0.4 * pulseAnim.value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 14),
            const SizedBox(width: 6),
            Text(
              '${city.city} — ${city.riskLevel}',
              style: const TextStyle(
                  color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
