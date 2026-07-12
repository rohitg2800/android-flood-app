import "package:flutter/material.dart";
import '../../../../l10n/context_l10n.dart';
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;
import "../../domain/dashboard_stats.dart";

class HeroSummary extends StatelessWidget {
  final DashboardStats stats;
  const HeroSummary({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = core_theme.RiverTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bihar Flood Watch",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 22)),
          const SizedBox(height: 4),
          Text(stats.heroSubtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary)),
          const SizedBox(height: 3),
          Text("Updated ${stats.lastUpdated}",
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}
