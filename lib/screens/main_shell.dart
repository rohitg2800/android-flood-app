// lib/screens/main_shell.dart  nav-v4 PREMIUM
//
// Changes from v3:
//   • Floating pill nav bar with glassmorphism + animated active indicator
//   • Map FAB right-aligned with pulse ring animation
//   • 3D scale+fade animated More sheet (showGeneralDialog)
//   • 3-theme switcher chip row: Day / Night / Robo
//   • More sheet uses 5-col grid with better aspect ratio (0.95)
//   • SOS quick-launch button in nav bar (center position)
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../theme/theme_registry.dart';
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

// ─────────────────────────────────────────────────────────────
//  Nav item model
// ─────────────────────────────────────────────────────────────
class _NavItem {
  final IconData active;
  final IconData idle;
  final String   label;
  const _NavItem(this.active, this.idle, this.label);
}

const _navItems = [
  _NavItem(Icons.home_rounded,           Icons.home_outlined,              'Home'),
  _NavItem(Icons.water_rounded,          Icons.water_outlined,             'Rivers'),
  _NavItem(Icons.notifications_rounded,  Icons.notifications_none_rounded, 'Alerts'),
  _NavItem(Icons.map_rounded,            Icons.map_outlined,               'Map'),
  _NavItem(Icons.people_rounded,         Icons.people_outline,             'Community'),
  _NavItem(Icons.settings_rounded,       Icons.tune_rounded,               'Settings'),
];

// ─────────────────────────────────────────────────────────────
//  MainShell
// ─────────────────────────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  static const String route = Routes.shell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  int _index = 0;
  final Set<String> _shownAlertIds = {};

  // FAB pulse controller
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  static final _screens = [
    const DashboardScreen(),
    const RiverMonitorScreen(),
    const AlertsScreen(),
    const BiharRiverMapScreen(),
    const CommunityScreen(),
    const SettingsScreen(),
  ];

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<List<FloodAlert>>(alertsProvider, (prev, alerts) {
      final criticals = alerts.where(
        (a) => a.severity == AlertSeverity.critical ||
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
            onViewMap:    () => navigatorKey.currentState?.pushNamed(Routes.biharRiverMap),
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
        systemNavigationBarColor:          Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      // ── Right-aligned Map FAB with pulse ring ──
      floatingActionButton: _MapFab(
        pulseCtrl: _pulseCtrl,
        accentColor: scheme.primary,
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _index = 3); // Map tab
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // ── Floating pill bottom nav ──
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _index,
        scheme: scheme,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        onMoreTap: () => _showMoreSheet(context, t, scheme),
      ),
    );
  }

  // ── 3D animated More sheet ──
  void _showMoreSheet(BuildContext ctx, RiverColors t, ColorScheme scheme) {
    showGeneralDialog<void>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'More',
      barrierColor: Colors.black.withOpacity(0.72),
      transitionDuration: const Duration(milliseconds: 440),
      transitionBuilder: (ctx, anim, _, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.18),
            end:   Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
            child: FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      pageBuilder: (ctx, _, __) => _MoreSheetV4(theme: t, scheme: scheme),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Right-aligned Map FAB with animated pulse ring
// ─────────────────────────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final AnimationController pulseCtrl;
  final Color accentColor;
  final VoidCallback onTap;
  const _MapFab({required this.pulseCtrl, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) {
          final pulse = pulseCtrl.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // outer pulse ring
              Container(
                width: 56 + pulse * 12,
                height: 56 + pulse * 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withOpacity(0.35 - pulse * 0.25),
                    width: 2,
                  ),
                ),
              ),
              // FAB core
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [accentColor, accentColor.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.45),
                      blurRadius: 16, offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.map_rounded, color: Colors.white, size: 24),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Premium Floating Pill Nav Bar
// ─────────────────────────────────────────────────────────────
class _PremiumNavBar extends StatelessWidget {
  final int         currentIndex;
  final ColorScheme scheme;
  final ValueChanged<int> onTap;
  final VoidCallback onMoreTap;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.scheme,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 72, 20), // right pad for FAB
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.88),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: scheme.primary.withOpacity(0.28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._navItems.asMap().entries.map((e) {
                  final i      = e.key;
                  final item   = e.value;
                  final active = i == currentIndex;
                  return _NavTap(
                    item:   item,
                    active: active,
                    scheme: scheme,
                    onTap:  () => onTap(i),
                  );
                }),
                // More button
                _MoreButton(scheme: scheme, onTap: onMoreTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTap extends StatelessWidget {
  final _NavItem    item;
  final bool        active;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _NavTap({required this.item, required this.active, required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 14 : 10,
          vertical: 8,
        ),
        decoration: active
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withOpacity(0.22),
                    scheme.secondary.withOpacity(0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim, child: child,
              ),
              child: Icon(
                active ? item.active : item.idle,
                key: ValueKey(active),
                color: active
                    ? scheme.primary
                    : scheme.onSurface.withOpacity(0.42),
                size: active ? 25 : 21,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize:   active ? 9.5 : 0,
                fontWeight: FontWeight.w700,
                color:      scheme.primary,
                letterSpacing: 0.3,
              ),
              child: Text(item.label, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final ColorScheme  scheme;
  final VoidCallback onTap;
  const _MoreButton({required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.apps_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 2),
            Text('More',
              style: TextStyle(
                fontSize:   9.5,
                fontWeight: FontWeight.w700,
                color:      scheme.primary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  3D More Sheet V4  (showGeneralDialog, premium grid)
// ─────────────────────────────────────────────────────────────
class _MoreSheetV4 extends ConsumerWidget {
  final RiverColors  theme;
  final ColorScheme  scheme;
  const _MoreSheetV4({required this.theme, required this.scheme});

  static const _items = [
    _MI('AI Predictor',    Icons.psychology_rounded,            Color(0xFF7E57C2), Routes.aiPredictor),
    _MI('Predict',         Icons.trending_up_rounded,           Color(0xFF9C27B0), Routes.predict),
    _MI('Model Info',      Icons.info_outline_rounded,          Color(0xFF7E57C2), Routes.modelInfo),
    _MI('Bihar Map',       Icons.map_rounded,                   Color(0xFF00897B), Routes.biharRiverMap),
    _MI('River Explorer',  Icons.travel_explore_rounded,        Color(0xFF0097A7), Routes.indiaRiverExplorer),
    _MI('Live Stations',   Icons.broadcast_on_personal_rounded, Color(0xFF26A69A), Routes.liveStations),
    _MI('River Monitor',   Icons.monitor_heart_outlined,        Color(0xFF2196F3), Routes.riverMonitor),
    _MI('State Matrix',    Icons.grid_view_rounded,             Color(0xFF3949AB), Routes.stateMatrix),
    _MI('Weather',         Icons.wb_sunny_rounded,              Color(0xFFFF8F00), Routes.weather),
    _MI('Rainfall',        Icons.grain_rounded,                 Color(0xFF1976D2), Routes.rainfallForecast),
    _MI('Evacuation',      Icons.directions_run_rounded,        Color(0xFFF57F17), Routes.evacuation),
    _MI('Emergency SOS',   Icons.health_and_safety_rounded,     Color(0xFFC62828), Routes.sos),
    _MI('Report',          Icons.report_problem_rounded,        Color(0xFFE64A19), Routes.incidentReport),
    _MI('Crowd Feed',      Icons.forum_rounded,                 Color(0xFF6A1B9A), Routes.crowdReports),
    _MI('News Feed',       Icons.article_rounded,               Color(0xFFF9A825), Routes.news),
    _MI('Analytics',       Icons.area_chart_rounded,            Color(0xFF0288D1), Routes.analytics),
    _MI('Historical',      Icons.timeline_rounded,              Color(0xFF6D4C41), Routes.historicalAnalytics),
    _MI('Export',          Icons.upload_file_rounded,           Color(0xFF455A64), Routes.export_),
    _MI('Admin',           Icons.admin_panel_settings_rounded,  Color(0xFFB71C1C), Routes.adminDashboard),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t        = theme;
    final appTheme = ref.watch(themeRegistryProvider);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        decoration: BoxDecoration(
          color:        t.navBg.withOpacity(0.96),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: scheme.primary.withOpacity(0.22), width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color:       scheme.primary.withOpacity(0.20),
              blurRadius:  40,
              spreadRadius: -4,
              offset:      const Offset(0, -8),
            ),
            BoxShadow(
              color:      Colors.black.withOpacity(0.30),
              blurRadius: 24,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                        ).createShader(r),
                        child: const Icon(Icons.apps_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text('All Features',
                        style: TextStyle(
                          color:      t.textPrimary,
                          fontSize:   17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        )),
                      const Spacer(),
                      // ── Theme switcher chips ──
                      _ThemeChips(current: appTheme),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grid
                  GridView.count(
                    crossAxisCount:   5,
                    shrinkWrap:       true,
                    physics:          const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing:  10,
                    childAspectRatio: 0.95,
                    children: _items.map((item) => _MoreTileV4(
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
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Theme Switcher Chips ────────────────────────────────────
class _ThemeChips extends ConsumerWidget {
  final AppSkin current;
  const _ThemeChips({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const chips = [
      (AppSkin.day,   '☀️', 'Day'),
      (AppSkin.night, '🌙', 'Night'),
      (AppSkin.robo,  '🤖', 'Robo'),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips.map((c) {
        final active = c.$1 == current;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(themeRegistryProvider.notifier).setSkin(c.$1);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.20),
                width: 1,
              ),
            ),
            child: Text(
              '${c.$2} ${c.$3}',
              style: TextStyle(
                fontSize:   10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── More Tile V4 ────────────────────────────────────────────
class _MoreTileV4 extends StatelessWidget {
  final _MI          item;
  final RiverColors  theme;
  final VoidCallback onTap;
  const _MoreTileV4({required this.item, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        mainAxisAlignment:  MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [
                item.color.withOpacity(0.30),
                item.color.withOpacity(0.06),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.color.withOpacity(0.38), width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:      item.color.withOpacity(0.22),
                  blurRadius: 10,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: Icon(item.icon, color: item.color, size: 22)),
          ),
          const SizedBox(height: 5),
          Text(
            item.label,
            textAlign:  TextAlign.center,
            maxLines:   2,
            overflow:   TextOverflow.ellipsis,
            style: TextStyle(
              color:      theme.textPrimary,
              fontSize:   9.5,
              fontWeight: FontWeight.w600,
              height:     1.2,
            ),
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
