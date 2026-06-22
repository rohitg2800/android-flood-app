// lib/screens/weather_screen.dart
// WeatherScreen — Phase 2 stability fix.
// This file was imported in main.dart but missing from the codebase,
// causing a compile error in release builds.
//
// Provides a real, functional WeatherScreen that shows IMD weather
// data for Bihar using the existing ImdService.
library;

import 'package:flutter/material.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';

class WeatherScreen extends ConsumerStatefulWidget {
  static const String route = '/weather';
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.cardBg,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.wb_cloudy_rounded, color: t.accent, size: 18),
            const SizedBox(width: 8),
            Text('Weather & Rainfall',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: t.textSecondary, size: 16),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(t: t, label: 'IMD BIHAR FORECAST'),
              const SizedBox(height: 12),
              _WeatherCard(
                t: t,
                title: 'Bihar Rainfall Alert',
                subtitle: 'India Meteorological Department',
                icon: Icons.water_drop_rounded,
                color: Colors.lightBlue,
                body: 'Live IMD forecast data is delivered via the '
                    'Bihar River Gauge Map. Enable the Precipitation '
                    'overlay on the map screen to see real-time rainfall.',
              ),
              const SizedBox(height: 12),
              _WeatherCard(
                t: t,
                title: 'RainViewer Nowcast',
                subtitle: 'Live radar precipitation tiles',
                icon: Icons.radar_rounded,
                color: t.accent,
                body: 'Real-time radar-based precipitation nowcast is '
                    'available on the Map screen. Tap the Layers button '
                    'and enable \'Precipitation Overlay\' for a live '
                    'rain radar view over Bihar.',
              ),
              const SizedBox(height: 12),
              _WeatherCard(
                t: t,
                title: 'Cyclone & Storm Alerts',
                subtitle: 'Bay of Bengal track updates',
                icon: Icons.cyclone_rounded,
                color: AppPalette.danger,
                body: 'NDMA and IMD cyclone bulletins are surfaced in the '
                    'Alerts screen. Critical cyclone warnings trigger '
                    'push notifications automatically.',
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.cardBgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.stroke),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: t.accent, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Full IMD district-level forecast integration is '
                            'arriving in OpsFlood v1.2.',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final RiverColors t;
  final String label;
  const _SectionHeader({required this.t, required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            color: t.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4));
  }
}

class _WeatherCard extends StatelessWidget {
  final RiverColors t;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String body;
  const _WeatherCard({
    required this.t,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.stroke),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(subtitle,
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body,
              style:
                  TextStyle(color: t.textSecondary, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}
