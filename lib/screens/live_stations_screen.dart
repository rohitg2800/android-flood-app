// lib/screens/live_stations_screen.dart  (v3.0 — 3D theme)
//
// OpsFlood — All-Stations Live Screen
//
// v2.x → v3.0:
//   • Migrated to Td3 3D theme system
//   • AppBar → Td3AppBar (SliverAppBar)
//   • Station cards → Td3Card with Td3ProgressBar gauge
//   • Stat chips → Td3Chip
//   • Risk badges → Td3Badge
//   • Retry button → Td3Button
//   • All colours via RiverColors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bihar_live_provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

class LiveStationsScreen extends ConsumerWidget {
  static const String route = '/live-stations';
  const LiveStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(biharLiveProvider);
    final t     = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: async.when(
        loading: () => CustomScrollView(
          slivers: [
            Td3AppBar(title: 'Live Stations', subtitle: 'Loading…'),
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
        error: (err, _) => CustomScrollView(
          slivers: [
            Td3AppBar(title: 'Live Stations'),
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
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 12),
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
        ),
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
                        Icon(Icons.water_outlined,
                            size: 56, color: t.accent),
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

          final lastFetch = state.lastFetched;

          return RefreshIndicator(
            color: t.accent,
            onRefresh: () =>
                ref.read(biharLiveProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                Td3AppBar(
                  title: 'All Stations (${state.stations.length})',
                  subtitle: lastFetch != null
                      ? 'Updated ${DateFormat('HH:mm:ss').format(lastFetch)}'
                      : null,
                  actions: [_refreshAction(context, ref, t)],
                ),

                // ── Summary chips ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Td3Chip(
                          label: '${state.stations.length} Total',
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

                // ── Station cards ────────────────────────────────────────────
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _StationCard(station: state.stations[i]),
                      childCount: state.stations.length,
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

  Widget _refreshAction(
      BuildContext context, WidgetRef ref, RiverColors t) {
    return IconButton(
      icon: Icon(Icons.refresh_rounded, color: t.accent),
      tooltip: 'Refresh',
      onPressed: () => ref.read(biharLiveProvider.notifier).refresh(),
    );
  }
}

// ── Risk colour helper ────────────────────────────────────────────────────────────
Color _riskColor(BiharStationData s) {
  if (s.isCritical) return AppPalette.critical;
  if (s.isSevere)   return AppPalette.danger;
  if (s.isWarning)  return AppPalette.warning;
  if (s.isSafe)     return AppPalette.safe;
  return AppPalette.textGrey;
}

// ── Station card (3D) ────────────────────────────────────────────────────────────
class _StationCard extends StatelessWidget {
  final BiharStationData station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final s     = station;
    final color = _riskColor(s);
    final t     = RiverColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Td3Card(
        accentColor: color,
        elevation: Td3.elevHigh,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: dot + name + source + risk badge
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.city,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Td3Badge(
                  label: s.source == 'LIVE' ? '● LIVE' : '○ STATIC',
                  color: s.source == 'LIVE' ? t.accent : t.textSecondary,
                  fontSize: 9,
                ),
                const SizedBox(width: 6),
                Td3Badge(label: s.riskLabel, color: color),
              ],
            ),

            // River · district · state
            if ([s.river, s.district, s.state]
                .any((v) => v.isNotEmpty)) ...[
              const SizedBox(height: 4),
              Text(
                [s.river, s.district, s.state]
                    .where((v) => v.isNotEmpty)
                    .join(' · '),
                style: TextStyle(
                    color: t.textSecondary, fontSize: 12),
              ),
            ],

            const SizedBox(height: 12),

            // Level gauge (0-150%)
            if (s.currentLevel != null && s.dangerLevel != null) ...[
              Row(
                children: [
                  Text('Level',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 11)),
                  const Spacer(),
                  Text(
                    '${s.currentLevel!.toStringAsFixed(2)} m  /  '
                    '${s.dangerLevel!.toStringAsFixed(2)} m danger',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Td3ProgressBar(
                    value: (s.dangerPercent / 150).clamp(0.0, 1.0),
                    fillColor: color,
                    height: 8,
                  ),
                  // Danger-line tick at the 2/3 mark
                  FractionallySizedBox(
                    widthFactor: 2 / 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 2, height: 8,
                        color: AppPalette.danger.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Data chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (s.diff24h != null)
                  Td3Chip(
                    label:
                        '${s.diff24h! >= 0 ? '+' : ''}'
                        '${s.diff24h!.toStringAsFixed(2)} m/24h',
                    color: s.diff24h! > 0
                        ? AppPalette.danger
                        : t.accent,
                    icon: s.trend == '↑'
                        ? Icons.arrow_upward
                        : s.trend == '↓'
                            ? Icons.arrow_downward
                            : Icons.remove,
                    fontSize: 10,
                  ),
                if (s.discharge != null)
                  Td3Chip(
                    label: '${_fmt(s.discharge!)} m³/s',
                    color: t.accent,
                    icon: Icons.water,
                    fontSize: 10,
                  ),
                if (s.rainfall24h != null && s.rainfall24h! > 0)
                  Td3Chip(
                    label: '${s.rainfall24h!.toStringAsFixed(1)} mm',
                    color: Colors.lightBlue,
                    icon: Icons.grain,
                    fontSize: 10,
                  ),
                if (s.forecast24h != null)
                  Td3Chip(
                    label: 'Fcst ${s.forecast24h!.toStringAsFixed(2)} m',
                    color: AppPalette.gold,
                    icon: Icons.trending_up,
                    fontSize: 10,
                  ),
              ],
            ),

            // Source + time
            if (s.source.isNotEmpty || s.fetchedAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Td3Divider(),
              const SizedBox(height: 6),
              Text(
                [s.source, if (s.fetchedAt.isNotEmpty) _shortTs(s.fetchedAt)]
                    .join('  '),
                style: TextStyle(
                    color: t.textSecondary, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  static String _shortTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
