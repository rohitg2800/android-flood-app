import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class OpsSectionHeader extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? trailing;

  const OpsSectionHeader({super.key, required this.label, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: c.textMuted), const SizedBox(width: 6)],
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.textMuted, letterSpacing: 1.0, fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
