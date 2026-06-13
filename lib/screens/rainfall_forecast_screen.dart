// lib/screens/rainfall_forecast_screen.dart
// OpsFlood — Module 14: Rainfall Forecast Screen
//
// 7-day IMD-style rainfall forecast per district with:
//  • Hourly rain probability bars (fl_chart)
//  • Daily summary cards (rain mm, wind, humidity)
//  • Flood risk correlation badge
//  • Weather icon mapping
//  • Pull-to-refresh

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class DayForecast {
  final DateTime date;
  final double rainMm;
  final double tempMax;
  final double tempMin;
  final int humidity;
  final double windKmh;
  final double floodRisk; // 0.0 – 1.0
  final String condition; // 'heavy_rain' | 'moderate_rain' | 'light_rain' | 'cloudy' | 'clear'
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
// Sample provider (replace with IMD/OpenWeather call)
// ---------------------------------------------------------------------------

final _forecastProvider =
    FutureProvider.family<List<DayForecast>, String>(
        (_, district) async {
  await Future.delayed(const Duration(milliseconds: 400));
  final now = DateTime.now();
  return [
    DayForecast(date: now,
        rainMm: 42, tempMax: 33, tempMin: 26,
        humidity: 88, windKmh: 18, floodRisk: 0.72,
        condition: 'heavy_rain'),
    DayForecast(date: now.add(const Duration(days: 1)),
        rainMm: 65, tempMax: 31, tempMin: 25,
        humidity: 92, windKmh: 22, floodRisk: 0.85,
        condition: 'heavy_rain'),
    DayForecast(date: now.add(const Duration(days: 2)),
        rainMm: 28, tempMax: 32, tempMin: 25,
        humidity: 83, windKmh: 15, floodRisk: 0.60,
        condition: 'moderate_rain'),
    DayForecast(date: now.add(const Duration(days: 3)),
        rainMm: 12, tempMax: 34, tempMin: 26,
        humidity: 74, windKmh: 12, floodRisk: 0.40,
        condition: 'light_rain'),
    DayForecast(date: now.add(const Duration(days: 4)),
        rainMm: 5,  tempMax: 35, tempMin: 27,
        humidity: 68, windKmh: 10, floodRisk: 0.25,
        condition: 'cloudy'),
    DayForecast(date: now.add(const Duration(days: 5)),
        rainMm: 0,  tempMax: 36, tempMin: 27,
        humidity: 62, windKmh: 8,  floodRisk: 0.15,
        condition: 'clear'),
    DayForecast(date: now.add(const Duration(days: 6)),
        rainMm: 8,  tempMax: 35, tempMin: 26,
        humidity: 70, windKmh: 11, floodRisk: 0.30,
        condition: 'light_rain'),
  ];
});

final _selectedDistrictProvider =
    StateProvider<String>((_) => 'Patna');

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RainfallForecastScreen extends ConsumerWidget {
  static const String route = '/rainfall-forecast';
  const RainfallForecastScreen({super.key});

  static const _districts = [
    'Patna', 'Darbhanga', 'Muzaffarpur', 'Bhagalpur',
    'Supaul', 'Sitamarhi', 'Madhubani', 'Saran',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final district = ref.watch(_selectedDistrictProvider);
    final forecastAsync = ref.watch(_forecastProvider(district));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Rainfall Forecast'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // District selector
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              itemCount: _districts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _districts[i];
                final selected = d == district;
                return GestureDetector(
                  onTap: () => ref
                      .read(_selectedDistrictProvider.notifier)
                      .state = d,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0D47A1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF0D47A1),
                          width: selected ? 0 : 1),
                    ),
                    child: Text(d,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF0D47A1),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: forecastAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Failed to load: $e')),
              data: (forecasts) =>
                  RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(_forecastProvider(district).future),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _RainBarChart(forecasts: forecasts),
                        const SizedBox(height: 12),
                        ...forecasts
                            .map((f) => _DayCard(forecast: f)),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rain probability bar chart
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
              blurRadius: 6, offset: const Offset(0, 2))
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
            final risk = e.value.floodRisk;
            final color = risk > 0.7
                ? const Color(0xFFEF4444)
                : risk > 0.4
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF42A5F5);
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
    'heavy_rain'    => const Color(0xFFEF4444),
    'moderate_rain' => const Color(0xFF1565C0),
    'light_rain'    => const Color(0xFF42A5F5),
    'cloudy'        => Colors.grey,
    _               => const Color(0xFFFFA726),
  };

  String _riskLabel(double r) =>
    r > 0.8 ? 'Critical' : r > 0.6 ? 'High' :
    r > 0.4 ? 'Moderate' : 'Low';

  Color _riskColor(double r) =>
    r > 0.8 ? const Color(0xFFEF4444) :
    r > 0.6 ? const Color(0xFFFF9800) :
    r > 0.4 ? const Color(0xFFFFEB3B) :
    const Color(0xFF4CAF50);

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
            // Date & icon
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Text(DateFormat('EEE').format(forecast.date),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  Text(DateFormat('d MMM').format(forecast.date),
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Icon(_icon(forecast.condition),
                      color: _iconColor(forecast.condition),
                      size: 28),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stats
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(Icons.water_drop, '${forecast.rainMm.toInt()}mm',
                      const Color(0xFF1565C0)),
                  _Stat(Icons.thermostat,
                      '${forecast.tempMax.toInt()}°/${forecast.tempMin.toInt()}°',
                      const Color(0xFFFF6B35)),
                  _Stat(Icons.water, '${forecast.humidity}%',
                      const Color(0xFF42A5F5)),
                  _Stat(Icons.air, '${forecast.windKmh.toInt()}km/h',
                      Colors.grey),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Risk badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _riskColor(forecast.floodRisk)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _riskColor(forecast.floodRisk),
                    width: 1),
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
  final String value;
  final Color color;
  const _Stat(this.icon, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      );
}
