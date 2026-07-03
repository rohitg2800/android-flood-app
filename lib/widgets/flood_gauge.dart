// lib/widgets/flood_gauge.dart
// DEPRECATED — gauge widget removed in Abyss Ops v4.
// Use precision fill-bar in river_monitor_screen.dart instead.
// This stub prevents dangling imports from breaking the build.
library;

import 'package:flutter/material.dart';

/// Stub widget — renders nothing. Kept only to satisfy any remaining
/// import that has not yet been removed. Remove all usages and delete
/// this file once every call site has been migrated.
@Deprecated('Use the inline fill-bar in _LiveCard instead.')
class FloodGauge extends StatelessWidget {
  final double value;
  final double max;
  final Color color;

  const FloodGauge({
    super.key,
    required this.value,
    required this.max,
    this.color = const Color(0xFF00C6FF),
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
