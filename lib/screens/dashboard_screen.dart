// lib/screens/dashboard_screen.dart  (v8.0 — Unified Collapsible Dashboard)
//
// Single scrollable page that houses EVERY major screen as a
// collapsible ExpansionCard section.
// Sections (all independently expandable / collapsible):
//   1. Live Status Strip   — critical/severe/warning/safe counts
//   2. City Cards          — Bihar monitored cities grid
//   3. AI Prediction       — AIPredictionScreen embedded
//   4. River Monitor       — RiverMonitorScreen embedded
//   5. Live Stations       — LiveStationsScreen embedded
//   6. Bihar River Map     — BiharRiverMapScreen embedded
//   7. Rainfall Forecast   — RainfallForecastScreen embedded
//   8. Weather             — WeatherScreen embedded
//   9. State Matrix        — StateMatrixScreen embedded
//  10. News Feed           — NewsFeedScreen embedded
//  11. Alerts              — AlertsScreen embedded
//  12. Analytics           — AnalyticsDashboardScreen embedded

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../widgets/city_card.dart';
import '../widgets/summary_strip.dart';
import '../constants/india_geodata.dart';
import '../theme/river_theme.dart';

import 'ai_prediction_screen.dart';
import 'river_monitor_screen.dart';
import 'live_stations_screen.dart';
import 'bihar_river_map_screen.dart';
import 'rainfall_forecast_screen.dart';
import 'weather_screen.dart';
import 'state_matrix_screen.dart';
import 'news_feed_screen.dart';
import 'alerts_screen.dart';
import 'analytics_dashboard_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutoRefreshMixin {

  // Track which sections are expanded (all open by default except heavy ones)
  final Map<String, bool> _expanded = {
    'status':    true,
    'cities':    true,
    'ai':        false,
    'monitor':   false,
    'stations':  false,
    'map':       false,
    'rainfall':  false,
    'weather':   false,
    'matrix':    false,
    'news':      false,
    'alerts':    false,
    'analytics': false,
  };

  void _toggle(String key) => setState(() => _expanded[key] = !(_expanded[key] ?? false));

  @override
  Widget build(BuildContext context) {
    final liveAsync  = ref.watch(biharLiveProvider);
    final badgeCount = ref.watch(alertsBadgeProvider);
    final t          = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.water_rounded, color: t.accent, size: 22),
            const SizedBox(width: 8),
            Text('OpsFlood Bihar',
                style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                )),
          ],
        ),
        actions: [
          if (badgeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Badge(
                label: Text('$badgeCount'),
                child: Icon(Icons.notifications_rounded, color: t.textSecondary),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.textSecondary),
            tooltip: 'Refresh',
            onPressed: onManualRefresh,
          ),
          // Expand / collapse all toggle
          IconButton(
            icon: Icon(
              _expanded.values.any((v) => v)
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
              color: t.textSecondary,
            ),
            tooltip: 'Expand / Collapse all',
            onPressed: () {
              final anyOpen = _expanded.values.any((v) => v);
              setState(() {
                for (final k in _expanded.keys) {
                  _expanded[k] = !anyOpen;
                }
              });
            },
          ),
        ],
      ),
      body: refreshIndicator(
        child: liveAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => _errorView(context, e, t),
          data:    (live) => _buildBody(context, live, t),
        ),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────
  Widget _errorView(BuildContext ctx, Object e, RiverColors t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: t.textSecondary),
            const SizedBox(height: 16),
            Text('Could not load live data',
                style: TextStyle(color: t.textPrimary, fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Check your connection and try again.',
                style: TextStyle(color: t.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ref.invalidate(biharLiveProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main body ───────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext ctx, BiharLiveState live, RiverColors t) {
    final cities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [

        // ── Section 1: Live Status Strip ──────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'status',
          icon: Icons.dashboard_rounded,
          color: t.accent,
          title: 'Live Status',
          subtitle: '${live.stations.length} stations',
        ),
        if (_expanded['status'] == true)
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

        // ── Section 2: City Cards ─────────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'cities',
          icon: Icons.location_city_rounded,
          color: Colors.blue,
          title: 'Monitored Cities',
          subtitle: '${cities.length} Bihar cities',
        ),
        if (_expanded['cities'] == true)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                crossAxisSpacing:   10,
                mainAxisSpacing:    10,
                childAspectRatio:   1.45,
              ),
              itemCount: cities.length,
              itemBuilder: (_, i) {
                final mc   = cities[i];
                final name = mc['city'] as String;
                return CityCard(
                  cityMeta:    mc,
                  stationData: live.byCity(name),
                );
              },
            ),
          ),

        // ── Section 3: AI Prediction ──────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'ai',
          icon: Icons.auto_graph_rounded,
          color: const Color(0xFF7B2FF7),
          title: 'AI Flood Prediction',
          subtitle: 'ML forecast',
        ),
        if (_expanded['ai'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 520, child: AIPredictionScreen()),
          ),

        // ── Section 4: River Monitor ──────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'monitor',
          icon: Icons.monitor_heart_outlined,
          color: const Color(0xFF00B0FF),
          title: 'River Monitor',
          subtitle: 'All Bihar gauges',
        ),
        if (_expanded['monitor'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 560, child: RiverMonitorScreen()),
          ),

        // ── Section 5: Live Stations ──────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'stations',
          icon: Icons.sensors_rounded,
          color: const Color(0xFF00E676),
          title: 'Live Stations',
          subtitle: 'CWC + WRD feed',
        ),
        if (_expanded['stations'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 520, child: LiveStationsScreen()),
          ),

        // ── Section 6: Bihar River Map ────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'map',
          icon: Icons.map_rounded,
          color: Colors.teal,
          title: 'Bihar River Map',
          subtitle: 'Interactive map',
        ),
        if (_expanded['map'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 420, child: BiharRiverMapScreen()),
          ),

        // ── Section 7: Rainfall Forecast ──────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'rainfall',
          icon: Icons.cloudy_snowing,
          color: const Color(0xFF00B0FF),
          title: 'Rainfall Forecast',
          subtitle: '7-day IMD data',
        ),
        if (_expanded['rainfall'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 480, child: RainfallForecastScreen()),
          ),

        // ── Section 8: Weather ────────────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'weather',
          icon: Icons.wb_sunny_outlined,
          color: Colors.orange,
          title: 'Weather',
          subtitle: 'Current conditions',
        ),
        if (_expanded['weather'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 440, child: WeatherScreen()),
          ),

        // ── Section 9: State Matrix ───────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'matrix',
          icon: Icons.grid_view_rounded,
          color: const Color(0xFF039BE5),
          title: 'State Matrix',
          subtitle: 'District-level view',
        ),
        if (_expanded['matrix'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 480, child: StateMatrixScreen()),
          ),

        // ── Section 10: News Feed ─────────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'news',
          icon: Icons.newspaper_outlined,
          color: Colors.amber,
          title: 'News Feed',
          subtitle: 'Flood news',
        ),
        if (_expanded['news'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 480, child: NewsFeedScreen()),
          ),

        // ── Section 11: Alerts ────────────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'alerts',
          icon: Icons.notifications_active_rounded,
          color: Colors.red,
          title: 'Alerts',
          subtitle: 'Active warnings',
        ),
        if (_expanded['alerts'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 440, child: AlertsScreen()),
          ),

        // ── Section 12: Analytics ─────────────────────────────────────────────
        _sectionHeader(
          ctx, t, key: 'analytics',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF26C6DA),
          title: 'Analytics',
          subtitle: 'Trends & charts',
        ),
        if (_expanded['analytics'] == true)
          const SliverToBoxAdapter(
            child: SizedBox(height: 520, child: AnalyticsDashboardScreen()),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ── Section header builder ─────────────────────────────────────────────────
  Widget _sectionHeader(
    BuildContext ctx,
    RiverColors t, {
    required String    key,
    required IconData  icon,
    required Color     color,
    required String    title,
    required String    subtitle,
  }) {
    final isOpen = _expanded[key] ?? false;
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () => _toggle(key),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOpen ? color.withOpacity(0.6) : t.divider,
              width: isOpen ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:       Colors.black.withOpacity(0.08),
                blurRadius:  8,
                offset:      const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icon bubble
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            color:      t.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize:   14,
                          )),
                      Text(subtitle,
                          style: TextStyle(
                            color:    t.textSecondary,
                            fontSize: 11,
                          )),
                    ],
                  ),
                ),
                // Expand/collapse chevron
                AnimatedRotation(
                  turns:    isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
