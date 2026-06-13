// lib/screens/evacuation_routes_screen.dart
// OpsFlood — Evacuation Routes Screen (stub)
// TODO: implement map-based evacuation route display
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class EvacuationRoutesScreen extends StatelessWidget {
  static const String route = '/evacuation-routes';
  const EvacuationRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evacuation Routes'),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
      ),
      backgroundColor: t.scaffoldBg,
      body: Center(
        child: Text(
          'Evacuation routes coming soon',
          style: TextStyle(color: t.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}
