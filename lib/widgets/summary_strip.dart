// lib/widgets/summary_strip.dart
// SummaryStrip — horizontal scrolling chip row showing live station counts
// by severity level. Displayed at the top of DashboardScreen.
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class SummaryStrip extends StatelessWidget {
  final int    critical;
  final int    severe;
  final int    warning;
  final int    safe;
  final int    noData;
  final String lastUpdate;

  const SummaryStrip({
    super.key,
    required this.critical,
    required this.severe,
    required this.warning,
    required this.safe,
    required this.noData,
    this.lastUpdate = '',
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    final chips = [
      _CountChip(label: 'Critical', count: critical, color: AppPalette.critical),
      _CountChip(label: 'Severe',   count: severe,   color: AppPalette.danger),
      _CountChip(label: 'Warning',  count: warning,  color: AppPalette.warning),
      _CountChip(label: 'Safe',     count: safe,     color: AppPalette.safe),
      _CountChip(label: 'No Data',  count: noData,   color: t.textSecondary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: chips
                .map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: c,
                    ))
                .toList(),
          ),
        ),
        if (lastUpdate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              lastUpdate,
              style: TextStyle(fontSize: 11, color: t.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;

  const _CountChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.85), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
