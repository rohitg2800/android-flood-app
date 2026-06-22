import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

enum OpsBadgeVariant { danger, warning, success, info, neutral }

class OpsBadge extends StatelessWidget {
  final String label;
  final OpsBadgeVariant variant;

  const OpsBadge({super.key, required this.label, this.variant = OpsBadgeVariant.neutral});

  @override
  Widget build(BuildContext context) {
    final c = RiverTheme.of(context).colors;
    final Color base = switch (variant) {
      OpsBadgeVariant.danger  => c.danger,
      OpsBadgeVariant.warning => c.warning,
      OpsBadgeVariant.success => c.success,
      OpsBadgeVariant.info    => c.info,
      OpsBadgeVariant.neutral => c.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: base.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: base.withOpacity(0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: base, letterSpacing: 0.7),
      ),
    );
  }
}
