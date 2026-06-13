// lib/screens/comparison_screen.dart
// OpsFlood — River Station Comparison Screen (stub)
// TODO: implement full station-vs-station comparison UI
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class ComparisonScreen extends StatelessWidget {
  static const String route = '/comparison';
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Comparison'),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
      ),
      backgroundColor: t.scaffoldBg,
      body: Center(
        child: Text(
          'Comparison coming soon',
          style: TextStyle(color: t.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}
