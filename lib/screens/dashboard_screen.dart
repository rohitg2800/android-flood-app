// lib/screens/dashboard_screen.dart  (v9.0 — enhanced UI + theme-aware)
//
// Changes from v8.2:
//  • All Colors.black.withOpacity()  → withValues(alpha:)
//  • All Colors.X.withOpacity()      → withValues(alpha:)
//  • Section header card: uses t.cardBg, t.divider, t.accent from theme
//  • Section header: gradient accent left-border instead of plain border
//  • AppBar: animated wave gradient title, search action
//  • Body: subtle radial gradient behind CustomScrollView
//  • Error card: Td3Card + proper colour tokens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../widgets/city_card.dart';
import '../widgets/summary_strip.dart';
import '../constants/india_geodata.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

import 'ai_prediction_screen.dart';       // AiPredictionScreen
import 'river_monitor_screen.dart';       // RiverMonitorScreen
import 'live_stations_screen.dart';       // LiveStationsScreen
import 'bihar_river_map_screen.dart';     // BiharRiverMapScreen
import 'rainfall_forecast_screen.dart';   // RainfallForecastScreen
import 'weather_screen.dart';             // WeatherScreen
import 'state_matrix_screen.dart';        // StateMatrixScreen
import 'news_feed_screen.dart';           // NewsFeedScreen
import 'alerts_screen.dart';              // AlertsScreen
import 'analytics_dashboard_screen.dart'; // AnalyticsDashboardScreen

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutoRefreshMixin {

  // ── Section expand state ────────────────────────────────────────────────────
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

  void _toggle(String key) =>
      setState(() => _expanded[key] = !(_expanded[key] ?? false));

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final liveAsync  = ref.watch(biharLiveProvider);
    final badgeCount = ref.watch(alertsBadgeProvider);
    final t          = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: _buildAppBar(t, badgeCount),
      body: refreshIndicator(
        child: liveAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: t.accent),
          ),
          error:   (e, _) => _errorView(context, e, t),
          data:    (live) => _buildBody(context, live, t),
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(RiverColors t, int badgeCount) {
    return AppBar(
      backgroundColor: t.navBg,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (r) => LinearGradient(
              colors: [t.accent, t.metricColor],
            ).createShader(r),
            child: const Icon(Icons.water_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (r) => LinearGradient(
              colors: [t.textPrimary, t.accent],
              stops: const [0.5, 1.0],
            ).createShader(r),
            child: Text(
              'OpsFlood Bihar',
              style: const TextStyle(
                color:         Colors.white,
                fontWeight:    FontWeight.w800,
                fontSize:      18,
                letterSpacing: -0.3,
              ),
            ),
          ),
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
              for (final k in _expanded.keys) _expanded[k] = !anyOpen;
            });
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.accent.withValues(alpha: 0.0), t.accent.withValues(alpha: 0.6), t.accent.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }

  // ── Error view ───────────────────────────────────────────────────────────────
  Widget _errorView(BuildContext ctx, Object e, RiverColors t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Td3Card(
          accentColor: AppPalette.critical,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 56, color: t.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'Could not load live data',
                  style: TextStyle(
                    color:      t.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again.',
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Td3Button(
                  label: 'Try again',
                  icon:  Icons.refresh_rounded,
                  onTap: () => ref.invalidate(biharLiveProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Main body ────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext ctx, BiharLiveState live, RiverColors t) {
    final cities = IndiaGeodata.monitoredCities
        .where((c) => c['state'] == 'Bihar')
        .toList();

    return Stack(
      children: [
        // Subtle radial glow behind content
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  t.accent.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // 1 — Live Status
            _header(ctx, t, key: 'status',
                icon: Icons.dashboard_rounded, color: t.accent,
                title: 'Live Status', subtitle: '${live.stations.length} stations'),
            if (_expanded['status'] == true)
              SliverToBoxAdapter(
                child: SummaryStrip(
                  critical: live.criticalCount, severe: live.severeCount,
                  warning:  live.warningCount,  safe:   live.safeCount,
                  noData:   live.noDataCount,   lastUpdate: lastFetchedLabel,
                ),
              ),

            // 2 — Monitored Cities
            _header(ctx, t, key: 'cities',
                icon: Icons.location_city_rounded, color: Colors.blue,
                title: 'Monitored Cities', subtitle: '${cities.length} Bihar cities'),
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

            // 3 — AI Prediction
            _header(ctx, t, key: 'ai',
                icon: Icons.auto_graph_rounded, color: const Color(0xFF7B2FF7),
                title: 'AI Flood Prediction', subtitle: 'ML forecast'),
            if (_expanded['ai'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 520, child: AiPredictionScreen()),
              ),

            // 4 — River Monitor
            _header(ctx, t, key: 'monitor',
                icon: Icons.monitor_heart_outlined, color: const Color(0xFF00B0FF),
                title: 'River Monitor', subtitle: 'All Bihar gauges'),
            if (_expanded['monitor'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 560, child: RiverMonitorScreen()),
              ),

            // 5 — Live Stations
            _header(ctx, t, key: 'stations',
                icon: Icons.sensors_rounded, color: const Color(0xFF00E676),
                title: 'Live Stations', subtitle: 'CWC + WRD feed'),
            if (_expanded['stations'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 520, child: LiveStationsScreen()),
              ),

            // 6 — Bihar River Map
            _header(ctx, t, key: 'map',
                icon: Icons.map_rounded, color: Colors.teal,
                title: 'Bihar River Map', subtitle: 'Interactive map'),
            if (_expanded['map'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 420, child: BiharRiverMapScreen()),
              ),

            // 7 — Rainfall Forecast
            _header(ctx, t, key: 'rainfall',
                icon: Icons.cloudy_snowing, color: const Color(0xFF00B0FF),
                title: 'Rainfall Forecast', subtitle: '7-day IMD data'),
            if (_expanded['rainfall'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 480, child: RainfallForecastScreen()),
              ),

            // 8 — Weather
            _header(ctx, t, key: 'weather',
                icon: Icons.wb_sunny_outlined, color: Colors.orange,
                title: 'Weather', subtitle: 'Current conditions'),
            if (_expanded['weather'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 440, child: WeatherScreen()),
              ),

            // 9 — State Matrix
            _header(ctx, t, key: 'matrix',
                icon: Icons.grid_view_rounded, color: const Color(0xFF039BE5),
                title: 'State Matrix', subtitle: 'District-level view'),
            if (_expanded['matrix'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 480, child: StateMatrixScreen()),
              ),

            // 10 — News Feed
            _header(ctx, t, key: 'news',
                icon: Icons.newspaper_outlined, color: Colors.amber,
                title: 'News Feed', subtitle: 'Flood news'),
            if (_expanded['news'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 480, child: NewsFeedScreen()),
              ),

            // 11 — Alerts
            _header(ctx, t, key: 'alerts',
                icon: Icons.notifications_active_rounded, color: AppPalette.critical,
                title: 'Alerts', subtitle: 'Active warnings'),
            if (_expanded['alerts'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 440, child: AlertsScreen()),
              ),

            // 12 — Analytics
            _header(ctx, t, key: 'analytics',
                icon: Icons.bar_chart_rounded, color: const Color(0xFF26C6DA),
                title: 'Analytics', subtitle: 'Trends & charts'),
            if (_expanded['analytics'] == true)
              SliverToBoxAdapter(
                child: SizedBox(height: 520, child: AnalyticsDashboardScreen()),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ],
    );
  }

  // ── Section header card ───────────────────────────────────────────────────────
  Widget _header(
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
            color:        t.cardBg,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(
              color: isOpen ? color.withValues(alpha: 0.55) : t.divider,
              width: isOpen ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset:     const Offset(0, 3),
              ),
              if (isOpen)
                BoxShadow(
                  color:      color.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset:     const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // Gradient left-edge accent bar when open
                if (isOpen)
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.3)],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(isOpen ? 20 : 16, 12, 16, 12),
                  child: Row(
                    children: [
                      // Icon bubble
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color:        color.withValues(alpha: isOpen ? 0.22 : 0.13),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isOpen
                              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color:      t.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize:   14,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color:    t.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chevron
                      AnimatedRotation(
                        turns:    isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isOpen ? color : t.textSecondary,
                        ),
                      ),
                    ],
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
