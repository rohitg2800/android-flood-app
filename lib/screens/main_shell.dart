// lib/screens/main_shell.dart
// PHASE 2 — ConsumerStatefulWidget + critical alert listener
// WIRING UPDATE — Community tab (index 4) + "More" sheet for Phase 7-10 screens
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alerts_provider.dart';
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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  static const String route = '/shell';

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  final Set<String> _shownAlertIds = {};

  static const _screens = [
    DashboardScreen(),
    MonitorsScreen(),
    AlertsScreen(),
    MapScreen(),
    CommunityScreen(),   // ← Phase 10: Community now a first-class tab
    SettingsScreen(),
  ];

  static const _navItems = [
    Td3NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    Td3NavItem(
      icon: Icons.water_outlined,
      activeIcon: Icons.water_rounded,
      label: 'Monitors',
    ),
    Td3NavItem(
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
      label: 'Alerts',
    ),
    Td3NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
      label: 'Map',
    ),
    Td3NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people_rounded,
      label: 'Community',
    ),
    Td3NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
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
        final uid =
            '${alert.title}_${alert.currentLevel.toStringAsFixed(1)}';
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
            onViewMap:    () => setState(() => _index = 3),
            onEvacuate:   () => setState(() => _index = 2),
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
      // ── Floating "More" button (bottom-right, above nav bar) ──────────────
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
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endDocked,
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MoreSheet(theme: t),
    );
  }
}

// ── More Sheet ────────────────────────────────────────────────────────────────

class _MoreSheet extends StatelessWidget {
  final RiverColors theme;
  const _MoreSheet({required this.theme});

  static const _items = [
    _MoreItem('AI Predictor',      Icons.auto_graph,             Color(0xFF7B2FF7), AiPredictionScreen.route),
    _MoreItem('Rainfall Forecast', Icons.cloudy_snowing,         Color(0xFF00B0FF), RainfallForecastScreen.route),
    _MoreItem('Evacuation Routes', Icons.directions_run,         Colors.deepOrange, EvacuationRoutesScreen.route),
    _MoreItem('Report Incident',   Icons.report_problem_outlined,Colors.red,        IncidentReportScreen.route),
    _MoreItem('Crowd Feed',        Icons.dynamic_feed_outlined,  Colors.teal,       CrowdReportFeedScreen.route),
    _MoreItem('River Explorer',    Icons.water_outlined,         Color(0xFF00E5FF), IndiaRiverExplorerScreen.route),
    _MoreItem('News Feed',         Icons.newspaper_outlined,     Colors.amber,      NewsFeedScreen.route),
    _MoreItem('Emergency SOS',     Icons.sos_rounded,            Colors.red,        SosScreen.route),
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
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
                Navigator.pop(context);
                Navigator.pushNamed(context, item.route);
              },
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _MoreItem(this.label, this.icon, this.color, this.route);
}

class _MoreTile extends StatelessWidget {
  final _MoreItem item;
  final RiverColors theme;
  final VoidCallback onTap;
  const _MoreTile(
      {required this.item,
      required this.theme,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: item.color.withOpacity(0.5), width: 1),
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
