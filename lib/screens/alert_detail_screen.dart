// lib/screens/alert_detail_screen.dart
// Minimal Alert detail screen for router completeness.

library;

import 'package:flutter/material.dart';

import '../models/flood_alert.dart';

class AlertDetailScreen extends StatelessWidget {
  static const String route = '/alert-detail';

  final FloodAlert? alert;
  final String? stationName;

  const AlertDetailScreen({super.key, this.alert, this.stationName});

  @override
  Widget build(BuildContext context) {
    final title = alert?.station ?? alert?.cityName ?? stationName ?? 'Alert';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alert Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (alert != null) ...[
                Text('Level: ${alert!.level.label}'),
                const SizedBox(height: 8),
                Text(
                    'Current level: ${alert!.currentValue.toStringAsFixed(2)} m'),
                const SizedBox(height: 8),
                Text(
                    'Warning threshold: ${alert!.warningLevel.toStringAsFixed(2)} m'),
                const SizedBox(height: 8),
                Text(
                    'Danger threshold: ${alert!.dangerLevel.toStringAsFixed(2)} m'),
              ] else ...[
                Text('Station: $title'),
                const SizedBox(height: 8),
                const Text('No alert payload provided.'),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
