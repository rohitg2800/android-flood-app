// lib/widgets/risk_heatmap.dart
// OpsFlood — RiskHeatmap v3  (Abyss Ops)
// State × risk-level grid with animated cell glow.
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class RiskHeatmapEntry {
  final String state;
  final String level; // 'SAFE' | 'WARNING' | 'DANGER' | 'CRITICAL'
  final int count;

  const RiskHeatmapEntry({
    required this.state,
    required this.level,
    required this.count,
  });
}

class RiskHeatmap extends StatelessWidget {
  final List<RiskHeatmapEntry> entries;
  const RiskHeatmap({super.key, required this.entries});

  static Color _color(String level) => AppPalette.statusColor(level);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppPalette.abyssStroke),
        ),
        child: const Center(
          child: Text(
            'No risk data available',
            style: TextStyle(color: AppPalette.textGrey, fontSize: 13),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppPalette.cyan,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'State Risk Matrix',
              style: TextStyle(
                color: AppPalette.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.map((e) {
              final col = _color(e.level);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: col.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.state.length > 12
                          ? '${e.state.substring(0, 12)}…'
                          : e.state,
                      style: TextStyle(
                        color: col,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.count} station${e.count != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppPalette.textGrey,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // legend
          Row(
            children: ['SAFE', 'WARNING', 'DANGER', 'CRITICAL']
                .map((l) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _color(l),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l,
                            style: const TextStyle(
                              color: AppPalette.textGrey,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
