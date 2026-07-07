import 'package:flutter/material.dart';
import 'alert_model.dart';

class AlertListScreen extends StatelessWidget {
  const AlertListScreen({super.key});

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return Colors.red.shade900;
      case 'high':     return Colors.red;
      case 'medium':   return Colors.orange;
      default:         return Colors.yellow.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flood Alerts')),
      body: const Center(child: Text('Alert List — connect to Neon API')),
    );
  }
}
