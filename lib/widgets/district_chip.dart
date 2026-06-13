// lib/widgets/district_chip.dart
import 'package:flutter/material.dart';

class DistrictChip extends StatelessWidget {
  final String district;
  final bool selected;
  final VoidCallback? onTap;

  const DistrictChip({
    super.key,
    required this.district,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(district, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
        backgroundColor: selected ? Theme.of(context).colorScheme.primary : null,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
