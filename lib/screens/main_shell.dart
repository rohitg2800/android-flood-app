// lib/screens/main_shell.dart  nav-v3 (full UI audit)
//
// v3 changes:
//   • _MoreTile: icon is Center()-wrapped inside badge — was bare Icon() causing
//     glyph-level mis-alignment on certain icon glyphs
//   • _MoreSheet: GridView childAspectRatio 0.82 → 0.88 (taller tile = label
//     never clipped), crossAxisSpacing 12→10, runSpacing 10→12
//   • _MoreSheet: title row gets accent gradient + subtitle text
//   • _MoreSheet items updated to use _P custom icons/colors matching dashboard
//   • MainShell: floatingActionButton bottom padding 4→8 so it never overlaps
//     the bottom nav underline indicator
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alerts_provider.dart';
import '../app_router.dart';
import '../utils/haptic_service.dart';
import '../main.dart' show navigatorKey;
import 'critical_alert_screen.dart';
import 'dashboard_screen.dart';
import 'alerts_screen.dart';
import 'bihar_river_map_screen.dart';
import 'settings_screen.dart';
import 'community_screen.dart';
import 'ai_prediction_screen.dart';
import 'incident_report_screen.dart';
import 'crowd_report_feed_screen.dart';
import 'evacuation_routes_screen.dart';
import 'india_river_explorer_screen.dart';
import 'rainfall_forecast_screen.dart';
import 'news_feed_screen.dart';
import 'sos_screen.dart';
import 'weather_screen.dart';
import 'live_stations_screen.dart';
import 'state_matrix_screen.dart';
import 'historical_analytics_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'export_screen.dart';
import 'admin_dashboard_screen.dart';
import 'model_info_screen.dart';
import 'river_monitor_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  static const String route = Routes.shell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  final Set<String> _shownAlertIds = {};

  static final _screens = [
    const DashboardScreen(),
    const RiverMonitorScreen(),
    const AlertsScreen(),
    const BiharRiverMapScreen(),
    const CommunityScreen(),
    const SettingsScreen(),
  ];

  static const _navItems = [
    Td3NavItem(icon: Icons.home_outlined,              activeIcon: Icons.home_rounded,              label: 'Home'),
    Td3NavItem(icon: Icons.water_outlined,             activeIcon: Icons.water_rounded,             label: 'Monitors'),
    Td3NavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded,     label: 'Alerts'),
    Td3NavItem(icon: Icons.map_outlined,               activeIcon: Icons.map_rounded,               label: 'Map'),
    Td3NavItem(icon: Icons.people_outline,             activeIcon: Icons.people_rounded,            label: 'Community'),
    Td3NavItem(icon: Icons.tune_rounded,               activeIcon: Icons.settings_rounded,          label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<List<FloodAlert>>(alertsProvider, (prev, alerts) {
      final criticals = alerts.where(
        (a) =>
            a.severity == AlertSeverity.critical ||
            a.severity == AlertSeverity.emergency,
      ).toList();

      for (final alert in criticals) {
        final uid = '${alert.title}_${alert.currentLevel.toStringAsFixed(1)}';
        if (_shownAlertIds.contains(uid)) continue;
        _shownAlertIds.add(uid);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          HapticService.forSeverity(HapticSeverity.critical);
          showCriticalAlertOverlay(
            context,
            stationName:  alert.title,
            riverName:    alert.river,
            currentLevel: alert.currentLevel,
            dangerLevel:  alert.thresholdLevel,
            district:     alert.district,
            onViewMap:    () {
              // Bihar alerts should bring user into the Bihar river map context.
              navigatorKey.currentState?.pushNamed(Routes.biharRiverMap);
            },
            onEvacuate:   () => navigatorKey.currentState?.pushNamed(Routes.evacuation),
          );
        });
        break;
      }
    });

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:          t.navBg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8), // v3: was 4 — clears indicator line
        child: FloatingActionButton.small(
          heroTag:         'more_fab',
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          tooltip:         'More features',
          onPressed:       () => _showMoreSheet(context, t),
          child:           const Icon(Icons.apps_rounded, size: 20),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: Td3BottomNav(
        currentIndex: _index,
        onTap:        (i) => setState(() => _index = i),
        items:        _navItems,
      ),
    );
  }

  void _showMoreSheet(BuildContext ctx, RiverColors t) {
    showModalBottomSheet<void>(
      context:            ctx,
      backgroundColor:    t.navBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _MoreSheet(theme: t),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
class _MoreSheet extends StatelessWidget {
  final RiverColors theme;
  const _MoreSheet({required this.theme});

  // v3: icons/colors aligned with _P palette from dashboard
  static const _items = [
    _MI('AI Predictor',    Icons.psychology_rounded,             Color(0xFF7E57C2), Routes.aiPredictor),
    _MI('Predict',         Icons.trending_up_rounded,            Color(0xFF9C27B0), Routes.predict),
    _MI('Model Info',      Icons.info_rounded,                   Color(0xFF7E57C2), Routes.modelInfo),
    _MI('Bihar Map',       Icons.map_rounded,                    Color(0xFF00897B), Routes.biharRiverMap),
    _MI('River Explorer',  Icons.travel_explore_rounded,         Color(0xFF0097A7), Routes.indiaRiverExplorer),
    _MI('Live Stations',   Icons.broadcast_on_personal_rounded,  Color(0xFF26A69A), Routes.liveStations),
    _MI('River Monitor',   Icons.monitor_heart_outlined,         Color(0xFF2196F3), Routes.riverMonitor),
    _MI('State Matrix',    Icons.grid_view_rounded,              Color(0xFF3949AB), Routes.stateMatrix),
    _MI('Weather',         Icons.wb_sunny_rounded,               Color(0xFFFF8F00), Routes.weather),
    _MI('Rainfall',        Icons.grain_rounded,                  Color(0xFF1976D2), Routes.rainfallForecast),
    _MI('Evacuation',      Icons.directions_run_rounded,         Color(0xFFF57F17), Routes.evacuation),
    _MI('Emergency SOS',   Icons.health_and_safety_rounded,      Color(0xFFC62828), Routes.sos),
    _MI('Report Incident', Icons.report_problem_rounded,         Color(0xFFE64A19), Routes.incidentReport),
    _MI('Crowd Feed',      Icons.forum_rounded,                  Color(0xFF6A1B9A), Routes.crowdReports),
    _MI('News Feed',       Icons.article_rounded,                Color(0xFFF9A825), Routes.news),
    _MI('Analytics',       Icons.area_chart_rounded,             Color(0xFF0288D1), Routes.analytics),
    _MI('Historical',      Icons.timeline_rounded,               Color(0xFF6D4C41), Routes.historicalAnalytics),
    _MI('Export Data',     Icons.upload_file_rounded,            Color(0xFF455A64), Routes.export_),
    _MI('Admin',           Icons.admin_panel_settings_rounded,   Color(0xFFB71C1C), Routes.adminDashboard),
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: t.stroke.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // ── Header ──
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => LinearGradient(
                  colors: [t.accent, t.metricColor],
                ).createShader(r),
                child: const Icon(Icons.apps_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text('More Features', style: TextStyle(
                color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.w800,
              )),
              const Spacer(),
              Text('${_items.length} screens', style: TextStyle(
                color: t.textSecondary, fontSize: 11, fontWeight: FontWeight.w500,
              )),
            ],
          ),
          const SizedBox(height: 16),
          // ── Grid ──
          GridView.count(
            crossAxisCount:   4,
            shrinkWrap:       true,
            physics:          const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing:  12,
            childAspectRatio: 0.88,   // v3: was 0.82 — label had no room
            children: _items.map((item) => _MoreTile(
              item:  item,
              theme: t,
              onTap: () {
                Navigator.of(context).pop();
                navigatorKey.currentState?.pushNamed(item.route);
              },
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _MI {
  final String   label;
  final IconData icon;
  final Color    color;
  final String   route;
  const _MI(this.label, this.icon, this.color, this.route);
}

class _MoreTile extends StatelessWidget {
  final _MI          item;
  final RiverColors  theme;
  final VoidCallback onTap;
  const _MoreTile({required this.item, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        mainAxisAlignment:  MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [
                item.color.withValues(alpha: 0.28),
                item.color.withValues(alpha: 0.08),
              ]),
              borderRadius:  BorderRadius.circular(15),
              border: Border.all(color: item.color.withValues(alpha: 0.40), width: 1),
              boxShadow: [
                BoxShadow(color: item.color.withValues(alpha: 0.18),
                    blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            // v3: Center() wraps icon — was bare Icon() causing glyph mis-alignment
            child: Center(child: Icon(item.icon, color: item.color, size: 24)),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign:  TextAlign.center,
            maxLines:   2,
            overflow:   TextOverflow.ellipsis,
            style: TextStyle(
              color:      t.textPrimary,
              fontSize:   10,
              fontWeight: FontWeight.w600,
              height:     1.25,
            ),
          ),
        ],
      ),
    );
  }
}