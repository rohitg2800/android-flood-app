// lib/screens/settings_screen.dart  nav-v1
// Wired: notification settings, profile, export, admin, about/model-info.
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../app_router.dart';

class SettingsScreen extends StatelessWidget {
  static const String route = Routes.settings;
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(title: 'Settings', subtitle: 'App preferences'),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _section(t, 'Account', [
                  _tile(context, t, Icons.person_outline,        'Profile',               Routes.profile),
                  _tile(context, t, Icons.notifications_outlined,'Notification Settings',  Routes.notificationSettings),
                ]),
                const SizedBox(height: 16),
                _section(t, 'Data & Analytics', [
                  _tile(context, t, Icons.bar_chart_rounded,     'Analytics Dashboard',    Routes.analytics),
                  _tile(context, t, Icons.history_rounded,       'Historical Analytics',   Routes.historicalAnalytics),
                  _tile(context, t, Icons.download_rounded,      'Export Data',            Routes.export_),
                ]),
                const SizedBox(height: 16),
                _section(t, 'Tools', [
                  _tile(context, t, Icons.sensors,               'Live Stations',          Routes.liveStations),
                  _tile(context, t, Icons.grid_view_rounded,     'State Matrix',           Routes.stateMatrix),
                  _tile(context, t, Icons.monitor_heart_outlined,'River Monitor',          Routes.riverMonitor),
                  _tile(context, t, Icons.info_outline,          'Model Info',             Routes.modelInfo),
                ]),
                const SizedBox(height: 16),
                _section(t, 'Administration', [
                  _tile(context, t, Icons.admin_panel_settings_outlined, 'Admin Dashboard', Routes.adminDashboard),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(RiverColors t, String title, List<Widget> children) =>
      Td3Card(
        elevation: Td3.elevMid,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(title,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      );

  Widget _tile(BuildContext ctx, RiverColors t, IconData icon, String label,
      String route) =>
      ListTile(
        dense: true,
        leading: Icon(icon, color: t.accent, size: 20),
        title: Text(label,
            style: TextStyle(color: t.textPrimary, fontSize: 14)),
        trailing:
            Icon(Icons.chevron_right_rounded, color: t.textSecondary, size: 18),
        onTap: () => Navigator.of(ctx).pushNamed(route),
      );
}
