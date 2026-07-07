import 'package:flutter/material.dart';
import 'alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  final AlertModel alert;
  const AlertDetailScreen({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(alert.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Severity: ${alert.severity.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Area: ${alert.areaName}'),
            const SizedBox(height: 8),
            Text(alert.description),
          ],
        ),
      ),
    );
  }
}
