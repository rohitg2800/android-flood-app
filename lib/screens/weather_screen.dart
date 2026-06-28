// lib/screens/weather_screen.dart
// WeatherScreen — Full live weather using weatherProvider (no Freezed .when)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';

class WeatherScreen extends ConsumerStatefulWidget {
  static const String route = '/weather';
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t       = RiverColors.of(context);
    final weather = ref.watch(weatherProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: _buildAppBar(t, weather),
      body: SafeArea(
        child: switch (weather.status) {
          WeatherStatus.idle    => _buildLoading(t),
          WeatherStatus.loading => _buildLoading(t),
          WeatherStatus.error   => _buildError(t, weather),
          WeatherStatus.loaded  => _buildLoaded(t, weather),
        },
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(RiverColors t, WeatherState weather) {
    return AppBar(
      backgroundColor: t.cardBg,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: t.textSecondary, size: 16),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: _showSearch
          ? _SearchField(t: t, ctrl: _searchCtrl, onSearch: _onSearch)
          : Row(
              children: [
                Icon(Icons.wb_cloudy_rounded, color: t.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weather.cityName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ),
              ],
            ),
      actions: [
        if (!_showSearch)
          IconButton(
            icon: Icon(Icons.search_rounded, color: t.textSecondary),
            onPressed: () => setState(() => _showSearch = true),
          ),
        if (_showSearch)
          IconButton(
            icon: Icon(Icons.close_rounded, color: t.textSecondary),
            onPressed: () {
              setState(() => _showSearch = false);
              _searchCtrl.clear();
              ref.read(weatherProvider.notifier).clearSearch();
            },
          ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: t.accent),
          onPressed: () =>
              ref.read(weatherProvider.notifier).fetchWeather(forceRefresh: true),
        ),
      ],
    );
  }

  void _onSearch(String query) {
    ref.read(weatherProvider.notifier).searchCity(query);
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  Widget _buildLoading(RiverColors t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: t.accent),
          const SizedBox(height: 16),
          Text('Fetching weather…',
              style: TextStyle(color: t.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Error ────────────────────────────────────────────────────────────────

  Widget _buildError(RiverColors t, WeatherState weather) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: t.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(weather.error,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary, fontSize: 13)),
            if (weather.retryInSeconds > 0) ...[  
              const SizedBox(height: 8),
              Text('Retrying in ${weather.retryInSeconds}s',
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: t.accent),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Now'),
              onPressed: () =>
                  ref.read(weatherProvider.notifier).fetchWeather(forceRefresh: true),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Loaded ───────────────────────────────────────────────────────────────

  Widget _buildLoaded(RiverColors t, WeatherState weather) {
    final cur = weather.current!;
    return RefreshIndicator(
      color: t.accent,
      onRefresh: () =>
          ref.read(weatherProvider.notifier).fetchWeather(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search results overlay
          if (weather.searchLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(color: t.accent),
            ),
          if (weather.searchResults.isNotEmpty)
            _SearchResults(
              t: t,
              results: weather.searchResults,
              onSelect: (city) {
                ref.read(weatherProvider.notifier).selectCity(city);
                setState(() => _showSearch = false);
                _searchCtrl.clear();
              },
            ),

          // Current conditions
          _CurrentCard(t: t, cur: cur, cityName: weather.cityName),
          const SizedBox(height: 16),

          // Stat row
          _StatRow(t: t, cur: cur),
          const SizedBox(height: 16),

          // 7-day forecast
          if (weather.forecast.isNotEmpty) ...[  
            Text('7-DAY FORECAST',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
            const SizedBox(height: 10),
            ...weather.forecast.map((d) => _ForecastRow(t: t, day: d)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final RiverColors t;
  final TextEditingController ctrl;
  final ValueChanged<String> onSearch;
  const _SearchField(
      {required this.t, required this.ctrl, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      autofocus: true,
      onChanged: onSearch,
      style: TextStyle(color: t.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search city…',
        hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
        border: InputBorder.none,
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final RiverColors t;
  final List<CityResult> results;
  final ValueChanged<CityResult> onSelect;
  const _SearchResults(
      {required this.t, required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        children: results
            .map(
              (c) => ListTile(
                dense: true,
                leading:
                    Icon(Icons.location_on_rounded, color: t.accent, size: 16),
                title: Text(c.displayName,
                    style:
                        TextStyle(color: t.textPrimary, fontSize: 13)),
                onTap: () => onSelect(c),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CurrentCard extends StatelessWidget {
  final RiverColors t;
  final WeatherCurrent cur;
  final String cityName;
  const _CurrentCard(
      {required this.t, required this.cur, required this.cityName});

  @override
  Widget build(BuildContext context) {
    final icon = _wmoIcon(cur.weatherCode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.accent.withValues(alpha: 0.18), t.cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        children: [
          Icon(icon, color: t.accent, size: 52),
          const SizedBox(height: 8),
          Text('${cur.tempC.toStringAsFixed(1)}°C',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w900)),
          Text(_wmoLabel(cur.weatherCode),
              style: TextStyle(color: t.textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Feels like ${cur.feelsLikeC.toStringAsFixed(1)}°C',
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final RiverColors t;
  final WeatherCurrent cur;
  const _StatRow({required this.t, required this.cur});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(t: t, icon: Icons.water_drop_rounded,
            label: 'Humidity', value: '${cur.humidity}%'),
        const SizedBox(width: 8),
        _StatChip(t: t, icon: Icons.air_rounded,
            label: 'Wind', value: '${cur.windKph.toStringAsFixed(0)} km/h'),
        const SizedBox(width: 8),
        _StatChip(t: t, icon: Icons.umbrella_rounded,
            label: 'Rain', value: '${cur.precipMm.toStringAsFixed(1)} mm'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final RiverColors t;
  final IconData icon;
  final String label;
  final String value;
  const _StatChip(
      {required this.t,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.stroke),
        ),
        child: Column(
          children: [
            Icon(icon, color: t.accent, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            Text(label,
                style: TextStyle(color: t.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final RiverColors t;
  final WeatherDay day;
  const _ForecastRow({required this.t, required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(_formatDate(day.date),
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Icon(_wmoIcon(day.weatherCode), color: t.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${day.rainMm.toStringAsFixed(1)} mm rain',
              style: TextStyle(color: t.textSecondary, fontSize: 11),
            ),
          ),
          Text('${day.minC.toStringAsFixed(0)}°',
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
          const SizedBox(width: 4),
          Text('/',
              style: TextStyle(color: t.stroke, fontSize: 12)),
          const SizedBox(width: 4),
          Text('${day.maxC.toStringAsFixed(0)}°',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WMO weather-code helpers
// ─────────────────────────────────────────────────────────────────────────────

IconData _wmoIcon(int code) {
  if (code == 0)              return Icons.wb_sunny_rounded;
  if (code <= 2)              return Icons.wb_cloudy_rounded;
  if (code <= 9)              return Icons.cloud_rounded;
  if (code <= 49)             return Icons.foggy;
  if (code <= 59)             return Icons.grain_rounded;
  if (code <= 69)             return Icons.water_drop_rounded;
  if (code <= 79)             return Icons.ac_unit_rounded;
  if (code <= 82)             return Icons.umbrella_rounded;
  if (code <= 86)             return Icons.cloudy_snowing;
  if (code <= 99)             return Icons.thunderstorm_rounded;
  return Icons.wb_cloudy_rounded;
}

String _wmoLabel(int code) {
  if (code == 0)  return 'Clear sky';
  if (code == 1)  return 'Mainly clear';
  if (code == 2)  return 'Partly cloudy';
  if (code == 3)  return 'Overcast';
  if (code <= 49) return 'Fog';
  if (code <= 59) return 'Drizzle';
  if (code <= 69) return 'Rain';
  if (code <= 79) return 'Snow';
  if (code <= 82) return 'Rain showers';
  if (code <= 86) return 'Snow showers';
  if (code <= 99) return 'Thunderstorm';
  return 'Cloudy';
}
