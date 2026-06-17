// lib/screens/rainfall_forecast_screen.dart  v2.0
// Merged with live risk forecast — real station data from biharBulkPredictionsProvider.
// UI widgets (_RainBarChart, _DayCard, _Stat) preserved unchanged.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/river_theme.dart';
import '../providers/bihar_prediction_provider.dart';
import '../models/flood_prediction.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class DayForecast {
  final DateTime date;
  final double   rainMm;
  final double   tempMax;
  final double   tempMin;
  final int      humidity;
  final double   windKmh;
  final double   floodRisk;
  final String   condition;
  const DayForecast({
    required this.date,
    required this.rainMm,
    required this.tempMax,
    required this.tempMin,
    required this.humidity,
    required this.windKmh,
    required this.floodRisk,
    required this.condition,
  });
}

// ---------------------------------------------------------------------------
// Helpers — map FloodPrediction → 3-day DayForecast list
// ---------------------------------------------------------------------------

List<DayForecast> _predToForecasts(FloodPrediction p) {
  final now = DateTime.now();
  final levels = [p.predicted24h, p.predicted48h, p.predicted72h];
  final risks  = levels.map((l) =>
      p.dangerLevel > 0 ? (l / p.dangerLevel).clamp(0.0, 1.0) : 0.3).toList();

  String _cond(double risk) {
    if (risk > 0.8) return 'heavy_rain';
    if (risk > 0.6) return 'moderate_rain';
    if (risk > 0.35) return 'light_rain';
    if (risk > 0.2) return 'cloudy';
    return 'clear';
  }

  // Estimate rainfall mm from level rise relative to warning threshold
  double _rainMm(double level, double prev) {
    final rise = (level - prev).clamp(0.0, 5.0);
    return (rise * 18 + risks[0] * 25).clamp(0.0, 100.0);
  }

  return [
    DayForecast(
      date:      now.add(const Duration(days: 1)),
      rainMm:    _rainMm(levels[0], p.currentLevel),
      tempMax:   34, tempMin: 26, humidity: (75 + risks[0] * 20).toInt(),
      windKmh:   14 + risks[0] * 12,
      floodRisk: risks[0],
      condition: _cond(risks[0]),
    ),
    DayForecast(
      date:      now.add(const Duration(days: 2)),
      rainMm:    _rainMm(levels[1], levels[0]),
      tempMax:   33, tempMin: 25, humidity: (72 + risks[1] * 20).toInt(),
      windKmh:   12 + risks[1] * 12,
      floodRisk: risks[1],
      condition: _cond(risks[1]),
    ),
    DayForecast(
      date:      now.add(const Duration(days: 3)),
      rainMm:    _rainMm(levels[2], levels[1]),
      tempMax:   34, tempMin: 26, humidity: (70 + risks[2] * 20).toInt(),
      windKmh:   11 + risks[2] * 10,
      floodRisk: risks[2],
      condition: _cond(risks[2]),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Search notifier
// ---------------------------------------------------------------------------

class _SearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

final _searchProvider =
    NotifierProvider<_SearchNotifier, String>(_SearchNotifier.new);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RainfallForecastScreen extends ConsumerWidget {
  static const String route = '/rainfall-forecast';
  const RainfallForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query      = ref.watch(_searchProvider);
    final allPreds   = ref.watch(biharBulkPredictionsProvider);

    // Filter by search query; sort critical-first
    final preds = allPreds
        .where((p) => query.isEmpty ||
            p.station.toLowerCase().contains(query.toLowerCase()))
        .toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return Scaffold(
      backgroundColor: AppPalette.abyss2,
      appBar: AppBar(
        title: const Text('Risk Forecast — All Stations'),
        backgroundColor: AppPalette.oceanAccent,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => ref.read(_searchProvider.notifier).set(v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search station…',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                filled: true,
                fillColor: Colors.white12,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: preds.isEmpty
          ? const Center(
              child: Text('No stations found',
                  style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: preds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) {
                final pred      = preds[i];
                final forecasts = _predToForecasts(pred);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Station header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(pred.station,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          _SeverityChip(pred.severity),
                          const SizedBox(width: 6),
                          Text('${pred.riskScore.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    _RainBarChart(forecasts: forecasts),
                    const SizedBox(height: 6),
                    ...forecasts.map((f) => _DayCard(forecast: f)),
                  ],
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Severity chip
// ---------------------------------------------------------------------------

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip(this.severity);

  Color get _color => switch (severity) {
    'CRITICAL' => AppPalette.critical,
    'SEVERE'   => AppPalette.severe,
    'MODERATE' => AppPalette.warning,
    _          => AppPalette.safe,
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color, width: 1),
        ),
        child: Text(severity,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.bold, color: _color)),
      );
}

// ---------------------------------------------------------------------------
// Rain bar chart
// ---------------------------------------------------------------------------

class _RainBarChart extends StatelessWidget {
  final List<DayForecast> forecasts;
  const _RainBarChart({required this.forecasts});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: 100,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx >= 0 && idx < forecasts.length) {
                    return Text(
                      DateFormat('E').format(forecasts[idx].date),
                      style: const TextStyle(fontSize: 9),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}mm',
                  style: const TextStyle(fontSize: 8),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: forecasts.asMap().entries.map((e) {
            final risk  = e.value.floodRisk;
            final color = risk > 0.7
                ? AppPalette.critical
                : risk > 0.4
                    ? AppPalette.warning
                    : AppPalette.cyan;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.rainMm.clamp(0, 100),
                  color: color,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day card
// ---------------------------------------------------------------------------

class _DayCard extends StatelessWidget {
  final DayForecast forecast;
  const _DayCard({required this.forecast});

  IconData _icon(String cond) => switch (cond) {
    'heavy_rain'    => Icons.thunderstorm_outlined,
    'moderate_rain' => Icons.grain,
    'light_rain'    => Icons.water_drop_outlined,
    'cloudy'        => Icons.cloud_outlined,
    _               => Icons.wb_sunny_outlined,
  };

  Color _iconColor(String cond) => switch (cond) {
    'heavy_rain'    => AppPalette.critical,
    'moderate_rain' => AppPalette.oceanAccent,
    'light_rain'    => AppPalette.cyan,
    'cloudy'        => Colors.grey,
    _               => AppPalette.warning,
  };

  String _riskLabel(double r) =>
      r > 0.8 ? 'Critical' : r > 0.6 ? 'High' :
      r > 0.4 ? 'Moderate' : 'Low';

  Color _riskColor(double r) =>
      r > 0.8 ? AppPalette.critical :
      r > 0.6 ? AppPalette.warning  :
      r > 0.4 ? AppPalette.warning  :
      AppPalette.safe;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Text(DateFormat('EEE').format(forecast.date),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(DateFormat('d MMM').format(forecast.date),
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Icon(_icon(forecast.condition),
                      color: _iconColor(forecast.condition), size: 28),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(Icons.water_drop,  '${forecast.rainMm.toInt()}mm',
                      AppPalette.oceanAccent),
                  _Stat(Icons.thermostat,
                      '${forecast.tempMax.toInt()}°/${forecast.tempMin.toInt()}°',
                      AppPalette.danger),
                  _Stat(Icons.water, '${forecast.humidity}%',
                      AppPalette.cyan),
                  _Stat(Icons.air, '${forecast.windKmh.toInt()}km/h',
                      Colors.grey),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _riskColor(forecast.floodRisk).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _riskColor(forecast.floodRisk), width: 1),
              ),
              child: Text(
                _riskLabel(forecast.floodRisk),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _riskColor(forecast.floodRisk)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String   value;
  final Color    color;
  const _Stat(this.icon, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      );
}
