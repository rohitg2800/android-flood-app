// lib/widgets/river_level_chip.dart
// RiverLevelChip — small compact chip showing a station's risk level badge.
// Used by DashboardScreen station rows and city detail cards.
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class RiverLevelChip extends StatelessWidget {
  final String level;   // 'SAFE' | 'WARNING' | 'DANGER' | 'CRITICAL'
  final double? currentLevel;
  final double? dangerLevel;
  final bool compact;

  const RiverLevelChip({
    super.key,
    required this.level,
    this.currentLevel,
    this.dangerLevel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.statusColor(level);

    final levelText = currentLevel != null
        ? '${currentLevel!.toStringAsFixed(1)} m'
        : level;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical:   compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(compact ? 6 : 10),
        border:       Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        levelText,
        style: TextStyle(
          color:      color,
          fontSize:   compact ? 10 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
