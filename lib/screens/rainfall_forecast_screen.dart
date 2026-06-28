// lib/screens/rainfall_forecast_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';
import '../providers/weather_provider.dart';

class RainfallForecastScreen extends ConsumerWidget {
  const RainfallForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t    = RiverColors.of(context);
    final data = ref.watch(rainfallForecastProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Rainfall Forecast',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: t.accent),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(rainfallForecastProvider),
          ),
        ],
        elevation: 0,
      ),
      body: data.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: t.textSecondary, size: 48),
              const SizedBox(height: 12),
              Text('Could not load forecast',
                  style: TextStyle(color: t.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(rainfallForecastProvider),
                child: Text('Retry', style: TextStyle(color: t.accent)),
              ),
            ],
          ),
        ),
        data: (forecast) => ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            for (final day in forecast)
              _ForecastCard(t: t, day: day),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.t, required this.day});
  final RiverColors t;
  final dynamic day;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        day?.toString() ?? '—',
        style: TextStyle(color: t.textPrimary, fontSize: 13),
      ),
    );
  }
}
