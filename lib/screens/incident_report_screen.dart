// lib/screens/incident_report_screen.dart
// OpsFlood — Incident Report Screen (stub)
// TODO: implement community incident reporting form
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class IncidentReportScreen extends StatelessWidget {
  static const String route = '/incident-report';
  const IncidentReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
      ),
      backgroundColor: t.scaffoldBg,
      body: Center(
        child: Text(
          'Incident reporting coming soon',
          style: TextStyle(color: t.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}
