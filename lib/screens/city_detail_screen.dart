// lib/screens/city_detail_screen.dart
library;

import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

/// Minimal CityDetailScreen stub.
/// Replace the body with full implementation when ready.
class CityDetailScreen extends StatelessWidget {
  final String cityName;

  const CityDetailScreen({super.key, required this.cityName});

  static const String route = '/city-detail';

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: Text(cityName),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'City detail for $cityName\n(coming soon)',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
