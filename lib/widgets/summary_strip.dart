// lib/widgets/summary_strip.dart
//
// SummaryStrip — horizontal status bar shown at the top of the dashboard.
// Shows counts of CRITICAL / SEVERE / WARNING / SAFE / NO-DATA stations
// and a 'last updated' label.

import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _chip('CRITICAL', critical, Colors.red),
              _chip('SEVERE',   severe,   Colors.deepOrange),
              _chip('WARNING',  warning,  Colors.orange),
              _chip('SAFE',     safe,     Colors.green),
              if (noData > 0)
                _chip('N/A', noData, Colors.grey),
            ],
          ),
          if (lastUpdate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              lastUpdate,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 9),
        ),
      ],
    );
  }
}
