// lib/screens/dashboard_screen.dart  v10.2  (15 Jun 2026)
//
// v10.2 visual overhaul:
//   • _LauncherTile: icon ALWAYS in Center inside fixed badge; label centered
//   • _sectionHeader: icon badge vertically centers with Row crossAxisAlignment.center
//   • Every tile gets its own bespoke icon + mid-tone custom color (not too dark/light)
//   • Stat tiles: Td3StatTile already fixed in theme_3d v2.3
//   • Section colours refreshed to match icon personality
library;

import 'package:flutter/material.dart';
import '../widgets/app_icon_box.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/real_time_river_provider.dart';
import '../models/river_station.dart';
import '../providers/alerts_badge_provider.dart';
import '../widgets/summary_strip.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ── screen imports ────────────────────────────────────────────────────────────
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
import 'evacuation_routes_screen.dart';
import 'sos_screen.dart';
import 'incident_report_screen.dart';
import 'community_screen.dart';
import 'historical_analytics_screen.dart';
import 'export_screen.dart';
import 'settings_screen.dart';

import 'india_river_explorer_screen.dart';
import 'crowd_report_feed_screen.dart';
import '../providers/bihar_prediction_provider.dart';
import '../models/flood_prediction.dart';
import 'city_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom mid-tone palette — not too light, not too dark
// Each colour is HSL ~50% lightness so it reads on both dark+light themes
// ─────────────────────────────────────────────────────────────────────────────
class _P {
  // Blues / Teals
  static const riverBlue    = Color(0xFF2196F3); // river monitor
  static const signalGreen  = Color(0xFF26A69A); // live stations (teal-green)
  static const mapTeal      = Color(0xFF00897B); // bihar map
  static const explorerCyan = Color(0xFF0097A7); // india explorer
  static const layerSlate   = Color(0xFF546E7A); // map layers
  // Purples / Indigo
  static const aiViolet     = Color(0xFF7E57C2); // ai prediction
  static const rainfallBlue = Color(0xFF1976D2); // rainfall
  static const sunAmber     = Color(0xFFFF8F00); // weather / sun
  static const matrixIndigo = Color(0xFF3949AB); // state matrix
  // Reds / Oranges for alerts
  static const alertRed     = Color(0xFFE53935); // alerts
  static const criticalOrange= Color(0xFFEF6C00); // active alerts
  static const sosRed       = Color(0xFFC62828); // SOS
  static const evacAmber    = Color(0xFFF57F17); // evacuation
  // Greens for community
  static const communityGreen= Color(0xFF388E3C); // community
  static const incidentOrange= Color(0xFFE64A19); // incident
  static const crowdPurple  = Color(0xFF6A1B9A); // crowd reports
  static const newsGold     = Color(0xFFF9A825); // news
  // Analytics
  static const analyticsBlue= Color(0xFF0288D1); // analytics
  static const historyBrown = Color(0xFF6D4C41); // historical
  static const exportSteel  = Color(0xFF455A64); // export
  static const settingsGray = Color(0xFF607D8B); // settings
}

// ─────────────────────────────────────────────────────────────────────────────
// _Tile data model
// ─────────────────────────────────────────────────────────────────────────────
class _Tile {
  final String       label;
  final IconData     icon;
  final Color        color;
  final String?      badge;
  final WidgetBuilder builder;
  const _Tile({
    required this.label,
    required this.icon,
    required this.color,
    required this.builder,
    // ignore: unused_element_parameter
    this.badge,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutoRefreshMixin {

  String _query = '';

  // ── Tile catalogues with custom icons + mid-tone colors ──────────────────

  List<_Tile> get _monitoringTiles => [
    _Tile(
      label:   'River Monitor',
      icon:    Icons.monitor_heart_outlined,
      color:   _P.riverBlue,
      builder: (_) => const RiverMonitorScreen(),
    ),
    _Tile(
      label:   'Live Stations',
      icon:    Icons.broadcast_on_personal_rounded,
      color:   _P.signalGreen,
      builder: (_) => const LiveStationsScreen(),
    ),
    _Tile(
      label:   'Bihar Map',
      icon:    Icons.map_rounded,
      color:   _P.mapTeal,
      builder: (_) => const BiharRiverMapScreen(),
    ),
    _Tile(
      label:   'India Explorer',
      icon:    Icons.travel_explore_rounded,
      color:   _P.explorerCyan,
      builder: (_) => const IndiaRiverExplorerScreen(),
    ),
    _Tile(
      label:   'Map View',
      icon:    Icons.layers_rounded,
      color:   _P.layerSlate,
      builder: (_) => const BiharRiverMapScreen(),
    ),
  ];

  List<_Tile> get _forecastTiles => [
    _Tile(
      label:   'AI Prediction',
      icon:    Icons.psychology_rounded,
      color:   _P.aiViolet,
      builder: (_) => const RainfallForecastScreen(),
    ),
    _Tile(
      label:   'Rainfall',
      icon:    Icons.grain_rounded,
      color:   _P.rainfallBlue,
      builder: (_) => const RainfallForecastScreen(),
    ),
    _Tile(
      label:   'Weather',
      icon:    Icons.wb_sunny_rounded,
      color:   _P.sunAmber,
      builder: (_) => const WeatherScreen(),
    ),
    _Tile(
      label:   'State Matrix',
      icon:    Icons.grid_view_rounded,
      color:   _P.matrixIndigo,
      builder: (_) => const StateMatrixScreen(),
    ),
  ];

  List<_Tile> get _alertsTiles => [
    _Tile(
      label:   'Alerts',
      icon:    Icons.notifications_active_rounded,
      color:   _P.alertRed,
      builder: (_) => const AlertsScreen(),
    ),
    _Tile(
      label:   'Active Alerts',
      icon:    Icons.crisis_alert_rounded,
      color:   _P.criticalOrange,
      builder: (_) => const AlertsScreen(),
    ),
    _Tile(
      label:   'SOS',
      icon:    Icons.health_and_safety_rounded,
      color:   _P.sosRed,
      builder: (_) => const SosScreen(),
    ),
    _Tile(
      label:   'Evacuation',
      icon:    Icons.directions_run_rounded,
      color:   _P.evacAmber,
      builder: (_) => const EvacuationRoutesScreen(),
    ),
  ];

  List<_Tile> get _communityTiles => [
    _Tile(
      label:   'Community',
      icon:    Icons.groups_rounded,
      color:   _P.communityGreen,
      builder: (_) => const CommunityScreen(),
    ),
    _Tile(
      label:   'Report Incident',
      icon:    Icons.report_problem_rounded,
      color:   _P.incidentOrange,
      builder: (_) => const IncidentReportScreen(),
    ),
    _Tile(
      label:   'Crowd Reports',
      icon:    Icons.forum_rounded,
      color:   _P.crowdPurple,
      builder: (_) => const CrowdReportFeedScreen(),
    ),
    _Tile(
      label:   'News Feed',
      icon:    Icons.article_rounded,
      color:   _P.newsGold,
      builder: (_) => const NewsFeedScreen(),
    ),
  ];

  List<_Tile> get _analyticsTiles => [
    _Tile(
      label:   'Analytics',
      icon:    Icons.area_chart_rounded,
      color:   _P.analyticsBlue,
      builder: (_) => const AnalyticsDashboardScreen(),
    ),
    _Tile(
      label:   'Historical',
      icon:    Icons.timeline_rounded,
      color:   _P.historyBrown,
      builder: (_) => const HistoricalAnalyticsScreen(),
    ),
    _Tile(
      label:   'Export',
      icon:    Icons.upload_file_rounded,
      color:   _P.exportSteel,
      builder: (_) => const ExportScreen(),
    ),
    _Tile(
      label:   'Settings',
      icon:    Icons.tune_rounded,
      color:   _P.settingsGray,
      builder: (_) => const SettingsScreen(),
    ),
  ];

  late final List<_Tile> _allTiles = [
    ..._monitoringTiles, ..._forecastTiles,
    ..._alertsTiles, ..._communityTiles, ..._analyticsTiles,
  ];

  List<_Tile> get _filteredTiles => _query.isEmpty
      ? _allTiles
      : _allTiles.where((t) =>
          t.label.toLowerCase().contains(_query.toLowerCase())).toList();

  void _open(BuildContext ctx, _Tile tile) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: tile.builder,
      settings: RouteSettings(name: tile.label),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final liveAsync  = ref.watch(biharLiveProvider);
    final merged     = ref.watch(mergedStationsProvider);
    final badgeCount = ref.watch(alertsBadgeProvider);
    final t          = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: _buildAppBar(t, badgeCount),
      body: Stack(
        children: [
          liveAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: t.accent)),
            error:   (e, _) => _errorView(context, e, t),
            data:    (live) => _buildBody(context, live, t, merged),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SosScreen())),
                child: Container(
                  width: 28,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(RiverColors t, int badgeCount) {
    return AppBar(
      backgroundColor: t.navBg,
      elevation: 0,
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (r) =>
                LinearGradient(colors: [t.accent, t.metricColor]).createShader(r),
            child: const Icon(Icons.water_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (r) => LinearGradient(
              colors: [t.textPrimary, t.accent],
              stops: const [0.5, 1.0],
            ).createShader(r),
            child: const Text('OpsFlood Bihar',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 18, letterSpacing: -0.3,
              )),
          ),
        ],
      ),
      actions: [
        if (badgeCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Badge(
              label: Text('$badgeCount'),
              child: IconButton(
                icon: Icon(Icons.notifications_rounded, color: t.textSecondary),
                tooltip: 'Alerts',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AlertsScreen())),
              ),
            ),
          ),
        IconButton(
          icon: Icon(Icons.search_rounded, color: t.textSecondary),
          tooltip: 'Search screens',
          onPressed: () => _showSearchSheet(context, t),
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: t.textSecondary),
          tooltip: 'Refresh live data',
          onPressed: onManualRefresh,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              t.accent.withValues(alpha: 0.0),
              t.accent.withValues(alpha: 0.6),
              t.accent.withValues(alpha: 0.0),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext ctx, RiverColors t) {
    return FloatingActionButton.extended(
      heroTag:         'sos_fab',
      backgroundColor: _P.sosRed,
      foregroundColor: Colors.white,
      icon:  const Icon(Icons.health_and_safety_rounded),
      label: const Text('SOS',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      onPressed: () => Navigator.push(
          ctx, MaterialPageRoute(builder: (_) => const SosScreen())),
    );
  }

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
                Text('Could not load live data', style: TextStyle(
                  color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Check your connection and try again.',
                    style: TextStyle(color: t.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center),
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

  Widget _buildBody(BuildContext ctx, BiharLiveState live, RiverColors t, List<dynamic> merged) {
    return refreshIndicator(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SummaryStrip(
                critical:   merged.where((s) => s.dangerClass.index >= 3).length,
                severe:     merged.where((s) => s.dangerClass.index == 2).length,
                warning:    merged.where((s) => s.dangerClass.index == 1).length,
                safe:       merged.where((s) => s.dangerClass == DangerClass.normal && s.current > 0).length,
                noData:     merged.where((s) => s.current == 0).length,
                lastUpdate: lastFetchedLabel,
              ),
            ),
          ),

          // 4 KPI stat tiles
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   2,
                crossAxisSpacing: 10,
                mainAxisSpacing:  10,
                childAspectRatio: 2.6,
              ),
              itemCount: 4,
              itemBuilder: (_, i) => [
                Td3StatTile(
                  icon:       Icons.crisis_alert_rounded,
                  value:      '${merged.where((s) => s.dangerClass.index >= 3).length}',
                  label:      'Critical',
                  valueColor: _P.alertRed,
                  onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => const AlertsScreen())),
                ),
                Td3StatTile(
                  icon:       Icons.warning_amber_rounded,
                  value:      '${merged.where((s) => s.dangerClass.index == 1 || s.dangerClass.index == 2).length}',
                  label:      'Warning',
                  valueColor: _P.evacAmber,
                  onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => const AlertsScreen())),
                ),
                Td3StatTile(
                  icon:       Icons.check_circle_outline_rounded,
                  value:      '${merged.where((s) => s.dangerClass == DangerClass.normal && s.current > 0).length}',
                  label:      'Safe',
                  valueColor: _P.communityGreen,
                ),
                Td3StatTile(
                  icon:       Icons.sensors_off_rounded,
                  value:      '${merged.where((s) => s.current == 0).length}',
                  label:      'No Data',
                  valueColor: _P.layerSlate,
                ),
              ][i],
            ),
          ),

          _riskForecastStrip(ctx, t),

          _sectionHeader(ctx, t, 'Monitoring & Maps',
              Icons.radar_rounded, _P.riverBlue),
          _tileGrid(ctx, t, _monitoringTiles),

          _sectionHeader(ctx, t, 'Forecast & AI',
              Icons.psychology_rounded, _P.aiViolet),
          _tileGrid(ctx, t, _forecastTiles),

          _sectionHeader(ctx, t, 'Alerts & Safety',
              Icons.crisis_alert_rounded, _P.alertRed),
          _tileGrid(ctx, t, _alertsTiles),

          _sectionHeader(ctx, t, 'Community',
              Icons.groups_rounded, _P.communityGreen),
          _tileGrid(ctx, t, _communityTiles),

          _sectionHeader(ctx, t, 'Analytics & Tools',
              Icons.area_chart_rounded, _P.analyticsBlue),
          _tileGrid(ctx, t, _analyticsTiles),

          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  // ── Risk forecast strip ─────────────────────────────────────────────────
  Widget _riskForecastStrip(BuildContext ctx, RiverColors t) {
    final preds = ref.watch(biharBulkPredictionsProvider).take(5).toList();
    if (preds.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _P.aiViolet.withValues(alpha: 0.28),
                    _P.aiViolet.withValues(alpha: 0.10),
                  ]),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _P.aiViolet.withValues(alpha: 0.30), width: 1),
                ),
                child: Center(child: Icon(Icons.auto_awesome_rounded, color: _P.aiViolet, size: 16)),
              ),
              const SizedBox(width: 9),
              Text('RISK FORECAST', style: TextStyle(
                  color: _P.aiViolet, fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const RainfallForecastScreen())),
                child: Text('See all', style: TextStyle(
                    color: t.accent, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              cacheExtent: 320,
              itemCount: preds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => RepaintBoundary(
                child: _RiskCard(pred: preds[i], onTap: () {
                  Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => CityDetailScreen(cityName: preds[i].station.split(' (').first),
                  ));
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ──────────────────────────────────────────────────────────
  Widget _sectionHeader(
    BuildContext ctx, RiverColors t,
    String label, IconData icon, Color color,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Row(
          // ✅ crossAxisAlignment.center keeps badge + text on same baseline
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
              ),
              // ✅ Center guarantees icon centred in badge regardless of glyph metrics
              child: Center(child: Icon(icon, color: color, size: 16)),
            ),
            const SizedBox(width: 9),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color:         color,
                fontSize:      11,
                fontWeight:    FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tile grid ─────────────────────────────────────────────────────────────
  Widget _tileGrid(BuildContext ctx, RiverColors t, List<_Tile> tiles) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   3,
          crossAxisSpacing: 10,
          mainAxisSpacing:  10,
          childAspectRatio: 1.05,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) => _LauncherTile(
          tile:  tiles[i],
          onTap: () => _open(ctx, tiles[i]),
        ),
      ),
    );
  }

  void _showSearchSheet(BuildContext ctx, RiverColors t) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: t.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _SearchSheet(
        tiles:  _allTiles,
        onOpen: (tile) { Navigator.pop(sheetCtx); _open(ctx, tile); },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LauncherTile  v10.2
//
// Key fixes:
//   1. Icon badge uses Center() — icon always pixel-perfect centred
//   2. Column uses mainAxisAlignment.center + crossAxisAlignment.center
//   3. Text always textAlign.center
//   4. RadialGradient badge gives depth without relying on default fill
// ─────────────────────────────────────────────────────────────────────────────
class _LauncherTile extends StatefulWidget {
  final _Tile        tile;
  final VoidCallback onTap;
  const _LauncherTile({required this.tile, required this.onTap});
  @override
  State<_LauncherTile> createState() => _LauncherTileState();
}

class _LauncherTileState extends State<_LauncherTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale =
      Tween(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t    = RiverColors.of(context);
    final tile = widget.tile;
    final c    = tile.color;

    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Td3Card(
          accentColor: c,
          elevation:   Td3.elevMid,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment:  MainAxisAlignment.center,   // ✅ vertically centred
              crossAxisAlignment: CrossAxisAlignment.center,  // ✅ horizontally centred
              mainAxisSize: MainAxisSize.max,
              children: [
                // Icon badge — always centred via Center()
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      c.withValues(alpha: 0.32),
                      c.withValues(alpha: 0.08),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.withValues(alpha: 0.35), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color:      c.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset:     const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(child: Icon(tile.icon, color: c, size: 24)), // ✅ Center
                ),
                const SizedBox(height: 7),
                // Label — always centred
                Text(
                  tile.label,
                  style: TextStyle(
                    color:      t.textPrimary,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    height:     1.25,
                  ),
                  textAlign: TextAlign.center, // ✅ center
                  maxLines:  2,
                  overflow:  TextOverflow.ellipsis,
                ),
                if (tile.badge != null) ...[
                  const SizedBox(height: 4),
                  Td3Badge(text: tile.badge!, color: c, fontSize: 9),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchSheet
// ─────────────────────────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final List<_Tile>          tiles;
  final void Function(_Tile) onOpen;
  const _SearchSheet({required this.tiles, required this.onOpen});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _q = '';
  List<_Tile> get _results => _q.isEmpty
      ? widget.tiles
      : widget.tiles.where((t) =>
          t.label.toLowerCase().contains(_q.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (_, sc) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: t.stroke, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Td3InputField(
              label:     'Search screens',
              icon:      Icons.search_rounded,
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller:  sc,
              padding:     const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount:   _results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final tile = _results[i];
                return RepaintBoundary(child: Td3Card(
                  accentColor: tile.color,
                  elevation:   Td3.elevLow,
                  onTap:       () => widget.onOpen(tile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AppIconBox(
                          icon:  tile.icon,
                          color: tile.color,
                          size:  38,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(tile.label, style: TextStyle(
                            color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 14,
                          )),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: t.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk Forecast Strip  (Step 6.1)
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// _RiskCard  (Step 6.1)
// ─────────────────────────────────────────────────────────────────────────────
class _RiskCard extends StatelessWidget {
  final FloodPrediction pred;
  final VoidCallback    onTap;
  const _RiskCard({required this.pred, required this.onTap});

  Color _sevColor() {
    switch (pred.severity.toUpperCase()) {
      case 'CRITICAL': return const Color(0xFFE53935);
      case 'SEVERE':   return const Color(0xFFFFB300);
      case 'MODERATE': return const Color(0xFFFDD835);
      default:         return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final c   = _sevColor();
    final bar = (pred.riskScore / 100).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withValues(alpha: 0.4)),
                  ),
                  child: Text(pred.severity,
                      style: TextStyle(color: c, fontSize: 9,
                          fontWeight: FontWeight.w900, letterSpacing: 0.4),
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.textSecondary, size: 14),
            ]),
            const SizedBox(height: 4),
            Text(
              pred.station.split(' (').first,
              style: TextStyle(color: t.textPrimary, fontSize: 11,
                  fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text('24h: ${pred.predicted24h.toStringAsFixed(2)} m',
                style: TextStyle(color: t.textSecondary, fontSize: 9)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bar, minHeight: 4,
                backgroundColor: c.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
            ),
            const SizedBox(height: 3),
            Text('Risk: ${pred.riskScore.toInt()}',
                style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
