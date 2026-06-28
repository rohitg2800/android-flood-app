#!/bin/bash

# ── presentation/widgets/section_sliver.dart ───────────────────────────
cat <<'EOF' > lib/features/dashboard/presentation/widgets/section_sliver.dart
import 'package:flutter/material.dart';
import 'package:android_flood_app/core/widgets/ops_section_header.dart';
import '../../domain/dashboard_tile.dart';
import 'tile_grid.dart';

class SectionSliver extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<DashboardTile> tiles;

  const SectionSliver({
    super.key,
    required this.label,
    required this.icon,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: OpsSectionHeader(label: label, icon: icon),
        ),
        TileGrid(tiles: tiles),
      ],
    );
  }
}
EOF

# ── presentation/new_dashboard_screen.dart ─────────────────────────────
cat <<'EOF' > lib/features/dashboard/presentation/new_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_flood_app/core/theme/river_theme.dart' as core_theme;
import 'package:android_flood_app/core/widgets/ops_banner.dart';
import '../application/dashboard_viewmodel.dart';
import 'widgets/hero_summary.dart';
import 'widgets/quick_stats_row.dart';
import 'widgets/section_sliver.dart';

class NewDashboardScreen extends ConsumerWidget {
  static const route = '/new-dashboard';
  const NewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c     = core_theme.RiverTheme.of(context).colors;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [

          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: c.scaffoldBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                Icon(Icons.water_rounded, color: c.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'FloodWatch',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: c.textSecondary),
                onPressed: () => Navigator.pushNamed(context, '/alerts'),
              ),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: c.textSecondary),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Hero summary ─────────────────────────────────────────────
          SliverToBoxAdapter(child: HeroSummary(stats: stats)),

          // ── Critical alert banner (shown only when critical > 0) ─────
          if (stats.critical > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OpsBanner(
                  title: '${stats.critical} critical station${stats.critical > 1 ? 's' : ''} active',
                  subtitle: 'Tap to view alerts',
                  variant: OpsBannerVariant.danger,
                  onTap: () => Navigator.pushNamed(context, '/alerts'),
                ),
              ),
            ),

          // ── Quick stats ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: QuickStatsRow(
              stats: stats,
              onCriticalTap: () => Navigator.pushNamed(context, '/alerts'),
              onElevatedTap: () => Navigator.pushNamed(context, '/alerts'),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Section: Monitoring & Maps ───────────────────────────────
          SectionSliver(
            label: 'Monitoring & Maps',
            icon: Icons.radar_rounded,
            tiles: monitoringTiles,
          ),

          // ── Section: Alerts & Safety ─────────────────────────────────
          SectionSliver(
            label: 'Alerts & Safety',
            icon: Icons.crisis_alert_rounded,
            tiles: alertsTiles,
          ),

          // ── Section: Forecast & AI ───────────────────────────────────
          SectionSliver(
            label: 'Forecast & AI',
            icon: Icons.psychology_rounded,
            tiles: forecastTiles,
          ),

          // ── Bottom padding ───────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
EOF

# ── features/dashboard/index.dart (barrel) ─────────────────────────────
cat <<'EOF' > lib/features/dashboard/index.dart
export 'presentation/new_dashboard_screen.dart';
export 'application/dashboard_viewmodel.dart';
export 'domain/dashboard_tile.dart';
export 'domain/dashboard_stats.dart';
EOF

echo "✅ dashboard module complete"
