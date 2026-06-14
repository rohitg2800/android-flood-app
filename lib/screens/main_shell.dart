// lib/screens/main_shell.dart  nav-v1
// OpsFlood — MainShell with full navigation wiring.
//
// Changes nav-v1:
//   • _MoreSheet items use Routes.xxx constants (no bare strings).
//   • Added: Weather, State Matrix, Live Stations, Historical Analytics,
//     Analytics, Export, Admin, Model Info, River Monitor.
//   • Critical-alert overlay: "View Map" → tab 3, "Evacuate" → pushes
//     EvacuationRoutesScreen directly.
//   • SOS FAB kept; "+More" FAB retained.
//   • All Navigator.pushNamed calls go through the root navigator so
//     they are handled by AppRouter.onGenerateRoute.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alerts_provider.dart';
import '../app_router.dart';
import '../utils/haptic_service.dart';
import 'critical_alert_screen.dart';
import 'dashboard_screen.dart';
import 'monitors_screen.dart';
import 'alerts_screen.dart';
import 'map_screen.dart';
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
import 'bihar_river_map_screen.dart';
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

  // Bottom-nav tab bodies (kept alive via IndexedStack)
  static const _screens = [
    DashboardScreen(),
    MonitorsScreen(),
    AlertsScreen(),
    MapScreen(),
    CommunityScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    Td3NavItem(icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,              label: 'Home'),
    Td3NavItem(icon: Icons.water_outlined,          activeIcon: Icons.water_rounded,             label: 'Monitors'),
    Td3NavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Alerts'),
    Td3NavItem(icon: Icons.map_outlined,            activeIcon: Icons.map_rounded,               label: 'Map'),
    Td3NavItem(icon: Icons.people_outline,          activeIcon: Icons.people_rounded,            label: 'Community'),
    Td3NavItem(icon: Icons.settings_outlined,       activeIcon: Icons.settings_rounded,          label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Critical alert listener ────────────────────────────────────────────
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
            // ── View Map → Map tab
            onViewMap:  () => setState(() => _index = 3),
            // ── Evacuate → push EvacuationRoutesScreen on top of shell
            onEvacuate: () => Navigator.of(context).pushNamed(Routes.evacuation),
          );
        });
        break;
      }
    });

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: t.cardBg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: FloatingActionButton.small(
          heroTag: 'more_fab',
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          tooltip: 'More features',
          onPressed: () => _showMoreSheet(context, t),
          child: const Icon(Icons.apps_rounded, size: 20),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: Td3BottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _navItems,
      ),
    );
  }

  void _showMoreSheet(BuildContext ctx, RiverColors t) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: t.navBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MoreSheet(theme: t),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// More Sheet — all 16 extra screens, 4-column grid
// ─────────────────────────────────────────────────────────────────────────────
class _MoreSheet extends StatelessWidget {
  final RiverColors theme;
  const _MoreSheet({required this.theme});

  // All items use Routes.xxx — no bare strings
  static const _items = [
    // ── Prediction & intelligence
    _MI('AI Predictor',      Icons.auto_graph,              Color(0xFF7B2FF7), Routes.aiPredictor),
    _MI('Predict',           Icons.trending_up,             Color(0xFF9C27B0), Routes.predict),
    _MI('Model Info',        Icons.info_outline,            Color(0xFF7E57C2), Routes.modelInfo),
    // ── Water & map
    _MI('Bihar Map',         Icons.map_outlined,            Colors.blue,       Routes.biharRiverMap),
    _MI('River Explorer',    Icons.water_outlined,          Color(0xFF00E5FF), Routes.indiaRiverExplorer),
    _MI('Live Stations',     Icons.sensors,                 Color(0xFF00E676), Routes.liveStations),
    _MI('River Monitor',     Icons.monitor_heart_outlined,  Color(0xFF00B0FF), Routes.riverMonitor),
    _MI('State Matrix',      Icons.grid_view_rounded,       Color(0xFF039BE5), Routes.stateMatrix),
    // ── Weather
    _MI('Weather',           Icons.wb_sunny_outlined,       Colors.orange,     Routes.weather),
    _MI('Rainfall',          Icons.cloudy_snowing,          Color(0xFF00B0FF), Routes.rainfallForecast),
    // ── Safety
    _MI('Evacuation',        Icons.directions_run,          Colors.deepOrange, Routes.evacuation),
    _MI('Emergency SOS',     Icons.sos_rounded,             Colors.red,        Routes.sos),
    // ── Community & reports
    _MI('Report Incident',   Icons.report_problem_outlined, Colors.red,        Routes.incidentReport),
    _MI('Crowd Feed',        Icons.dynamic_feed_outlined,   Colors.teal,       Routes.crowdReports),
    // ── Info & analytics
    _MI('News Feed',         Icons.newspaper_outlined,      Colors.amber,      Routes.news),
    _MI('Analytics',         Icons.bar_chart_rounded,       Color(0xFF26C6DA), Routes.analytics),
    _MI('Historical',        Icons.history_rounded,         Color(0xFF78909C), Routes.historicalAnalytics),
    _MI('Export Data',       Icons.download_rounded,        Color(0xFF66BB6A), Routes.export_),
    // ── Admin
    _MI('Admin',             Icons.admin_panel_settings_outlined, Color(0xFFEF5350), Routes.adminDashboard),
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('More Features',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: _items.map((item) => _MoreTile(
              item: item,
              theme: t,
              onTap: () {
                Navigator.pop(context); // close sheet
                Navigator.of(context).pushNamed(item.route);
              },
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Model & tile ────────────────────────────────────────────────────────────
class _MI {
  final String   label;
  final IconData icon;
  final Color    color;
  final String   route;
  const _MI(this.label, this.icon, this.color, this.route);
}

class _MoreTile extends StatelessWidget {
  final _MI        item;
  final RiverColors theme;
  final VoidCallback onTap;
  const _MoreTile({required this.item, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.color.withOpacity(0.5), width: 1),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2),
          ),
        ],
      ),
    );
  }
}
