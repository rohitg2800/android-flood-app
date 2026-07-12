// lib/widgets/river_level_bar.dart
import 'package:flutter/material.dart';

class RiverLevelBar extends StatelessWidget {
  final double current;
  final double warning;
  final double danger;
  final double hfl;
  final double height;

  const RiverLevelBar({
    super.key,
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final pct = hfl > 0 ? (current / hfl).clamp(0.0, 1.0) : 0.0;
    Color barColor = Colors.green;
    if (current >= danger)
      barColor = Colors.red;
    else if (current >= warning) barColor = Colors.orange;

    return LinearProgressIndicator(
      value: pct,
      minHeight: height,
      backgroundColor: Colors.grey.shade200,
      valueColor: AlwaysStoppedAnimation<Color>(barColor),
    );
  }
}
