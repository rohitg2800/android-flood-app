// lib/widgets/level_chart.dart
import 'package:flutter/material.dart';

class LevelChart extends StatelessWidget {
  final List<double> levels;
  final double warningLevel;
  final double dangerLevel;
  final String label;

  const LevelChart({
    super.key,
    required this.levels,
    required this.warningLevel,
    required this.dangerLevel,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
              child: Text('Level chart',
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
        ),
      ],
    );
  }
}
