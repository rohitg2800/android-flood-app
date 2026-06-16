// lib/screens/main_shell.dart  nav-v4.3 PREMIUM
//
// v4.3 polish:
// - removes label-layout jitter in bottom nav by conditionally rendering labels
// - makes More button visually consistent with nav items
// - slightly increases nav bar height/tap comfort
// - trims More sheet density for smaller phones
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
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

class _NavItem {
  final IconData active;
  final IconData idle;
  final String label;
  const _NavItem(this.active, this.idle, this.label);
}

const _navItems = [
  _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
  _NavItem(Icons.water_rounded, Icons.water_outlined, 'Rivers'),
  _NavItem(Icons.notifications_rounded, Icons.notifications_none_rounded, 'Alerts'),
  _NavItem(Icons.map_rounded, Icons.map_outlined, 'Map'),
  _NavItem(Icons.people_rounded, Icons.people_outline, 'Community'),
  _NavItem(Icons.settings_rounded, Icons.tune_rounded, 'Settings'),
];

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
    final t = RiverColors.of(context);
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
            stationName: alert.title,
            riverName: alert.river,
            currentLevel: alert.currentLevel,
            dangerLevel: alert.thresholdLevel,
            district: alert.district,
            onViewMap: () => navigatorKey.currentState?.pushNamed(Routes.biharRiverMap),
            onEvacuate: () => navigatorKey.currentState?.pushNamed(Routes.evacuation),
          );
        });
        break;
      }
    });

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: _MapFab(
        pulseCtrl: _pulseCtrl,
        accentColor: scheme.primary,
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _index = 3);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  void _showMoreSheet(BuildContext ctx, RiverColors t, ColorScheme scheme) {
    showGeneralDialog<void>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'More',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 440),
      transitionBuilder: (ctx, anim, _, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
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

class _MapFab extends StatelessWidget {
  final AnimationController pulseCtrl;
  final Color accentColor;
  final VoidCallback onTap;
  const _MapFab({
    required this.pulseCtrl,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) {
          final p = pulseCtrl.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56 + p * 12,
                height: 56 + p * 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35 - p * 0.25),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
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
      padding: const EdgeInsets.fromLTRB(12, 0, 72, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(38),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.24),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.16),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ..._navItems.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  final active = i == currentIndex;
                  return Expanded(
                    child: _NavTap(
                      item: item,
                      active: active,
                      scheme: scheme,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
                Expanded(
                  child: _MoreButton(scheme: scheme, onTap: onMoreTap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTap extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _NavTap({
    required this.item,
    required this.active,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: active
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.20),
                    scheme.secondary.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                active ? item.active : item.idle,
                key: ValueKey('${item.label}_$active'),
                color: active
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.48),
                size: active ? 22 : 20,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: active
                  ? Text(
                      item.label,
                      key: ValueKey(item.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                        letterSpacing: 0.15,
                        height: 1,
                      ),
                    )
                  : const SizedBox(height: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _MoreButton({required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.apps_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(height: 2),
            Text(
              'More',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                letterSpacing: 0.15,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreSheetV4 extends ConsumerWidget {
  final RiverColors theme;
  final ColorScheme scheme;
  const _MoreSheetV4({required this.theme, required this.scheme});

  static const _items = [
    _MI('AI Predictor', Icons.psychology_rounded, Color(0xFF7E57C2), Routes.aiPredictor),
    _MI('Predict', Icons.trending_up_rounded, Color(0xFF9C27B0), Routes.predict),
    _MI('Model Info', Icons.info_outline_rounded, Color(0xFF7E57C2), Routes.modelInfo),
    _MI('Bihar Map', Icons.map_rounded, Color(0xFF00897B), Routes.biharRiverMap),
    _MI('River Explorer', Icons.travel_explore_rounded, Color(0xFF0097A7), Routes.indiaRiverExplorer),
    _MI('Live Stations', Icons.broadcast_on_personal_rounded, Color(0xFF26A69A), Routes.liveStations),
    _MI('River Monitor', Icons.monitor_heart_outlined, Color(0xFF2196F3), Routes.riverMonitor),
    _MI('State Matrix', Icons.grid_view_rounded, Color(0xFF3949AB), Routes.stateMatrix),
    _MI('Weather', Icons.wb_sunny_rounded, Color(0xFFFF8F00), Routes.weather),
    _MI('Rainfall', Icons.grain_rounded, Color(0xFF1976D2), Routes.rainfallForecast),
    _MI('Evacuation', Icons.directions_run_rounded, Color(0xFFF57F17), Routes.evacuation),
    _MI('Emergency SOS', Icons.health_and_safety_rounded, Color(0xFFC62828), Routes.sos),
    _MI('Report', Icons.report_problem_rounded, Color(0xFFE64A19), Routes.incidentReport),
    _MI('Crowd Feed', Icons.forum_rounded, Color(0xFF6A1B9A), Routes.crowdReports),
    _MI('News Feed', Icons.article_rounded, Color(0xFFF9A825), Routes.news),
    _MI('Analytics', Icons.area_chart_rounded, Color(0xFF0288D1), Routes.analytics),
    _MI('Historical', Icons.timeline_rounded, Color(0xFF6D4C41), Routes.historicalAnalytics),
    _MI('Export', Icons.upload_file_rounded, Color(0xFF455A64), Routes.export_),
    _MI('Admin', Icons.admin_panel_settings_rounded, Color(0xFFB71C1C), Routes.adminDashboard),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = theme;
    final activeSkin = ref.watch(appSkinProvider);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        decoration: BoxDecoration(
          color: t.navBg.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.20),
              blurRadius: 40,
              spreadRadius: -4,
              offset: const Offset(0, -8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                        ).createShader(r),
                        child: const Icon(Icons.apps_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'All Features',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      _SkinChips(activeSkin: activeSkin),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.92,
                    children: _items
                        .map(
                          (item) => _MoreTileV4(
                            item: item,
                            theme: t,
                            onTap: () {
                              Navigator.of(context).pop();
                              navigatorKey.currentState?.pushNamed(item.route);
                            },
                          ),
                        )
                        .toList(),
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

class _SkinChips extends ConsumerWidget {
  final AppSkin activeSkin;
  const _SkinChips({required this.activeSkin});

  static const _chips = [
    (AppSkin.deepSpace, '🌌', 'Space'),
    (AppSkin.tacticalOps, '🤖', 'Tactical'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _chips.map((c) {
        final active = c.$1 == activeSkin;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(appSkinProvider.notifier).set(c.$1);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? cs.primary.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Text(
              '${c.$2} ${c.$3}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MoreTileV4 extends StatelessWidget {
  final _MI item;
  final RiverColors theme;
  final VoidCallback onTap;
  const _MoreTileV4({required this.item, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  item.color.withValues(alpha: 0.30),
                  item.color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: item.color.withValues(alpha: 0.38),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(child: Icon(item.icon, color: item.color, size: 19)),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 9.2,
              fontWeight: FontWeight.w600,
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MI {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _MI(this.label, this.icon, this.color, this.route);
}
