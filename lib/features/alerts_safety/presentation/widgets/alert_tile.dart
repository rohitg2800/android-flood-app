import "package:flutter/material.dart";
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;
import "package:equinox_flood/core/widgets/ops_badge.dart";

enum AlertTileSeverity { critical, severe, warning }

class AlertTile extends StatelessWidget {
  final String city;
  final String river;
  final String riskLabel;
  final double? currentLevel;
  final double? dangerLevel;
  final AlertTileSeverity severity;
  final VoidCallback? onTap;

  const AlertTile({
    super.key,
    required this.city,
    required this.river,
    required this.riskLabel,
    this.currentLevel,
    this.dangerLevel,
    required this.severity,
    this.onTap,
  });

  Color _color(dynamic c) {
    switch (severity) {
      case AlertTileSeverity.critical: return c.danger;
      case AlertTileSeverity.severe:   return const Color(0xFFFF8C42);
      case AlertTileSeverity.warning:  return c.warning;
    }
  }

  IconData _icon() {
    switch (severity) {
      case AlertTileSeverity.critical: return Icons.crisis_alert_rounded;
      case AlertTileSeverity.severe:   return Icons.warning_rounded;
      case AlertTileSeverity.warning:  return Icons.warning_amber_rounded;
    }
  }

  OpsBadgeVariant _badge() {
    switch (severity) {
      case AlertTileSeverity.critical: return OpsBadgeVariant.danger;
      case AlertTileSeverity.severe:   return OpsBadgeVariant.danger;
      case AlertTileSeverity.warning:  return OpsBadgeVariant.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c     = core_theme.RiverTheme.of(context).colors;
    final color = _color(c);
    final level = currentLevel?.toStringAsFixed(2) ?? "--";
    final dngr  = dangerLevel?.toStringAsFixed(2)  ?? "--";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(city,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OpsBadge(label: riskLabel, variant: _badge()),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(river,
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Chip(label: "Current", value: "$level m", color: color),
                      const SizedBox(width: 8),
                      _Chip(label: "Danger",  value: "$dngr m", color: c.textMuted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = core_theme.RiverTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: "\$label  ",
            style: TextStyle(color: c.textMuted, fontSize: 10)),
          TextSpan(text: value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}