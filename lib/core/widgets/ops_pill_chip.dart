import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class OpsPillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? activeColor;

  const OpsPillChip({super.key, required this.label, this.selected = false, this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    final active = activeColor ?? c.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? active.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? active : c.surfaceOutline),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? active : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
        ),
      ),
    );
  }
}
