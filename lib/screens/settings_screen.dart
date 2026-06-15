// lib/screens/settings_screen.dart  v2.0 — theme picker wired
// Adds "Appearance" section with live theme switcher for all 7 AppThemeMode
// options. Uses themeModeProvider.notifier.setMode() — persisted via SharedPrefs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/theme_provider.dart';
import '../app_router.dart';

class SettingsScreen extends ConsumerWidget {
  static const String route = Routes.settings;
  const SettingsScreen({super.key});

  // ── Theme mode metadata ────────────────────────────────────────────────────
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
  Widget build(BuildContext context, WidgetRef ref) {
    final t        = RiverColors.of(context);
    final mode     = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          const Td3AppBar(title: 'Settings', subtitle: 'App preferences'),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Appearance (theme picker) ─────────────────────────────
                _sectionHeader(t, 'Appearance', Icons.palette_rounded),
                const SizedBox(height: 8),
                _buildThemeGrid(context, t, mode, notifier),

                const SizedBox(height: 20),

                // ── Account ───────────────────────────────────────────────
                _section(t, 'Account', [
                  _tile(context, t, Icons.person_outline,
                      'Profile', Routes.profile),
                  _tile(context, t, Icons.notifications_outlined,
                      'Notification Settings', Routes.notificationSettings),
                ]),

                const SizedBox(height: 16),

                // ── Data & Analytics ──────────────────────────────────────
                _section(t, 'Data & Analytics', [
                  _tile(context, t, Icons.bar_chart_rounded,
                      'Analytics Dashboard', Routes.analytics),
                  _tile(context, t, Icons.history_rounded,
                      'Historical Analytics', Routes.historicalAnalytics),
                  _tile(context, t, Icons.download_rounded,
                      'Export Data', Routes.export_),
                ]),

                const SizedBox(height: 16),

                // ── Tools ─────────────────────────────────────────────────
                _section(t, 'Tools', [
                  _tile(context, t, Icons.sensors,
                      'Live Stations', Routes.liveStations),
                  _tile(context, t, Icons.grid_view_rounded,
                      'State Matrix', Routes.stateMatrix),
                  _tile(context, t, Icons.monitor_heart_outlined,
                      'River Monitor', Routes.riverMonitor),
                  _tile(context, t, Icons.info_outline,
                      'Model Info', Routes.modelInfo),
                ]),

                const SizedBox(height: 16),

                // ── Administration ────────────────────────────────────────
                _section(t, 'Administration', [
                  _tile(context, t, Icons.admin_panel_settings_outlined,
                      'Admin Dashboard', Routes.adminDashboard),
                ]),

                const SizedBox(height: 32),
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
    _ThemeModeNotifier notifier,
  ) {
    return Wrap(
      spacing:     10,
      runSpacing:  10,
      children: _themes.map((item) {
        final (themeMode, icon, label, desc, accentColor) = item;
        final selected = current == themeMode;

        return GestureDetector(
          onTap: () => notifier.setMode(themeMode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve:    Curves.easeOut,
            width: (MediaQuery.of(ctx).size.width - 42) / 2,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.12)
                  : t.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? accentColor
                    : t.stroke.withValues(alpha: 0.5),
                width: selected ? 1.5 : 1.0,
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

  // ── Section header (plain label, not inside a card) ────────────────────────
  Widget _sectionHeader(RiverColors t, String title, IconData icon) =>
      Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:        t.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: t.accent, size: 15),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color:         t.accent,
              fontSize:      11,
              fontWeight:    FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      );

  // ── Card section (existing style, unchanged) ───────────────────────────────
  Widget _section(RiverColors t, String title, List<Widget> children) =>
      Td3Card(
        elevation: Td3.elevMid,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title,
                style: TextStyle(
                  color:         t.textSecondary,
                  fontSize:      11,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      );

  Widget _tile(
    BuildContext ctx,
    RiverColors t,
    IconData icon,
    String label,
    String route,
  ) =>
      ListTile(
        dense:   true,
        leading: Icon(icon, color: t.accent, size: 20),
        title:   Text(label,
            style: TextStyle(color: t.textPrimary, fontSize: 14)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: t.textSecondary, size: 18),
        onTap: () => Navigator.of(ctx).pushNamed(route),
      );
}

// Private type alias so the method signature compiles without exposing the
// private class name across files.
typedef _ThemeModeNotifier
    = Notifier<AppThemeMode>;
