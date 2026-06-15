// lib/screens/dashboard_screen.dart  (v10.1)
// Fix: CriticalAlertScreen is an overlay helper (no Widget class to push).
//      Both usages replaced with AlertsScreen. Import removed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mixins/auto_refresh_mixin.dart';
import '../providers/bihar_live_provider.dart';
import '../providers/alerts_badge_provider.dart';
import '../widgets/summary_strip.dart';
import '../constants/india_geodata.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ── screen imports ───────────────────────────────────────────────────────────
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
import 'map_screen.dart';
import 'india_river_explorer_screen.dart';
import 'crowd_report_feed_screen.dart';
// NOTE: critical_alert_screen.dart is overlay-only (no routable Widget class)
//       — use showCriticalAlertOverlay() / showCriticalAlertBanner() directly.

// ─────────────────────────────────────────────────────────────────────────────
// _Tile — data model for each launcher card
// ─────────────────────────────────────────────────────────────────────────────

class _Tile {
  final String    label;
  final IconData  icon;
  final Color     color;
  final String?   badge;
  final WidgetBuilder builder;

  const _Tile({
    required this.label,
    required this.icon,
    required this.color,
    required this.builder,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Tile catalogue
  // ─────────────────────────────────────────────────────────────────────────

  List<_Tile> get _monitoringTiles => [
    _Tile(
      label:   'River Monitor',
      icon:    Icons.monitor_heart_outlined,
      color:   const Color(0xFF00B0FF),
      builder: (_) => const RiverMonitorScreen(),
    ),
    _Tile(
      label:   'Live Stations',
      icon:    Icons.sensors_rounded,
      color:   const Color(0xFF00E676),
      builder: (_) => const LiveStationsScreen(),
    ),
    _Tile(
      label:   'Bihar Map',
      icon:    Icons.map_rounded,
      color:   Colors.teal,
      builder: (_) => const BiharRiverMapScreen(),
    ),
    _Tile(
      label:   'India Explorer',
      icon:    Icons.public_rounded,
      color:   const Color(0xFF26C6DA),
      builder: (_) => const IndiaRiverExplorerScreen(),
    ),
    _Tile(
      label:   'Map View',
      icon:    Icons.layers_rounded,
      color:   Colors.blueGrey,
      builder: (_) => const MapScreen(),
    ),
  ];

  List<_Tile> get _forecastTiles => [
    _Tile(
      label:   'AI Prediction',
      icon:    Icons.auto_graph_rounded,
      color:   const Color(0xFF7B2FF7),
      builder: (_) => const AiPredictionScreen(),
    ),
    _Tile(
      label:   'Rainfall',
      icon:    Icons.cloudy_snowing,
      color:   const Color(0xFF00B0FF),
      builder: (_) => const RainfallForecastScreen(),
    ),
    _Tile(
      label:   'Weather',
      icon:    Icons.wb_sunny_outlined,
      color:   Colors.orange,
      builder: (_) => const WeatherScreen(),
    ),
    _Tile(
      label:   'State Matrix',
      icon:    Icons.grid_view_rounded,
      color:   const Color(0xFF039BE5),
      builder: (_) => const StateMatrixScreen(),
    ),
  ];

  List<_Tile> get _alertsTiles => [
    _Tile(
      label:   'Alerts',
      icon:    Icons.notifications_active_rounded,
      color:   AppPalette.critical,
      builder: (_) => const AlertsScreen(),
    ),
    // CriticalAlertScreen is an overlay helper — no separate screen to push.
    // "Active Alerts" below is the canonical alerts list screen.
    _Tile(
      label:   'Active Alerts',
      icon:    Icons.crisis_alert_rounded,
      color:   AppPalette.danger,
      builder: (_) => const AlertsScreen(),
    ),
    _Tile(
      label:   'SOS',
      icon:    Icons.sos_rounded,
      color:   AppPalette.critical,
      builder: (_) => const SosScreen(),
    ),
    _Tile(
      label:   'Evacuation',
      icon:    Icons.directions_run_rounded,
      color:   AppPalette.warning,
      builder: (_) => const EvacuationRoutesScreen(),
    ),
  ];

  List<_Tile> get _communityTiles => [
    _Tile(
      label:   'Community',
      icon:    Icons.people_rounded,
      color:   const Color(0xFF66BB6A),
      builder: (_) => const CommunityScreen(),
    ),
    _Tile(
      label:   'Report Incident',
      icon:    Icons.report_rounded,
      color:   AppPalette.warning,
      builder: (_) => const IncidentReportScreen(),
    ),
    _Tile(
      label:   'Crowd Reports',
      icon:    Icons.chat_bubble_outline_rounded,
      color:   const Color(0xFFAB47BC),
      builder: (_) => const CrowdReportFeedScreen(),
    ),
    _Tile(
      label:   'News Feed',
      icon:    Icons.newspaper_outlined,
      color:   Colors.amber,
      builder: (_) => const NewsFeedScreen(),
    ),
  ];

  List<_Tile> get _analyticsTiles => [
    _Tile(
      label:   'Analytics',
      icon:    Icons.bar_chart_rounded,
      color:   const Color(0xFF26C6DA),
      builder: (_) => const AnalyticsDashboardScreen(),
    ),
    _Tile(
      label:   'Historical',
      icon:    Icons.history_rounded,
      color:   const Color(0xFFFF7043),
      builder: (_) => const HistoricalAnalyticsScreen(),
    ),
    _Tile(
      label:   'Export',
      icon:    Icons.download_rounded,
      color:   const Color(0xFF78909C),
      builder: (_) => const ExportScreen(),
    ),
    _Tile(
      label:   'Settings',
      icon:    Icons.settings_rounded,
      color:   const Color(0xFF90A4AE),
      builder: (_) => const SettingsScreen(),
    ),
  ];

  late final List<_Tile> _allTiles = [
    ..._monitoringTiles,
    ..._forecastTiles,
    ..._alertsTiles,
    ..._communityTiles,
    ..._analyticsTiles,
  ];

  List<_Tile> get _filteredTiles => _query.isEmpty
      ? _allTiles
      : _allTiles
          .where((t) => t.label.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  void _open(BuildContext ctx, _Tile tile) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: tile.builder,
        settings: RouteSettings(name: tile.label),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final liveAsync  = ref.watch(biharLiveProvider);
    final badgeCount = ref.watch(alertsBadgeProvider);
    final t          = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: _buildAppBar(t, badgeCount),
      floatingActionButton: _buildFab(context, t),
      body: liveAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: t.accent)),
        error:   (e, _) => _errorView(context, e, t),
        data:    (live) => _buildBody(context, live, t),
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
            child: const Text(
              'OpsFlood Bihar',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 18, letterSpacing: -0.3,
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
              child: IconButton(
                icon: Icon(Icons.notifications_rounded, color: t.textSecondary),
                tooltip: 'Alerts',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
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
      backgroundColor: AppPalette.critical,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.sos_rounded),
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
                Text('Could not load live data',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
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

  Widget _buildBody(BuildContext ctx, BiharLiveState live, RiverColors t) {
    return refreshIndicator(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SummaryStrip(
                critical:   live.criticalCount,
                severe:     live.severeCount,
                warning:    live.warningCount,
                safe:       live.safeCount,
                noData:     live.noDataCount,
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
                childAspectRatio: 2.4,
              ),
              itemCount: 4,
              itemBuilder: (_, i) => [
                Td3StatTile(
                  icon:       Icons.crisis_alert_rounded,
                  value:      '${live.criticalCount}',
                  label:      'Critical',
                  valueColor: AppPalette.critical,
                  // ✔ AlertsScreen is the correct routable screen for critical tap
                  onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => const AlertsScreen())),
                ),
                Td3StatTile(
                  icon:       Icons.warning_amber_rounded,
                  value:      '${live.warningCount}',
                  label:      'Warning',
                  valueColor: AppPalette.warning,
                  onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => const AlertsScreen())),
                ),
                Td3StatTile(
                  icon:       Icons.check_circle_outline_rounded,
                  value:      '${live.safeCount}',
                  label:      'Safe',
                  valueColor: AppPalette.safe,
                ),
                Td3StatTile(
                  icon:       Icons.sensors_off_rounded,
                  value:      '${live.noDataCount}',
                  label:      'No Data',
                  valueColor: t.textSecondary,
                ),
              ][i],
            ),
          ),

          _sectionHeader(ctx, t, 'Monitoring & Maps',
              Icons.radar_rounded, const Color(0xFF00B0FF)),
          _tileGrid(ctx, t, _monitoringTiles),

          _sectionHeader(ctx, t, 'Forecast & AI',
              Icons.auto_graph_rounded, const Color(0xFF7B2FF7)),
          _tileGrid(ctx, t, _forecastTiles),

          _sectionHeader(ctx, t, 'Alerts & Safety',
              Icons.crisis_alert_rounded, AppPalette.critical),
          _tileGrid(ctx, t, _alertsTiles),

          _sectionHeader(ctx, t, 'Community',
              Icons.people_rounded, const Color(0xFF66BB6A)),
          _tileGrid(ctx, t, _communityTiles),

          _sectionHeader(ctx, t, 'Analytics & Tools',
              Icons.bar_chart_rounded, const Color(0xFF26C6DA)),
          _tileGrid(ctx, t, _analyticsTiles),

          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext ctx, RiverColors t,
    String label, IconData icon, Color color,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Td3SectionHeader(label, accentColor: color, showLine: false),
          ],
        ),
      ),
    );
  }

  Widget _tileGrid(BuildContext ctx, RiverColors t, List<_Tile> tiles) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   3,
          crossAxisSpacing: 10,
          mainAxisSpacing:  10,
          childAspectRatio: 1.0,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) => _LauncherTile(
          tile: tiles[i],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _SearchSheet(
        tiles:  _allTiles,
        onOpen: (tile) {
          Navigator.pop(sheetCtx);
          _open(ctx, tile);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LauncherTile
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
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      c.withValues(alpha: 0.30),
                      c.withValues(alpha: 0.08),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: c.withValues(alpha: 0.35), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color:      c.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset:     const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(tile.icon, color: c, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  tile.label,
                  style: TextStyle(
                    color: t.textPrimary, fontSize: 11,
                    fontWeight: FontWeight.w600, height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
      : widget.tiles
          .where((t) => t.label.toLowerCase().contains(_q.toLowerCase()))
          .toList();

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
                color: t.stroke,
                borderRadius: BorderRadius.circular(2)),
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
                return Td3Card(
                  accentColor: tile.color,
                  elevation:   Td3.elevLow,
                  onTap:       () => widget.onOpen(tile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: tile.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(tile.icon, color: tile.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tile.label,
                          style: TextStyle(
                            color:      t.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize:   14,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: t.textSecondary, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
