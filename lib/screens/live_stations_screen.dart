// lib/screens/live_stations_screen.dart  v3.4.1  (18 Jun 2026)
//
// v3.4.1: fix — add missing import for pre_monsoon_baseline_provider.dart
//         (kPreMonsoonBaselineRiskThreshold, preMonsoonBaselineProvider).
//         No logic changes.
//
// v3.4 (18 Jun 2026)
//   • Baseline filter: when preMonsoonBaselineProvider is enabled, stations
//     whose fill % (currentLevel / dangerLevel * 100) is below
//     kPreMonsoonBaselineRiskThreshold are hidden.
//     Stations with no dangerLevel data are always shown.
//   • Dismissible info chip shows how many stations are currently filtered.
//
// v3.3:
//   • onTap now passes liveLevel: s.currentLevel and liveRisk: s.riskLabel
//     to CityDetailScreen so the level shown on the card matches the detail.
//     Note: BiharStationData uses riskLabel (not riskLevel).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bihar_live_provider.dart';
import '../providers/bihar_prediction_provider.dart';
// ✅ v3.4.1 fix — required for preMonsoonBaselineProvider & kPreMonsoonBaselineRiskThreshold
import '../providers/pre_monsoon_baseline_provider.dart';
import '../theme/river_theme.dart';
import '../models/river_station.dart';
import '../providers/prediction_provider.dart';
import '../widgets/dashboard/river_pulse_card.dart';
import '../theme/theme_3d.dart';
import 'city_detail_screen.dart';

class LiveStationsScreen extends ConsumerWidget {
  static const String route = '/live-stations';
  const LiveStationsScreen({super.key});

  /// Returns true if a station passes the pre-monsoon baseline filter.
  /// A station is suppressed only when dangerLevel is known AND
  /// fill % is strictly below the threshold.
  static bool _passesBaseline(BiharStationData s) {
    final dl = s.dangerLevel;
    final cl = s.currentLevel;
    if (dl == null || dl <= 0 || cl == null)
      return true; // no data → always show
    final fillPct = (cl / dl) * 100.0;
    return fillPct >= kPreMonsoonBaselineRiskThreshold;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(biharLiveProvider);
    final baselineOn = ref.watch(preMonsoonBaselineProvider);
    final t = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: liveAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            const Td3AppBar(title: 'Live Stations', subtitle: 'Loading…'),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (err, stack) {
          debugPrint('[LiveStationsScreen] \$err\n\$stack');
          return CustomScrollView(
            slivers: [
              const Td3AppBar(title: 'Live Stations'),
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 48, color: t.danger),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load station data',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString(),
                          style:
                              TextStyle(color: t.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Td3Button(
                          label: 'Retry',
                          icon: Icons.refresh_rounded,
                          width: 140,
                          height: 44,
                          color: t.accent,
                          onTap: () =>
                              ref.read(biharLiveProvider.notifier).refresh(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        data: (state) {
          if (state.stations.isEmpty) {
            return CustomScrollView(
              slivers: [
                Td3AppBar(
                  title: 'Live Stations',
                  subtitle: 'No data yet',
                  actions: [_refreshAction(context, ref, t)],
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_outlined, size: 56, color: t.accent),
                        const SizedBox(height: 12),
                        Text('No station data yet',
                            style: TextStyle(color: t.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Pull to refresh',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Apply baseline filter
          final allStations = state.stations;
          final visibleStations = baselineOn
              ? allStations.where(_passesBaseline).toList()
              : allStations;
          final hiddenCount = allStations.length - visibleStations.length;

          final lastFetch = state.lastFetched;

          return RefreshIndicator(
            color: t.accent,
            onRefresh: () => ref.read(biharLiveProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                Td3AppBar(
                  title: 'All Stations (${allStations.length})',
                  subtitle: lastFetch != null
                      ? 'Updated ${DateFormat('HH:mm:ss').format(lastFetch)}'
                      : null,
                  actions: [_refreshAction(context, ref, t)],
                ),

                // ── Summary chips ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Td3Chip(
                          label: '${visibleStations.length} Showing',
                          color: t.accent,
                          icon: Icons.sensors,
                        ),
                        if (state.criticalCount > 0)
                          Td3Chip(
                            label: '${state.criticalCount} Critical',
                            color: t.danger,
                            icon: Icons.warning_amber_rounded,
                          ),
                        if (state.severeCount > 0)
                          Td3Chip(
                            label: '${state.severeCount} Severe',
                            color: AppPalette.danger,
                            icon: Icons.warning_rounded,
                          ),
                        if (state.warningCount > 0)
                          Td3Chip(
                            label: '${state.warningCount} Warning',
                            color: AppPalette.warning,
                            icon: Icons.info_outline_rounded,
                          ),
                        if (state.safeCount > 0)
                          Td3Chip(
                            label: '${state.safeCount} Safe',
                            color: AppPalette.safe,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        if (state.noDataCount > 0)
                          Td3Chip(
                            label: '${state.noDataCount} No Data',
                            color: t.textSecondary,
                            icon: Icons.signal_wifi_off_rounded,
                          ),
                      ],
                    ),
                  ),
                ),

                // Baseline filter info chip
                if (baselineOn && hiddenCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF7B2FF7).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF7B2FF7)
                                  .withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list_rounded,
                                color: Color(0xFF7B2FF7), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Baseline filter active — $hiddenCount '
                                'low-fill station'
                                '${hiddenCount == 1 ? '' : 's'} hidden',
                                style: const TextStyle(
                                    color: Color(0xFF7B2FF7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Station cards ──────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final s = visibleStations[i];
                        final rs = RiverStation(
                          city: s.city,
                          state: s.state,
                          river: s.river,
                          station: s.city,
                          current: s.currentLevel ?? 0.0,
                          warning: s.warningLevel ?? 0.0,
                          danger: s.dangerLevel ?? 0.0,
                          hfl: (s.dangerLevel ?? 0.0) * 1.2,
                          isLive: s.source == 'LIVE',
                          dataSource: s.source,
                          lastUpdated: s.fetchedAt,
                        );
                        final preds = ref.watch(floodPredictionsProvider);
                        final pred = preds
                            .where((p) => p.station
                                .toLowerCase()
                                .contains(s.city.toLowerCase()))
                            .toList();
                        final conf =
                            pred.isNotEmpty ? pred.first.confidencePct : null;
                        return RiverPulseCard(
                          station: rs,
                          index: i,
                          confidencePercent: conf,
                          onTap: () => Navigator.of(ctx).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CityDetailScreen(
                                cityName: s.city,
                                liveLevel: s.currentLevel,
                                liveRisk: s.riskLabel,
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: visibleStations.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _refreshAction(BuildContext context, WidgetRef ref, RiverColors t) {
    return IconButton(
      icon: Icon(Icons.refresh_rounded, color: t.accent),
      tooltip: 'Refresh',
      onPressed: () => ref.read(biharLiveProvider.notifier).refresh(),
    );
  }
}
