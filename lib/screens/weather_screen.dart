// lib/screens/weather_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';
import '../providers/weather_provider.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t       = RiverColors.of(context);
    final weather = ref.watch(weatherProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Weather',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.accent),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(weatherProvider),
          ),
        ],
        elevation: 0,
      ),
      body: weather.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: t.accent),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: t.textSecondary, size: 48),
              const SizedBox(height: 12),
              Text('Could not load weather',
                  style: TextStyle(color: t.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(weatherProvider),
                child: Text('Retry', style: TextStyle(color: t.accent)),
              ),
            ],
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _WeatherCard(t: t, data: data),
          ],
        ),
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.t, required this.data});
  final RiverColors t;
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data?.toString() ?? 'Weather data unavailable',
            style: TextStyle(color: t.textPrimary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
