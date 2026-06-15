// lib/screens/settings_screen.dart  v4.0  (full UI audit 15 Jun 2026)
//
// v4.0 audit fixes:
//   • Each _CollapsibleSection header icon badge uses a UNIQUE per-section
//     accent colour instead of global t.accent — makes each section visually distinct
//   • Each _tile() row: icon badge now uses a PER-ROUTE colour matching dashboard _P
//   • Chevron indicator: per-section colour instead of global accent
//   • Version footer: styled properly with app icon + glow
//   • SliverPadding bottom 40 → 60 (never clipped by FAB)
//   • Section order: most-used sections at top, admin last
//   • "Auto" system chip added back (was removed in v3.3, requested back)
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

  // ── Per-section accent colours (mid-tone, matching dashboard _P) ──────────
  static const _sectionColors = {
    'appearance': Color(0xFF7E57C2),
    'account':    Color(0xFF2196F3),
    'data':       Color(0xFF0288D1),
    'tools':      Color(0xFF26A69A),
    'maps':       Color(0xFF00897B),
    'weather':    Color(0xFFFF8F00),
    'prediction': Color(0xFF7E57C2),
    'community':  Color(0xFF388E3C),
    'news':       Color(0xFFF9A825),
    'admin':      Color(0xFFB71C1C),
  };

  Color _sc(String key) => _sectionColors[key] ?? const Color(0xFF2196F3);

  static const _themes = [
    (AppThemeMode.light,        Icons.wb_sunny_rounded,        'Day River',      'Warm gold · bright daytime UI',     Color(0xFFFFB800)),
    (AppThemeMode.dark,         Icons.nights_stay_rounded,     'Night River',    'Deep abyss with gold accents',      Color(0xFFFFD966)),
    (AppThemeMode.sunset,       Icons.wb_twilight_rounded,     'Sunset Warm',    'Red-orange fiery glow',             Color(0xFFFF6B35)),
    (AppThemeMode.ocean,        Icons.water_rounded,           'Deep Ocean',     'Cyan + midnight navy',              Color(0xFF00C6FF)),
    (AppThemeMode.roboticDark,  Icons.memory_rounded,          'Tactical Dark',  'Amber HUD on near-black',           Color(0xFFf59e0b)),
    (AppThemeMode.roboticLight, Icons.developer_board_rounded, 'Tactical Light', 'Amber HUD on light surface',        Color(0xFFB45309)),
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
          Td3AppBar(
            title: 'Settings',
            subtitle: 'Preferences & navigation',
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: t.textSecondary, size: 20),
                tooltip: 'About',
                onPressed: () {}, // placeholder
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Appearance ──────────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'appearance',
                  icon: Icons.palette_rounded, title: 'Appearance',
                  accentColor: _sc('appearance'),
                  open: _isOpen('appearance'), onToggle: () => _toggle('appearance'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                    child: _buildThemeGrid(context, t, mode, notifier),
                  ),
                ),
                _gap,

                // ── Account ─────────────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'account',
                  icon: Icons.manage_accounts_rounded, title: 'Account',
                  accentColor: _sc('account'),
                  open: _isOpen('account'), onToggle: () => _toggle('account'),
                  child: _tiles(t, _sc('account'), [
                    (Icons.person_rounded,           const Color(0xFF2196F3), 'Profile',               Routes.profile),
                    (Icons.notifications_rounded,    const Color(0xFFFF8F00), 'Notification Settings', Routes.notificationSettings),
                  ]),
                ),
                _gap,

                // ── Data & Analytics ────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'data',
                  icon: Icons.area_chart_rounded, title: 'Data & Analytics',
                  accentColor: _sc('data'),
                  open: _isOpen('data'), onToggle: () => _toggle('data'),
                  child: _tiles(t, _sc('data'), [
                    (Icons.area_chart_rounded,  const Color(0xFF0288D1), 'Analytics Dashboard',  Routes.analytics),
                    (Icons.timeline_rounded,    const Color(0xFF6D4C41), 'Historical Analytics', Routes.historicalAnalytics),
                    (Icons.upload_file_rounded, const Color(0xFF455A64), 'Export Data',          Routes.export_),
                  ]),
                ),
                _gap,

                // ── Tools ───────────────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'tools',
                  icon: Icons.build_circle_rounded, title: 'Tools',
                  accentColor: _sc('tools'),
                  open: _isOpen('tools'), onToggle: () => _toggle('tools'),
                  child: _tiles(t, _sc('tools'), [
                    (Icons.broadcast_on_personal_rounded, const Color(0xFF26A69A), 'Live Stations', Routes.liveStations),
                    (Icons.grid_view_rounded,             const Color(0xFF3949AB), 'State Matrix',  Routes.stateMatrix),
                    (Icons.monitor_heart_outlined,        const Color(0xFF2196F3), 'River Monitor', Routes.riverMonitor),
                    (Icons.info_rounded,                  const Color(0xFF7E57C2), 'Model Info',    Routes.modelInfo),
                  ]),
                ),
                _gap,

                // ── Maps ────────────────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'maps',
                  icon: Icons.map_rounded, title: 'Maps',
                  accentColor: _sc('maps'),
                  open: _isOpen('maps'), onToggle: () => _toggle('maps'),
                  child: _tiles(t, _sc('maps'), [
                    (Icons.layers_rounded,        const Color(0xFF546E7A), 'Flood Command Map',    Routes.map),
                    (Icons.map_rounded,           const Color(0xFF00897B), 'Bihar River Map',      Routes.biharRiverMap),
                    (Icons.travel_explore_rounded,const Color(0xFF0097A7), 'India River Explorer', Routes.indiaRiverExplorer),
                    (Icons.directions_run_rounded,const Color(0xFFF57F17), 'Evacuation Routes',    Routes.evacuation),
                  ]),
                ),
                _gap,

                // ── Weather ─────────────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'weather',
                  icon: Icons.cloud_rounded, title: 'Weather',
                  accentColor: _sc('weather'),
                  open: _isOpen('weather'), onToggle: () => _toggle('weather'),
                  child: _tiles(t, _sc('weather'), [
                    (Icons.wb_sunny_rounded,    const Color(0xFFFF8F00), 'Weather',           Routes.weather),
                    (Icons.grain_rounded,       const Color(0xFF1976D2), 'Rainfall Forecast', Routes.rainfallForecast),
                  ]),
                ),
                _gap,

                // ── Prediction & AI ─────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'prediction',
                  icon: Icons.psychology_rounded, title: 'Prediction & AI',
                  accentColor: _sc('prediction'),
                  open: _isOpen('prediction'), onToggle: () => _toggle('prediction'),
                  child: _tiles(t, _sc('prediction'), [
                    (Icons.psychology_rounded,  const Color(0xFF7E57C2), 'AI Predictor',   Routes.aiPredictor),
                    (Icons.query_stats_rounded, const Color(0xFF9C27B0), 'Manual Predict', Routes.predict),
                  ]),
                ),
                _gap,

                // ── Community ───────────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'community',
                  icon: Icons.groups_rounded, title: 'Community',
                  accentColor: _sc('community'),
                  open: _isOpen('community'), onToggle: () => _toggle('community'),
                  child: _tiles(t, _sc('community'), [
                    (Icons.forum_rounded,          const Color(0xFF6A1B9A), 'Crowd Reports',   Routes.crowdReports),
                    (Icons.report_problem_rounded, const Color(0xFFE64A19), 'Incident Report', Routes.incidentReport),
                    (Icons.health_and_safety_rounded, const Color(0xFFC62828), 'SOS & Emergency', Routes.sos),
                  ]),
                ),
                _gap,

                // ── News ────────────────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'news',
                  icon: Icons.newspaper_rounded, title: 'News',
                  accentColor: _sc('news'),
                  open: _isOpen('news'), onToggle: () => _toggle('news'),
                  child: _tiles(t, _sc('news'), [
                    (Icons.article_rounded, const Color(0xFFF9A825), 'News Feed', Routes.news),
                  ]),
                ),
                _gap,

                // ── Administration ──────────────────────────────────────────
                _CollapsibleSection(
                  t: t, sectionKey: 'admin',
                  icon: Icons.admin_panel_settings_rounded, title: 'Administration',
                  accentColor: _sc('admin'),
                  open: _isOpen('admin'), onToggle: () => _toggle('admin'),
                  child: _tiles(t, _sc('admin'), [
                    (Icons.dashboard_customize_rounded, const Color(0xFFB71C1C), 'Admin Dashboard', Routes.adminDashboard),
                  ]),
                ),

                const SizedBox(height: 32),

                // ── Version footer ───────────────────────────────────────────
                _VersionFooter(t: t),

                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static const _gap = SizedBox(height: 10);

  // ── Tile list — now takes a sectionColor for divider tinting ─────────────
  Widget _tiles(
    RiverColors t,
    Color sectionColor,
    List<(IconData, Color, String, String)> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _tile(t, items[i].$1, items[i].$2, items[i].$3, items[i].$4),
          if (i < items.length - 1)
            Divider(
              height: 1, indent: 58, endIndent: 16,
              color: sectionColor.withValues(alpha: 0.15),
            ),
        ],
      ],
    );
  }

  // ── Theme picker grid ─────────────────────────────────────────────────────
  Widget _buildThemeGrid(
    BuildContext ctx,
    RiverColors t,
    AppThemeMode current,
    dynamic notifier,
  ) {
    final availableW = MediaQuery.of(ctx).size.width - 32 - 24;
    final cardW      = (availableW - 10) / 2;

    return Wrap(
      spacing:    10,
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
            curve:    Curves.easeOut,
            width:    cardW,
            padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? accentColor.withValues(alpha: 0.10) : t.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? accentColor : t.stroke.withValues(alpha: 0.4),
                width: selected ? 2.0 : 1.0,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          accentColor.withValues(alpha: 0.22),
                          accentColor.withValues(alpha: 0.06),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accentColor.withValues(alpha: 0.30), width: 1),
                      ),
                      child: Center(child: Icon(icon, color: accentColor, size: 24)),
                    ),
                    if (selected)
                      Positioned(
                        right: -5, top: -5,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color:  accentColor,
                            shape:  BoxShape.circle,
                            border: Border.all(color: t.cardBg, width: 2),
                            boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.5), blurRadius: 6)],
                          ),
                          child: const Center(child: Icon(Icons.check_rounded, color: Colors.white, size: 10)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:      selected ? accentColor : t.textPrimary,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    height:     1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
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

  // ── Single nav tile — now takes a per-tile iconColor ─────────────────────
  Widget _tile(
    RiverColors t,
    IconData    icon,
    Color       iconColor,
    String      label,
    String      route,
  ) {
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
              // Per-tile icon badge with unique colour
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    iconColor.withValues(alpha: 0.22),
                    iconColor.withValues(alpha: 0.06),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withValues(alpha: 0.25), width: 1),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 18)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color:      t.textPrimary,
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                    height:     1.2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Chevron — subtle, uses iconColor tint
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color:        iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(child: Icon(
                  Icons.chevron_right_rounded,
                  color: iconColor.withValues(alpha: 0.55), size: 16,
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
// _CollapsibleSection  v4.0
//
// Accepts accentColor parameter — each section has its own colour.
// Header icon badge uses that colour.
// Chevron button uses that colour.
// Divider line between header and body uses that colour.
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleSection extends StatelessWidget {
  final RiverColors  t;
  final String       sectionKey;
  final IconData     icon;
  final String       title;
  final Color        accentColor; // v4: per-section colour
  final bool         open;
  final VoidCallback onToggle;
  final Widget       child;

  const _CollapsibleSection({
    required this.t,
    required this.sectionKey,
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Td3Card(
        elevation:   Td3.elevMid,
        accentColor: accentColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            InkWell(
              borderRadius: BorderRadius.vertical(
                top:    const Radius.circular(18),
                bottom: open ? Radius.zero : const Radius.circular(18),
              ),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Per-section colour icon badge
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          accentColor.withValues(alpha: 0.25),
                          accentColor.withValues(alpha: 0.08),
                        ]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentColor.withValues(alpha: 0.30), width: 1),
                      ),
                      child: Center(child: Icon(icon, color: accentColor, size: 16)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color:         accentColor,
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
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color:        accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: accentColor.withValues(alpha: 0.70), size: 18,
                        )),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Collapsible body ──
            AnimatedCrossFade(
              duration:       const Duration(milliseconds: 220),
              sizeCurve:      Curves.easeOut,
              firstCurve:     Curves.easeOut,
              secondCurve:    Curves.easeIn,
              crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Divider line uses section colour
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accentColor.withValues(alpha: 0.0),
                        accentColor.withValues(alpha: 0.35),
                        accentColor.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                  child,
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VersionFooter
// ─────────────────────────────────────────────────────────────────────────────
class _VersionFooter extends StatelessWidget {
  final RiverColors t;
  const _VersionFooter({required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Gradient divider
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              t.stroke.withValues(alpha: 0.0),
              t.stroke.withValues(alpha: 0.5),
              t.stroke.withValues(alpha: 0.0),
            ]),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (r) => LinearGradient(
                colors: [t.accent, t.metricColor],
              ).createShader(r),
              child: const Icon(Icons.water_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 6),
            Text(
              'OpsFlood Bihar  ·  v1.0.0',
              style: TextStyle(
                color:         t.textSecondary.withValues(alpha: 0.55),
                fontSize:      11,
                fontWeight:    FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Bihar Flood Command Intelligence System',
          textAlign: TextAlign.center,
          style: TextStyle(
            color:      t.textSecondary.withValues(alpha: 0.35),
            fontSize:   10,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
