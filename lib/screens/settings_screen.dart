// lib/screens/settings_screen.dart  v3.0  (15 Jun 2026)
//
// v3.0:
//   • Converted to ConsumerStatefulWidget so each section tracks its own
//     expanded/collapsed bool locally (no external state needed).
//   • Every section is collapsible — animated with AnimatedCrossFade.
//   • ALL tiles are wired to their correct Routes constant.
//   • Added missing tiles: Weather, Rainfall Forecast, AI Predictor, Predict,
//     Bihar River Map, India River Explorer, Crowd Reports, Incident Report,
//     SOS, Evacuation Routes, News Feed.
//   • Appearance (theme grid) section is also collapsible.
//   • Sections default to expanded; tap header chevron to collapse.
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
  // Track expanded state per section key
  final Map<String, bool> _expanded = {
    'appearance':    true,
    'account':       true,
    'data':          true,
    'tools':         true,
    'maps':          true,
    'weather':       true,
    'community':     true,
    'prediction':    true,
    'news':          true,
    'admin':         true,
  };

  void _toggle(String key) {
    HapticFeedback.selectionClick();
    setState(() => _expanded[key] = !(_expanded[key] ?? true));
  }

  bool _isOpen(String key) => _expanded[key] ?? true;

  // ── Theme mode metadata ───────────────────────────────────────────────────
  static const _themes = [
    (
      AppThemeMode.system,
      Icons.brightness_auto_rounded,
      'Auto',
      'Follows OS light / dark setting',
      Color(0xFF94A3B8),
    ),
    (
      AppThemeMode.light,
      Icons.wb_sunny_rounded,
      'Day River',
      'Warm gold — bright daytime UI',
      Color(0xFFFFB800),
    ),
    (
      AppThemeMode.dark,
      Icons.nights_stay_rounded,
      'Night River',
      'Deep abyss with gold accents',
      Color(0xFFFFD966),
    ),
    (
      AppThemeMode.sunset,
      Icons.wb_twilight_rounded,
      'Sunset Warm',
      'Red-orange fiery glow',
      Color(0xFFFF6B35),
    ),
    (
      AppThemeMode.ocean,
      Icons.water_rounded,
      'Deep Ocean',
      'Cyan + midnight navy',
      Color(0xFF00C6FF),
    ),
    (
      AppThemeMode.roboticDark,
      Icons.memory_rounded,
      'Tactical Dark',
      'Amber HUD on near-black',
      Color(0xFFf59e0b),
    ),
    (
      AppThemeMode.roboticLight,
      Icons.developer_board_rounded,
      'Tactical Light',
      'Amber HUD on light surface',
      Color(0xFFB45309),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final mode     = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          const Td3AppBar(title: 'Settings', subtitle: 'App preferences'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Appearance ────────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'appearance',
                  icon:    Icons.palette_rounded,
                  title:   'Appearance',
                  open:    _isOpen('appearance'),
                  onToggle: () => _toggle('appearance'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: _buildThemeGrid(context, t, mode, notifier),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Account ───────────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'account',
                  icon:    Icons.manage_accounts_rounded,
                  title:   'Account',
                  open:    _isOpen('account'),
                  onToggle: () => _toggle('account'),
                  child: Column(children: [
                    _tile(t, Icons.person_outline,
                        'Profile', Routes.profile),
                    _tile(t, Icons.notifications_outlined,
                        'Notification Settings', Routes.notificationSettings),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Data & Analytics ──────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'data',
                  icon:    Icons.analytics_rounded,
                  title:   'Data & Analytics',
                  open:    _isOpen('data'),
                  onToggle: () => _toggle('data'),
                  child: Column(children: [
                    _tile(t, Icons.bar_chart_rounded,
                        'Analytics Dashboard', Routes.analytics),
                    _tile(t, Icons.history_rounded,
                        'Historical Analytics', Routes.historicalAnalytics),
                    _tile(t, Icons.download_rounded,
                        'Export Data', Routes.export_),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Tools ─────────────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'tools',
                  icon:    Icons.build_circle_outlined,
                  title:   'Tools',
                  open:    _isOpen('tools'),
                  onToggle: () => _toggle('tools'),
                  child: Column(children: [
                    _tile(t, Icons.sensors,
                        'Live Stations', Routes.liveStations),
                    _tile(t, Icons.grid_view_rounded,
                        'State Matrix', Routes.stateMatrix),
                    _tile(t, Icons.monitor_heart_outlined,
                        'River Monitor', Routes.riverMonitor),
                    _tile(t, Icons.info_outline,
                        'Model Info', Routes.modelInfo),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Maps ──────────────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'maps',
                  icon:    Icons.map_outlined,
                  title:   'Maps',
                  open:    _isOpen('maps'),
                  onToggle: () => _toggle('maps'),
                  child: Column(children: [
                    _tile(t, Icons.layers_outlined,
                        'Flood Command Map', Routes.map),
                    _tile(t, Icons.water_damage_outlined,
                        'Bihar River Map', Routes.biharRiverMap),
                    _tile(t, Icons.public_rounded,
                        'India River Explorer', Routes.indiaRiverExplorer),
                    _tile(t, Icons.alt_route_rounded,
                        'Evacuation Routes', Routes.evacuation),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Weather ───────────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'weather',
                  icon:    Icons.cloud_outlined,
                  title:   'Weather',
                  open:    _isOpen('weather'),
                  onToggle: () => _toggle('weather'),
                  child: Column(children: [
                    _tile(t, Icons.wb_sunny_outlined,
                        'Weather', Routes.weather),
                    _tile(t, Icons.thunderstorm_outlined,
                        'Rainfall Forecast', Routes.rainfallForecast),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Prediction / AI ───────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'prediction',
                  icon:    Icons.auto_awesome_rounded,
                  title:   'Prediction & AI',
                  open:    _isOpen('prediction'),
                  onToggle: () => _toggle('prediction'),
                  child: Column(children: [
                    _tile(t, Icons.psychology_rounded,
                        'AI Predictor', Routes.aiPredictor),
                    _tile(t, Icons.query_stats_rounded,
                        'Manual Predict', Routes.predict),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Community ─────────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'community',
                  icon:    Icons.people_outline,
                  title:   'Community',
                  open:    _isOpen('community'),
                  onToggle: () => _toggle('community'),
                  child: Column(children: [
                    _tile(t, Icons.feed_outlined,
                        'Crowd Reports', Routes.crowdReports),
                    _tile(t, Icons.report_outlined,
                        'Incident Report', Routes.incidentReport),
                    _tile(t, Icons.sos_rounded,
                        'SOS & Emergency', Routes.sos),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── News ──────────────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'news',
                  icon:    Icons.newspaper_rounded,
                  title:   'News',
                  open:    _isOpen('news'),
                  onToggle: () => _toggle('news'),
                  child: Column(children: [
                    _tile(t, Icons.article_outlined,
                        'News Feed', Routes.news),
                  ]),
                ),

                const SizedBox(height: 12),

                // ── Administration ────────────────────────────────────────────
                _CollapsibleSection(
                  t:       t,
                  sectionKey: 'admin',
                  icon:    Icons.admin_panel_settings_outlined,
                  title:   'Administration',
                  open:    _isOpen('admin'),
                  onToggle: () => _toggle('admin'),
                  child: Column(children: [
                    _tile(t, Icons.dashboard_customize_outlined,
                        'Admin Dashboard', Routes.adminDashboard),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── App version footer ─────────────────────────────────────────
                Center(
                  child: Text(
                    'OpsFlood v1.0.0  •  Bihar Flood Command',
                    style: TextStyle(
                      color:    t.textSecondary.withOpacity(0.5),
                      fontSize: 11,
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

  // ── Theme grid ─────────────────────────────────────────────────────────────
  Widget _buildThemeGrid(
    BuildContext ctx,
    RiverColors t,
    AppThemeMode current,
    dynamic notifier,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _themes.map((item) {
        final (themeMode, icon, label, desc, accentColor) = item;
        final selected = current == themeMode;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            notifier.setMode(themeMode);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve:    Curves.easeOut,
            width: (MediaQuery.of(ctx).size.width - 52) / 2,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.12)
                  : t.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:  selected ? accentColor : t.stroke.withValues(alpha: 0.5),
                width:  selected ? 1.5 : 1.0,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color:      accentColor.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset:     const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color:        accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                            width: 1),
                      ),
                      child: Icon(icon, color: accentColor, size: 18),
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: accentColor, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(
                    color:      selected ? accentColor : t.textPrimary,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    height:     1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    color:    t.textSecondary,
                    fontSize: 10,
                    height:   1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tile helper ────────────────────────────────────────────────────────────
  Widget _tile(
    RiverColors t,
    IconData icon,
    String label,
    String route,
  ) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pushNamed(route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:        t.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: t.accent, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:      t.textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: t.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      );
}

// ── Collapsible section widget ─────────────────────────────────────────────
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
          // ── Tappable header ──────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color:        t.accent.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: t.accent, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color:         t.accent,
                        fontSize:      11,
                        fontWeight:    FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns:    open ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 220),
                    curve:    Curves.easeOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: t.textSecondary,
                      size:  20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Animated body ────────────────────────────────────────────────
          AnimatedCrossFade(
            duration:       const Duration(milliseconds: 220),
            sizeCurve:      Curves.easeOut,
            firstCurve:     Curves.easeOut,
            secondCurve:    Curves.easeIn,
            crossFadeState: open
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: t.stroke.withOpacity(0.3)),
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
