// lib/screens/settings_screen.dart  v3.2  (15 Jun 2026)
//
// v3.2:
//   • Removed 'Auto' (AppThemeMode.system) from the theme grid — gone
//   • All 6 remaining theme cards laid out in a clean 2-column Wrap
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/theme_provider.dart';
import '../app_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  static const String route = Routes.settings;
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<String, bool> _expanded = {
    'appearance': true,
    'account':    true,
    'data':       true,
    'tools':      true,
    'maps':       true,
    'weather':    false,
    'community':  false,
    'prediction': false,
    'news':       false,
    'admin':      false,
  };

  void _toggle(String key) {
    HapticFeedback.selectionClick();
    setState(() => _expanded[key] = !(_expanded[key] ?? true));
  }

  bool _isOpen(String key) => _expanded[key] ?? true;

  // Auto (system) removed — 6 explicit themes only
  static const _themes = [
    (AppThemeMode.light,        Icons.wb_sunny_rounded,        'Day River',      'Warm gold — bright daytime UI',    Color(0xFFFFB800)),
    (AppThemeMode.dark,         Icons.nights_stay_rounded,     'Night River',    'Deep abyss with gold accents',     Color(0xFFFFD966)),
    (AppThemeMode.sunset,       Icons.wb_twilight_rounded,     'Sunset Warm',    'Red-orange fiery glow',            Color(0xFFFF6B35)),
    (AppThemeMode.ocean,        Icons.water_rounded,           'Deep Ocean',     'Cyan + midnight navy',             Color(0xFF00C6FF)),
    (AppThemeMode.roboticDark,  Icons.memory_rounded,          'Tactical Dark',  'Amber HUD on near-black',          Color(0xFFf59e0b)),
    (AppThemeMode.roboticLight, Icons.developer_board_rounded, 'Tactical Light', 'Amber HUD on light surface',       Color(0xFFB45309)),
  ];

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final mode     = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const Td3AppBar(title: 'Settings', subtitle: 'Preferences & navigation'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                _CollapsibleSection(
                  t: t, sectionKey: 'appearance',
                  icon: Icons.palette_rounded, title: 'Appearance',
                  open: _isOpen('appearance'), onToggle: () => _toggle('appearance'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                    child: _buildThemeGrid(context, t, mode, notifier),
                  ),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'account',
                  icon: Icons.manage_accounts_rounded, title: 'Account',
                  open: _isOpen('account'), onToggle: () => _toggle('account'),
                  child: _tiles(t, [
                    (Icons.person_outline,         'Profile',                Routes.profile),
                    (Icons.notifications_outlined, 'Notification Settings',  Routes.notificationSettings),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'data',
                  icon: Icons.analytics_rounded, title: 'Data & Analytics',
                  open: _isOpen('data'), onToggle: () => _toggle('data'),
                  child: _tiles(t, [
                    (Icons.bar_chart_rounded,  'Analytics Dashboard',  Routes.analytics),
                    (Icons.history_rounded,    'Historical Analytics', Routes.historicalAnalytics),
                    (Icons.download_rounded,   'Export Data',          Routes.export_),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'tools',
                  icon: Icons.build_circle_outlined, title: 'Tools',
                  open: _isOpen('tools'), onToggle: () => _toggle('tools'),
                  child: _tiles(t, [
                    (Icons.sensors,                'Live Stations',  Routes.liveStations),
                    (Icons.grid_view_rounded,      'State Matrix',   Routes.stateMatrix),
                    (Icons.monitor_heart_outlined, 'River Monitor',  Routes.riverMonitor),
                    (Icons.info_outline,           'Model Info',     Routes.modelInfo),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'maps',
                  icon: Icons.map_outlined, title: 'Maps',
                  open: _isOpen('maps'), onToggle: () => _toggle('maps'),
                  child: _tiles(t, [
                    (Icons.layers_outlined,       'Flood Command Map',    Routes.map),
                    (Icons.water_damage_outlined, 'Bihar River Map',      Routes.biharRiverMap),
                    (Icons.public_rounded,        'India River Explorer', Routes.indiaRiverExplorer),
                    (Icons.alt_route_rounded,     'Evacuation Routes',    Routes.evacuation),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'weather',
                  icon: Icons.cloud_outlined, title: 'Weather',
                  open: _isOpen('weather'), onToggle: () => _toggle('weather'),
                  child: _tiles(t, [
                    (Icons.wb_sunny_outlined,    'Weather',           Routes.weather),
                    (Icons.thunderstorm_outlined,'Rainfall Forecast', Routes.rainfallForecast),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'prediction',
                  icon: Icons.auto_awesome_rounded, title: 'Prediction & AI',
                  open: _isOpen('prediction'), onToggle: () => _toggle('prediction'),
                  child: _tiles(t, [
                    (Icons.psychology_rounded,  'AI Predictor',   Routes.aiPredictor),
                    (Icons.query_stats_rounded, 'Manual Predict', Routes.predict),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'community',
                  icon: Icons.people_outline, title: 'Community',
                  open: _isOpen('community'), onToggle: () => _toggle('community'),
                  child: _tiles(t, [
                    (Icons.feed_outlined,   'Crowd Reports',   Routes.crowdReports),
                    (Icons.report_outlined, 'Incident Report', Routes.incidentReport),
                    (Icons.sos_rounded,     'SOS & Emergency', Routes.sos),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'news',
                  icon: Icons.newspaper_rounded, title: 'News',
                  open: _isOpen('news'), onToggle: () => _toggle('news'),
                  child: _tiles(t, [
                    (Icons.article_outlined, 'News Feed', Routes.news),
                  ]),
                ),
                _gap,

                _CollapsibleSection(
                  t: t, sectionKey: 'admin',
                  icon: Icons.admin_panel_settings_outlined, title: 'Administration',
                  open: _isOpen('admin'), onToggle: () => _toggle('admin'),
                  child: _tiles(t, [
                    (Icons.dashboard_customize_outlined, 'Admin Dashboard', Routes.adminDashboard),
                  ]),
                ),

                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'OpsFlood v1.0.0  •  Bihar Flood Command',
                    style: TextStyle(
                      color: t.textSecondary.withOpacity(0.45),
                      fontSize: 11, letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static const _gap = SizedBox(height: 10);

  Widget _tiles(RiverColors t, List<(IconData, String, String)> items) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _tile(t, items[i].$1, items[i].$2, items[i].$3),
          if (i < items.length - 1)
            Divider(
              height: 1, indent: 58, endIndent: 16,
              color: t.stroke.withOpacity(0.25),
            ),
        ],
      ],
    );
  }

  Widget _buildThemeGrid(BuildContext ctx, RiverColors t,
      AppThemeMode current, dynamic notifier) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _themes.map((item) {
        final (themeMode, icon, label, desc, accentColor) = item;
        final selected = current == themeMode;
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            notifier.setMode(themeMode);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: (MediaQuery.of(ctx).size.width - 54) / 2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? accentColor.withValues(alpha: 0.10) : t.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? accentColor : t.stroke.withValues(alpha: 0.4),
                width: selected ? 1.5 : 1.0,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: accentColor.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: accentColor.withValues(alpha: 0.30), width: 1),
                        ),
                        child: Center(child: Icon(icon, color: accentColor, size: 22)),
                      ),
                      if (selected)
                        Positioned(
                          right: -2, top: -2,
                          child: Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(
                              color: accentColor, shape: BoxShape.circle,
                              border: Border.all(color: t.cardBg, width: 1.5),
                              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? accentColor : t.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w700, height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary, fontSize: 10, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _tile(RiverColors t, IconData icon, String label, String route) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pushNamed(route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.accent.withOpacity(0.18), width: 1),
                ),
                child: Center(child: Icon(icon, color: t.accent, size: 18)),
              ),
              const SizedBox(width: 13),
              Expanded(child: Text(label, style: TextStyle(
                color: t.textPrimary, fontSize: 14,
                fontWeight: FontWeight.w500, height: 1.2,
              ))),
              const SizedBox(width: 4),
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(child: Icon(
                  Icons.chevron_right_rounded,
                  color: t.accent.withOpacity(0.6), size: 16,
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleSection extends StatelessWidget {
  final RiverColors  t;
  final String       sectionKey;
  final IconData     icon;
  final String       title;
  final bool         open;
  final VoidCallback onToggle;
  final Widget       child;

  const _CollapsibleSection({
    required this.t,
    required this.sectionKey,
    required this.icon,
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Td3Card(
      elevation: Td3.elevMid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: open ? Radius.zero : const Radius.circular(16),
            ),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: t.accent.withOpacity(0.20), width: 1),
                    ),
                    child: Center(child: Icon(icon, color: t.accent, size: 15)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Text(title.toUpperCase(), style: TextStyle(
                    color: t.accent, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1.3,
                  ))),
                  AnimatedRotation(
                    turns: open ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: t.textSecondary, size: 18,
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOut,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: t.stroke.withOpacity(0.25)),
                child,
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
