import "package:flutter/material.dart";
import "../../../l10n/context_l10n.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;
import "package:equinox_flood/core/widgets/ops_banner.dart";
import "../../../app_router.dart";
import "../application/dashboard_viewmodel.dart";
import "widgets/hero_summary.dart";
import "widgets/quick_stats_row.dart";
import "widgets/section_sliver.dart";

class NewDashboardScreen extends ConsumerWidget {
  static const route = "/new-dashboard";
  const NewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = core_theme.RiverTheme.of(context).colors;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            backgroundColor: c.scaffoldBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                Icon(Icons.water_rounded, color: c.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.l10n.appTitle,
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
                icon:
                    Icon(Icons.notifications_outlined, color: c.textSecondary),
                onPressed: () => context.go(Routes.alerts),
              ),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: c.textSecondary),
                onPressed: () => context.go(Routes.settings),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(child: HeroSummary(stats: stats)),
          if (stats.critical > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OpsBanner(
                  title: "${stats.critical} critical station active",
                  subtitle: "Tap to view alerts",
                  variant: OpsBannerVariant.danger,
                  onTap: () => context.go(Routes.alerts),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: QuickStatsRow(
              stats: stats,
              onCriticalTap: () => context.go(Routes.alerts),
              onElevatedTap: () => context.go(Routes.alerts),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SectionSliver(
            label: context.l10n.tabMonitors,
            icon: Icons.pin_drop_outlined,
            tiles: monitoringTiles(context),
            columns: 2,
          ),
          SectionSliver(
            label: context.l10n.alerts,
            icon: Icons.crisis_alert_rounded,
            tiles: alertsTiles(context),
          ),
          SectionSliver(
            label: context.l10n.forecast,
            icon: Icons.psychology_rounded,
            tiles: forecastTiles(context),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
