// lib/screens/admin_dashboard_screen.dart
// OpsFlood — Module 11: Admin Dashboard
//
// Gated behind role check: only shown when
// FirebaseAuth.currentUser?.email ends with @opsflood.gov.in

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alert_provider.dart';
import '../services/alert_engine.dart';

// ── Stub providers — replace with real implementations when available ────────
final activeAlertsProvider = Provider<List<FloodAlert>>((ref) => const []);
final liveLevelsProvider   = Provider<List<dynamic>>((ref) => const []);
final pendingReportsProvider = Provider<List<dynamic>>((ref) => const []);

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    final alerts = ref.watch(activeAlertsProvider);
    final live   = ref.watch(liveLevelsProvider);
    final crowd  = ref.watch(pendingReportsProvider);

    final criticalCount = alerts.where((a) =>
      a.severity == AlertSeverity.critical ||
      a.severity == AlertSeverity.emergency).length;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.cardBg,
        elevation: 0,
        title: Text('Admin Dashboard',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OverviewCards(
            t: t,
            alertCount: alerts.length,
            criticalCount: criticalCount,
            liveCount: live.length,
            pendingCount: crowd.length,
          ),
          const SizedBox(height: 20),
          if (alerts.isNotEmpty) ..._AlertRows(alerts: alerts, t: t),
        ],
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final RiverColors t;
  final int alertCount, criticalCount, liveCount, pendingCount;
  const _OverviewCards({
    required this.t,
    required this.alertCount,
    required this.criticalCount,
    required this.liveCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _KpiCard(label: 'Active Alerts',  value: '$alertCount',   color: AppPalette.warning,  t: t),
        _KpiCard(label: 'Critical',       value: '$criticalCount', color: AppPalette.critical, t: t),
        _KpiCard(label: 'Live Stations',  value: '$liveCount',    color: AppPalette.cyan,     t: t),
        _KpiCard(label: 'Pending Reports',value: '$pendingCount', color: AppPalette.gold,     t: t),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final Color  color;
  final RiverColors t;
  const _KpiCard({
    required this.label, required this.value,
    required this.color, required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: color,
              fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

List<Widget> _AlertRows({
  required List<FloodAlert> alerts,
  required RiverColors t,
}) =>
    alerts.map((a) => _AlertRow(alert: a, t: t)).toList();

class _AlertRow extends StatelessWidget {
  final FloodAlert alert;
  final RiverColors t;
  const _AlertRow({required this.alert, required this.t});

  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency: return AppPalette.critical;
      case AlertSeverity.critical:  return AppPalette.danger;
      case AlertSeverity.warning:   return AppPalette.warning;
      case AlertSeverity.info:      return AppPalette.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(alert.title,
                style: TextStyle(color: t.textPrimary, fontSize: 13)),
          ),
          Text(alert.severity.name.toUpperCase(),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
