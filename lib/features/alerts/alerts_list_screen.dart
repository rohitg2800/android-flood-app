// Module 3: Alerts List Screen
import 'package:flutter/material.dart';
import 'alert_model.dart';

class AlertsListScreen extends StatelessWidget {
  const AlertsListScreen({super.key});

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low: return Colors.green;
      case AlertSeverity.medium: return Colors.orange;
      case AlertSeverity.high: return Colors.deepOrange;
      case AlertSeverity.critical: return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with BLoC state/stream from Neon API
    final List<FloodAlert> alerts = [];

    return Scaffold(
      appBar: AppBar(title: const Text('Flood Alerts')),
      body: alerts.isEmpty
          ? const Center(child: Text('No active alerts'))
          : ListView.builder(
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _severityColor(alert.severity),
                      child: const Icon(Icons.warning, color: Colors.white),
                    ),
                    title: Text(alert.title),
                    subtitle: Text(alert.areaName ?? 'Unknown area'),
                    trailing: Chip(
                      label: Text(alert.severity.name.toUpperCase()),
                      backgroundColor: _severityColor(alert.severity).withOpacity(0.2),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
