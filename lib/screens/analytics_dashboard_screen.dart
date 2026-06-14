// lib/screens/analytics_dashboard_screen.dart
// OpsFlood — Analytics Dashboard
// WIRING: added static route constant
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import 'historical_analytics_screen.dart';
import 'rainfall_forecast_screen.dart';
import 'state_matrix_screen.dart';
import 'export_screen.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  static const String route = '/analytics-dashboard';
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.analytics_outlined, color: t.accent, size: 20),
            const SizedBox(width: 8),
            const Text('Analytics Hub'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Td3SectionHeader('Data & Analytics', accentColor: t.accent),
          const SizedBox(height: 12),
          _AnalyticsCard(
            theme: t,
            icon: Icons.history_edu_outlined,
            color: AppPalette.cyan,
            title: 'Historical Analytics',
            subtitle: 'Timeline, charts & stats of past flood events',
            onTap: () => Navigator.pushNamed(context, HistoricalAnalyticsScreen.route),
          ),
          const SizedBox(height: 10),
          _AnalyticsCard(
            theme: t,
            icon: Icons.cloudy_snowing,
            color: const Color(0xFF00B0FF),
            title: 'Rainfall Forecast',
            subtitle: '7-day IMD rainfall & flood risk by district',
            onTap: () => Navigator.pushNamed(context, RainfallForecastScreen.route),
          ),
          const SizedBox(height: 10),
          _AnalyticsCard(
            theme: t,
            icon: Icons.grid_view_rounded,
            color: const Color(0xFF7B2FF7),
            title: 'State Matrix',
            subtitle: 'District-wise flood status matrix for Bihar',
            onTap: () => Navigator.pushNamed(context, StateMatrixScreen.route),
          ),
          const SizedBox(height: 10),
          _AnalyticsCard(
            theme: t,
            icon: Icons.download_outlined,
            color: Colors.green,
            title: 'Export Data',
            subtitle: 'Export station data as CSV / PDF report',
            onTap: () => Navigator.pushNamed(context, ExportScreen.route),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final RiverColors theme;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AnalyticsCard({
    required this.theme, required this.icon, required this.color,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Td3Card(
      showGloss: false,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: TextStyle(color: t.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: TextStyle(color: t.textSecondary, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: t.textSecondary, size: 18),
      ),
    );
  }
}
