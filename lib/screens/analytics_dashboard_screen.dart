// lib/screens/analytics_dashboard_screen.dart  v2.0
// Live analytics dashboard — KPI cards, river table, severity breakdown
library;

import 'package:flutter/material.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/data_fetch_provider.dart';
import '../providers/merged_stations_provider.dart';
import '../services/alert_engine.dart';
import '../app_router.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  static const route = '/analytics';
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    final alerts = ref.watch(alertsProvider);
    final stations = ref.watch(mergedStationsProvider);
    final isLoading = ref.watch(wrdIsLoadingProvider);
    final error = ref.watch(wrdErrorProvider);

    final total = alerts.length;
    final critical = alerts
        .where((a) =>
            a.severity == AlertSeverity.critical ||
            a.severity == AlertSeverity.emergency)
        .length;
    final warning =
        alerts.where((a) => a.severity == AlertSeverity.warning).length;
    final info = alerts.where((a) => a.severity == AlertSeverity.info).length;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          Td3AppBar(
            title: 'Analytics Dashboard',
            subtitle: 'Live flood intelligence overview',
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: t.textSecondary, size: 20),
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(mergedStationsProvider);
                  ref.invalidate(alertsProvider);
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── KPI Row 1 ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                        child: _KpiCard(
                            t: t,
                            label: 'Total Alerts',
                            value: total.toString(),
                            icon: Icons.notifications_rounded,
                            color: const Color(0xFF1976D2))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _KpiCard(
                            t: t,
                            label: 'Critical',
                            value: critical.toString(),
                            icon: Icons.warning_rounded,
                            color: const Color(0xFFE53935))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _KpiCard(
                            t: t,
                            label: 'Warning',
                            value: warning.toString(),
                            icon: Icons.report_problem_rounded,
                            color: const Color(0xFFFF8F00))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _KpiCard(
                            t: t,
                            label: 'Info / Safe',
                            value: info.toString(),
                            icon: Icons.info_rounded,
                            color: const Color(0xFF43A047))),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Alert severity bar ─────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFF0288D1),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alert Severity Distribution',
                            style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        if (total > 0) ...[
                          _SeverityBar(
                              label: 'Emergency/Critical',
                              count: critical,
                              total: total,
                              color: const Color(0xFFE53935)),
                          const SizedBox(height: 8),
                          _SeverityBar(
                              label: 'Warning',
                              count: warning,
                              total: total,
                              color: const Color(0xFFFF8F00)),
                          const SizedBox(height: 8),
                          _SeverityBar(
                              label: 'Info',
                              count: info,
                              total: total,
                              color: const Color(0xFF43A047)),
                        ] else
                          Text('No alerts at this time.',
                              style: TextStyle(
                                  color: t.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── River data table ───────────────────────────────────────
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? _ErrorCard(t: t, msg: error!)
                        : Td3Card(
                            elevation: Td3.elevMid,
                            accentColor: const Color(0xFF26A69A),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Live River Status  (${stations.length} stations)',
                                      style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 14),
                                  ...stations.take(20).map((r) => _RiverRow(
                                        t: t,
                                        name: r.river,
                                        level: r.current,
                                        danger: r.danger,
                                        onTap: () => Navigator.of(context)
                                            .pushNamed(Routes.riverDetail,
                                                arguments: r),
                                      )),
                                  if (stations.length > 20)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: TextButton(
                                        onPressed: () => Navigator.of(context)
                                            .pushNamed(Routes.liveStations),
                                        child: Text(
                                            'View all ${stations.length} stations →',
                                            style: const TextStyle(
                                                color: Color(0xFF26A69A),
                                                fontSize: 12)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final RiverColors t;
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.t,
      required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) => Td3Card(
        elevation: Td3.elevMid,
        accentColor: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Center(child: Icon(icon, color: color, size: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            color: color,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    Text(label,
                        style: TextStyle(color: t.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SeverityBar extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _SeverityBar(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('$count',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _RiverRow extends StatelessWidget {
  final RiverColors t;
  final String name;
  final double level, danger;
  final VoidCallback onTap;
  const _RiverRow(
      {required this.t,
      required this.name,
      required this.level,
      required this.danger,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final pct = danger > 0 ? (level / danger).clamp(0.0, 1.2) : 0.0;
    final color = pct > 1.0
        ? const Color(0xFFE53935)
        : pct > 0.85
            ? const Color(0xFFFF8F00)
            : const Color(0xFF43A047);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(name,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500))),
            Text('${level.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final RiverColors t;
  final String msg;
  const _ErrorCard({required this.t, required this.msg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x1AE53935),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x40E53935)),
        ),
        child: Text('Error loading data: $msg',
            style: const TextStyle(color: Color(0xFFE53935), fontSize: 12)),
      );
}
