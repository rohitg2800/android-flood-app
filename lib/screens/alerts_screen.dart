// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/alert_engine.dart';
import '../providers/data_fetch_provider.dart';
import '../theme/app_palette.dart';
import '../theme/river_colors.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _searchQuery = '';

  static Color _severityColor(AlertSeverity s, RiverColors t) {
    switch (s) {
      case AlertSeverity.critical:
        return t.danger;
      case AlertSeverity.emergency:
        return AppPalette.critical;
      case AlertSeverity.warning:
        return t.warning;
      case AlertSeverity.info:
        return t.safe;
    }
  }

  static IconData _severityIcon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return Icons.warning_amber_rounded;
      case AlertSeverity.emergency:
        return Icons.crisis_alert_rounded;
      case AlertSeverity.warning:
        return Icons.water_damage_rounded;
      case AlertSeverity.info:
        return Icons.info_outline_rounded;
    }
  }

  static String _severityLabel(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:  return 'CRITICAL';
      case AlertSeverity.emergency: return 'EMERGENCY';
      case AlertSeverity.warning:   return 'WARNING';
      case AlertSeverity.info:      return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final alerts = ref.watch(alertsProvider);

    final filtered = _searchQuery.isEmpty
        ? alerts
        : alerts.where((a) =>
            a.stationName.toLowerCase().contains(_searchQuery) ||
            a.title.toLowerCase().contains(_searchQuery) ||
            a.river.toLowerCase().contains(_searchQuery)).toList();

    final dangerCount = alerts.where(
        (a) =>
            a.severity == AlertSeverity.critical ||
            a.severity == AlertSeverity.emergency).length;
    final warnCount   = alerts.where(
        (a) => a.severity == AlertSeverity.warning).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flood Alerts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search station, river…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: t.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // summary chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _Chip(label: '$dangerCount DANGER', color: AppPalette.critical),
                const SizedBox(width: 8),
                _Chip(label: '$warnCount WARNING', color: AppPalette.warning),
                const SizedBox(width: 8),
                _Chip(label: '${alerts.length} TOTAL', color: t.textSecondary),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No alerts',
                        style: TextStyle(color: t.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final a = filtered[i];
                      final color = _severityColor(a.severity, t);
                      return Card(
                        color: t.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: color.withValues(alpha: 0.5), width: 1),
                        ),
                        child: ListTile(
                          leading: Icon(_severityIcon(a.severity), color: color),
                          title: Text(a.title,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${a.river} · ${a.district} · '
                            '${a.currentLevel.toStringAsFixed(2)} m',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_severityLabel(a.severity),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
}
