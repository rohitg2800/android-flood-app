// lib/screens/predict_screen_impl.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../models/flood_alert.dart';

class PredictScreen extends ConsumerWidget {
  const PredictScreen({super.key});

  static const String route = '/predict';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: Text('Predict', style: TextStyle(color: t.textPrimary)),
        backgroundColor: t.navBg,
      ),
      body: Center(
        child: Text('Prediction coming soon',
            style: TextStyle(color: t.textSecondary)),
      ),
    );
  }

  /// Helper used by widgets to derive color from alert level.
  static Color levelColor(BuildContext context, AlertLevel? level) {
    final t = RiverColors.of(context);
    if (level == AlertLevel.danger || level == AlertLevel.extreme) {
      return t.riverDanger;
    }
    if (level == AlertLevel.warning) return t.riverWarning;
    return t.riverNormal;
  }
}
