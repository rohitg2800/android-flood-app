import "package:flutter/material.dart";
import '../../../../l10n/context_l10n.dart';
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;
import "package:equinox_flood/core/widgets/ops_card.dart";
import "../../domain/dashboard_stats.dart";

class QuickStatsRow extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback? onCriticalTap;
  final VoidCallback? onElevatedTap;
  const QuickStatsRow(
      {super.key, required this.stats, this.onCriticalTap, this.onElevatedTap});

  @override
  Widget build(BuildContext context) {
    final c = core_theme.RiverTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
              child: _StatTile(
                  label: "Critical",
                  value: "${stats.critical}",
                  color: c.danger,
                  icon: Icons.crisis_alert_rounded,
                  onTap: onCriticalTap)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: "Elevated",
                  value: "${stats.elevated}",
                  color: c.warning,
                  icon: Icons.warning_amber_rounded,
                  onTap: onElevatedTap)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: "Safe",
                  value: "${stats.safe}",
                  color: c.success,
                  icon: Icons.check_circle_outline_rounded,
                  onTap: null)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = core_theme.RiverTheme.of(context).colors;
    return OpsCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      borderColor: color.withValues(alpha: 0.25),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.1)),
                Text(label,
                    textScaler: TextScaler.noScaling,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: c.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
