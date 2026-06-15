// lib/widgets/river_level_chip.dart
//
// RiverLevelChip — small inline chip showing a river level reading
// with a colour-coded background matching the station's risk level.

import 'package:flutter/material.dart';

class RiverLevelChip extends StatelessWidget {
  /// The current river level in metres.
  final double? level;

  /// The danger threshold in metres (used to compute percentage fill).
  final double? dangerLevel;

  /// Override the auto-computed colour.
  final Color? color;

  /// Compact mode: show only the numeric value without label text.
  final bool compact;

  const RiverLevelChip({
    super.key,
    this.level,
    this.dangerLevel,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final lvl = level;
    final dan = dangerLevel;

    final Color chipColor = color ?? _computeColor(lvl, dan);
    final String text     = lvl != null ? '${lvl.toStringAsFixed(2)} m' : '—';

    if (compact) {
      return Text(
        text,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static Color _computeColor(double? level, double? danger) {
    if (level == null || danger == null || danger <= 0) return Colors.grey;
    final pct = level / danger;
    if (pct >= 1.0)  return Colors.red;
    if (pct >= 0.90) return Colors.deepOrange;
    if (pct >= 0.75) return Colors.orange;
    return Colors.green;
  }
}
