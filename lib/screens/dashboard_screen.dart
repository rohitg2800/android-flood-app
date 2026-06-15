// lib/screens/dashboard_screen.dart  (v7.0 — 15 Jun 2026)
//
// CHANGE: Auto-refresh wired via stream subscription.
//
// v7.0 (15 Jun 2026) — Remove private Timer.periodic + initState ref.read.
//   All city-card / summary data now flows from ref.watch(biharLiveProvider),
//   which rebuilds the widget tree automatically every time BiharLiveEngine
//   emits a new feed (engine default: every 5 min, or immediately on manual
//   pull-to-refresh).  Added AutoRefreshMixin for the pull-to-refresh
//   indicator and the 'Updated X ago' subtitle chip.
//
// Previous versions kept a 5-minute Timer inside initState that called
// ref.read(biharLiveProvider.notifier).refresh() — this duplicated the
// engine's own schedule and caused a double-fetch on startup.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/bihar_dashboard_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../widgets/city_card.dart';
import '../widgets/summary_strip.dart';
import '../widgets/river_level_chip.dart';
import '../constants/india_geodata.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutoRefreshMixin {
  // ── No private Timer — BiharLiveEngine handles scheduling. ───────────────

  @override
  Widget build(BuildContext context) {
    // All three watches below rebuild automatically when the engine emits.
    final liveAsync  = ref.watch(biharLiveProvider);
    final dashState  = ref.watch(biharDashboardProvider);
    final badgeCount = ref.watch(alertsBadgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpsFlood Dashboard'),
        actions: [
          if (badgeCount > 0)
            Badge(
              label: Text('$badgeCount'),
              child: const Icon(Icons.notifications),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: onManualRefresh,
          ),
        ],
      ),
      body: refreshIndicator(
        child: liveAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data:    (live) => _buildBody(context, live, dashState),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BiharLiveState live,
    BiharDashboardState dash,
  ) {
    final cities = monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SummaryStrip(
            critical:   live.criticalCount,
            severe:     live.severeCount,
            warning:    live.warningCount,
            safe:       live.safeCount,
            noData:     live.noDataCount,
            lastUpdate: lastFetchedLabel,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              crossAxisSpacing:   12,
              mainAxisSpacing:    12,
              childAspectRatio:   1.45,
            ),
            itemCount: cities.length,
            itemBuilder: (ctx, i) {
              final mc   = cities[i];
              final name = mc['city'] as String;
              final data = live.byCity(name);
              return CityCard(
                cityMeta:    mc,
                stationData: data,
              );
            },
          ),
        ),
      ],
    );
  }
}
