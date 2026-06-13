// lib/screens/admin_dashboard_screen.dart
// OpsFlood — Module 11: Admin Dashboard
//
// Gated behind role check: only shown when
// FirebaseAuth.currentUser?.email ends with @opsflood.gov.in
// (replace with your real admin check)
//
// Sections:
//  1. Overview cards  — total stations, active alerts, reports today, uptime
//  2. Live alerts table
//  3. Station health grid
//  4. Crowd-report queue (pending moderation)

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alert_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/crowd_report_provider.dart';

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
    final warningCount = alerts.where((a) =>
      a.severity == AlertSeverity.warning).length;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.cardBg,
        elevation: 0,
        title: Text('Admin Dashboard',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text('ADMIN',
                  style: TextStyle(color: AppPalette.abyss0, fontSize: 11,
                      fontWeight: FontWeight.w700)),
              backgroundColor: AppPalette.danger,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Overview KPI row ──
          Text('System Overview',
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _KpiCard(label: 'Stations', value: '${live.length}',
                  icon: Icons.sensors, color: AppPalette.cyan, t: t),
              _KpiCard(label: 'Active Alerts', value: '${alerts.length}',
                  icon: Icons.notifications_active, color: AppPalette.warning, t: t),
              _KpiCard(label: 'Critical', value: '$criticalCount',
                  icon: Icons.crisis_alert, color: AppPalette.critical, t: t),
              _KpiCard(label: 'Pending Reports', value: '${crowd.length}',
                  icon: Icons.pending_actions, color: AppPalette.danger, t: t),
            ],
          ),
          const SizedBox(height: 24),

          // ── Live alerts table ──
          Text('Live Alerts',
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            Center(child: Text('No active alerts.',
                style: TextStyle(color: t.textSecondary)))
          else
            ...alerts.map((a) => _AlertRow(alert: a, t: t)).toList(),
          const SizedBox(height: 24),

          // ── Station health ──
          Text('Station Health',
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 12),
          if (live.isEmpty)
            Center(child: Text('Loading…', style: TextStyle(color: t.textSecondary)))
          else
            ...live.entries.take(10).map((e) {
              final fl = e.value;
              final pct  = fl.fillPercent.clamp(0.0, 1.0);
              final barColor = pct > 0.85 ? AppPalette.critical
                  : pct > 0.65 ? AppPalette.danger
                  : pct > 0.45 ? AppPalette.warning
                  : AppPalette.safe;
              return _StationHealthRow(
                name: fl.stationName,
                pct:  pct,
                color: barColor,
                t:    t,
              );
            }).toList(),
          const SizedBox(height: 24),

          // ── Pending crowd-report queue ──
          Text('Pending Crowd Reports',
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 12),
          if (crowd.isEmpty)
            Center(child: Text('Queue empty.',
                style: TextStyle(color: t.textSecondary)))
          else
            ...crowd.map((r) => _CrowdReportRow(report: r, t: t)).toList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color  color;
  final RiverColors t;
  const _KpiCard({required this.label, required this.value,
      required this.icon, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(color: t.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 18)),
              Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Alert Row ─────────────────────────────────────────────────────────────────
class _AlertRow extends StatelessWidget {
  final dynamic alert;
  final RiverColors t;
  const _AlertRow({required this.alert, required this.t});

  Color _sevColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.emergency:
      case AlertSeverity.critical:  return AppPalette.critical;
      case AlertSeverity.warning:   return AppPalette.warning;
      case AlertSeverity.info:      return AppPalette.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _sevColor(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        t.cardBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: c, size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.stationName,
                    style: TextStyle(color: t.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(alert.message,
                    style: TextStyle(color: t.textSecondary, fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(alert.severity.name.toUpperCase(),
                style: TextStyle(color: c, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Station Health Row ────────────────────────────────────────────────────────
class _StationHealthRow extends StatelessWidget {
  final String name;
  final double pct;
  final Color  color;
  final RiverColors t;
  const _StationHealthRow({
    required this.name, required this.pct,
    required this.color, required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.stroke.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: t.textPrimary, fontSize: 13)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           pct,
                    backgroundColor: t.stroke.withValues(alpha: 0.3),
                    color:           color,
                    minHeight:       6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Crowd Report Row ──────────────────────────────────────────────────────────
class _CrowdReportRow extends StatelessWidget {
  final dynamic report;
  final RiverColors t;
  const _CrowdReportRow({required this.report, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        t.cardBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: t.stroke.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: t.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.location ?? 'Unknown location',
                    style: TextStyle(color: t.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(report.description ?? '',
                    style: TextStyle(color: t.textSecondary, fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.check_circle_outline, color: AppPalette.safe, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.cancel_outlined, color: AppPalette.critical, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
