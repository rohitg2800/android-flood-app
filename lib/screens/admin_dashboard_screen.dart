// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/alert_engine.dart';
import '../providers/data_fetch_provider.dart';
import '../theme/app_palette.dart';
import '../theme/river_colors.dart';

final activeAlertsProvider = Provider<List<FloodAlert>>((ref) => const []);

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final alerts = ref.watch(alertsProvider);

    final dangerCount = alerts.where((a) =>
        a.severity == AlertSeverity.critical ||
        a.severity == AlertSeverity.emergency).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
              label: 'Active Danger Alerts',
              value: dangerCount.toString(),
              color: AppPalette.critical),
          _SummaryCard(
              label: 'Total Alerts',
              value: alerts.length.toString(),
              color: AppPalette.warning),
          const SizedBox(height: 16),
          ..._buildAlertRows(alerts: alerts, t: t),
        ],
      ),
    );
  }

  static List<Widget> _buildAlertRows({
    required List<FloodAlert> alerts,
    required RiverColors t,
  }) =>
      alerts.map((a) => _AlertRow(alert: a, t: t)).toList();
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _SummaryCard(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title:    Text(label),
          trailing: Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ),
      );
}

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
    return Card(
      child: ListTile(
        leading:  Icon(Icons.water, color: color),
        title:    Text(alert.title),
        subtitle: Text('${alert.river} · ${alert.district}'),
        trailing: Text(alert.severity.label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
