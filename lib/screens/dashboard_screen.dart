// lib/screens/dashboard_screen.dart
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/flood_provider.dart';
import '../providers/alert_provider.dart';
import 'city_detail_screen.dart';
import 'alerts_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'bihar_river_map_screen.dart';
import 'sos_screen.dart';
import 'weather_screen.dart';
import 'news_feed_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  static const String route = '/dashboard';

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
        const Duration(minutes: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final fp = ref.read(floodProvider);
    await fp.refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t  = RiverColors.of(context);
    final fp = ref.watch(floodProvider);
    final ap = ref.watch(alertProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: RefreshIndicator(
        color: t.accent,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            Td3AppBar(
              title: 'OpsFlood Bihar',
              subtitle: 'Live Flood Intelligence',
              actions: [
                IconButton(
                  icon: Icon(Icons.sos_rounded,
                      color: t.riverDanger, size: 26),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SosScreen())),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSummaryRow(context, t, fp, ap),
                  const SizedBox(height: 16),
                  _buildAtRiskCities(context, t, fp),
                  const SizedBox(height: 16),
                  _buildLiveStations(context, t, fp),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
      BuildContext context, RiverColors t, FloodProvider fp, AlertProvider ap) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'DANGER',
            value: '${ap.dangerCount}',
            valueColor: t.riverDanger,
            icon: Icons.warning_rounded,
            iconColor: t.riverDanger,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AlertsScreen())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'WARNING',
            value: '${ap.warningCount}',
            valueColor: t.riverWarning,
            icon: Icons.notifications_active_rounded,
            iconColor: t.riverWarning,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AlertsScreen())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'NORMAL',
            value: '${ap.normalCount}',
            valueColor: t.riverNormal,
            icon: Icons.check_circle_outline_rounded,
            iconColor: t.riverNormal,
          ),
        ),
      ],
    );
  }

  Widget _buildAtRiskCities(
      BuildContext context, RiverColors t, FloodProvider fp) {
    final cities = fp.topAtRiskCities.take(5).toList();
    if (cities.isEmpty) return const SizedBox.shrink();
    return Td3Card(
      elevation: Td3.elevMid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('At-Risk Cities',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          ...cities.map((city) {
            final color = city.riskLevel == 'CRITICAL' || city.riskLevel == 'DANGER'
                ? t.riverDanger
                : city.riskLevel == 'HIGH'
                    ? t.riverWarning
                    : t.riverNormal;
            // FloodData.city is the display name (was: cityName / stationId)
            return ListTile(
              dense: true,
              title: Text(city.city,
                  style: TextStyle(
                      color: t.textPrimary, fontSize: 13)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: color, size: 18),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CityDetailScreen(
                          cityName: city.city))),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLiveStations(
      BuildContext context, RiverColors t, FloodProvider fp) {
    final stations = fp.liveStations.take(10).toList();
    if (stations.isEmpty) return const SizedBox.shrink();
    return Td3Card(
      elevation: Td3.elevMid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Live Stations',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          // FloodData.city is the station display name (was: s.stationId)
          ...stations.map((s) => ListTile(
                dense: true,
                title: Text(s.city,
                    style: TextStyle(color: t.textPrimary, fontSize: 13)),
                trailing: Icon(Icons.circle,
                    color: t.accent, size: 8),
              )),
        ],
      ),
    );
  }
}

// ── Stat chip widget ─────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String  label;
  final String  value;
  final Color   valueColor;
  final IconData icon;
  final Color   iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Td3Card(
        elevation: Td3.elevLow,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: valueColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
