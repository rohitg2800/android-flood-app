// lib/screens/dashboard_screen.dart  (v7.1 — 15 Jun 2026)
//
// FIX (v7.1):
//   • Removed biharDashboardProvider — BiharDashboardState does not exist
//     as a concrete type (bihar_dashboard_provider.dart exposes only scalar
//     providers: biharStationCountProvider, biharCriticalCountProvider, …).
//   • _buildBody no longer takes a BiharDashboardState argument.
//   • live.byCity(name) returns BiharStationData? — wrap in [data] list
//     (or pass empty []) so CityCard stationData: List<BiharStationData>? matches.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../widgets/city_card.dart';
import '../widgets/summary_strip.dart';
import '../constants/india_geodata.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutoRefreshMixin {
  @override
  Widget build(BuildContext context) {
    final liveAsync  = ref.watch(biharLiveProvider);
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
            icon:    const Icon(Icons.refresh),
            tooltip: 'Refresh now',
            onPressed: onManualRefresh,
          ),
        ],
      ),
      body: refreshIndicator(
        child: liveAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data:    (live) => _buildBody(context, live),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BiharLiveState live) {
    final cities = IndiaGeodata.cities
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
              // byCity returns BiharStationData? — wrap in list or pass null
              final single = live.byCity(name);
              final data   = single != null ? [single] : <BiharStationData>[];
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
