import 'package:flutter/material.dart';

class WaterLevelStatusBadge extends StatelessWidget {
  const WaterLevelStatusBadge({
    super.key,
    required this.label,
  });

  final String label;

  Color _backgroundColor() {
    switch (label.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'danger':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: _backgroundColor(),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}
