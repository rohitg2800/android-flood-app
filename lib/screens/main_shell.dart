// lib/screens/main_shell.dart
// PHASE 2 — ConsumerStatefulWidget + critical alert listener
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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  static const String route = '/shell';

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  // Tracks UIDs of alerts already shown this session.
  final Set<String> _shownAlertIds = {};

  static const _screens = [
    DashboardScreen(),
    MonitorsScreen(),
    AlertsScreen(),
    MapScreen(),
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
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Critical alert listener ───────────────────────────────────────────────
    // alertsProvider returns List<FloodAlert> directly.
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
            // FIX: FloodAlert has .river (not .riverName)
            riverName:    alert.river,
            currentLevel: alert.currentLevel,
            dangerLevel:  alert.thresholdLevel,
            district:     alert.district,
            onViewMap:    () => setState(() => _index = 3),
            onEvacuate:   () => setState(() => _index = 2),
          );
        });
        break; // show one at a time
      }
    });

    // ── System UI ─────────────────────────────────────────────────────────────
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
      bottomNavigationBar: Td3BottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _navItems,
      ),
    );
  }
}
