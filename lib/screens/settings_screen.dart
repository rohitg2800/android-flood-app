// lib/screens/settings_screen.dart
// WIRING UPDATE: added Profile, Analytics Hub, Historical Analytics, Model Info links
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../providers/theme_provider.dart';
import 'notification_settings_screen.dart';
import 'export_screen.dart';
import 'profile_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'historical_analytics_screen.dart';
import 'model_info_screen.dart';
import 'admin_dashboard_screen.dart';

class SettingsScreen extends StatelessWidget {
  static const String route = '/settings';
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // ── Account ────────────────────────────────────────────────────────────────
          _SectionHeader(label: 'Account', theme: t),
          _SettingsTile(
            theme: t,
            icon: Icons.person_outline,
            color: Colors.teal,
            title: 'My Profile',
            subtitle: 'View and edit your profile',
            onTap: () => Navigator.pushNamed(context, ProfileScreen.route),
          ),
          // ── App ───────────────────────────────────────────────────────────────────
          _SectionHeader(label: 'App', theme: t),
          _ThemeTile(theme: t),
          _SettingsTile(
            theme: t,
            icon: Icons.notifications_outlined,
            color: Colors.amber,
            title: 'Notifications',
            subtitle: 'Alert thresholds, FCM topics',
            onTap: () => Navigator.pushNamed(
                context, NotificationSettingsScreen.route),
          ),
          // ── Analytics ───────────────────────────────────────────────────────────
          _SectionHeader(label: 'Analytics', theme: t),
          _SettingsTile(
            theme: t,
            icon: Icons.analytics_outlined,
            color: const Color(0xFF00E5FF),
            title: 'Analytics Hub',
            subtitle: 'Historical data, forecasts, state matrix, export',
            onTap: () => Navigator.pushNamed(
                context, AnalyticsDashboardScreen.route),
          ),
          _SettingsTile(
            theme: t,
            icon: Icons.history_edu_outlined,
            color: AppPalette.cyan,
            title: 'Historical Analytics',
            subtitle: 'Past flood event timeline & charts',
            onTap: () => Navigator.pushNamed(
                context, HistoricalAnalyticsScreen.route),
          ),
          _SettingsTile(
            theme: t,
            icon: Icons.download_outlined,
            color: Colors.green,
            title: 'Export Data',
            subtitle: 'Download station data as CSV / PDF',
            onTap: () => Navigator.pushNamed(context, ExportScreen.route),
          ),
          // ── About ────────────────────────────────────────────────────────────────
          _SectionHeader(label: 'About', theme: t),
          _SettingsTile(
            theme: t,
            icon: Icons.model_training_outlined,
            color: const Color(0xFF7B2FF7),
            title: 'Model Info',
            subtitle: 'AI model architecture & accuracy metrics',
            onTap: () => Navigator.pushNamed(context, ModelInfoScreen.route),
          ),
          _SettingsTile(
            theme: t,
            icon: Icons.admin_panel_settings_outlined,
            color: Colors.deepOrange,
            title: 'Admin Dashboard',
            subtitle: 'System diagnostics & data management',
            onTap: () => Navigator.pushNamed(
                context, AdminDashboardScreen.route),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text('OpsFlood Bihar v1.0.0',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final RiverColors theme;
  const _SectionHeader({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final RiverColors theme;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.theme, required this.icon, required this.color,
    required this.title, required this.subtitle, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: TextStyle(color: t.textPrimary,
              fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: t.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right,
          color: t.textSecondary, size: 18),
    );
  }
}

// ── Theme picker tile ──────────────────────────────────────────────────────────

class _ThemeTile extends ConsumerWidget {
  final RiverColors theme;
  const _ThemeTile({required this.theme});

  static const _modes = [
    (AppThemeMode.dark,         'Dark'),
    (AppThemeMode.light,        'Light'),
    (AppThemeMode.ocean,        'Ocean'),
    (AppThemeMode.sunset,       'Sunset'),
    (AppThemeMode.roboticDark,  'Robotic Dark'),
    (AppThemeMode.roboticLight, 'Robotic Light'),
    (AppThemeMode.system,       'System'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t       = theme;
    final current = ref.watch(themeModeProvider);
    final label   = _modes.firstWhere((m) => m.$1 == current,
        orElse: () => (AppThemeMode.dark, 'Dark')).$2;

    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.palette_outlined,
            color: Colors.purple, size: 20),
      ),
      title: Text('Theme',
          style: TextStyle(color: t.textPrimary,
              fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(label,
          style: TextStyle(color: t.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right,
          color: t.textSecondary, size: 18),
      onTap: () => _showThemePicker(context, ref, t, current),
    );
  }

  void _showThemePicker(
      BuildContext ctx, WidgetRef ref, RiverColors t, AppThemeMode current) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: t.navBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
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
            Text('Choose Theme',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._modes.map((m) => RadioListTile<AppThemeMode>(
                  value: m.$1,
                  groupValue: current,
                  title: Text(m.$2,
                      style: TextStyle(color: t.textPrimary)),
                  activeColor: t.accent,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeModeProvider.notifier).setMode(v);
                      Navigator.pop(ctx);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }
}
