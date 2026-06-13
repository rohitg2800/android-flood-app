// lib/screens/weather_screen.dart
// OpsFlood — WeatherScreen v4.1 — field names aligned with WeatherProvider v6
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen root
// ─────────────────────────────────────────────────────────────────────────────

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});
  static const String route = '/weather';
  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen>
    with TickerProviderStateMixin {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  bool  _searchOpen  = false;
  late AnimationController _searchBarCtrl;
  late Animation<double>   _searchBarAnim;
  late AnimationController _contentCtrl;
  late Animation<double>   _contentAnim;
  late AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _searchBarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _searchBarAnim = CurvedAnimation(
        parent: _searchBarCtrl, curve: Curves.easeOutCubic);

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _contentAnim = CurvedAnimation(
        parent: _contentCtrl, curve: Curves.easeOutCubic);

    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _searchBarCtrl.dispose();
    _contentCtrl.dispose();
    _rotateCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      _searchBarCtrl.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _searchFocus.requestFocus();
      });
    } else {
      _searchBarCtrl.reverse();
      _searchFocus.unfocus();
      _searchCtrl.clear();
      ref.read(weatherProvider.notifier).clearSearch();
    }
  }

  void _onSearchChanged(String v) {
    ref.read(weatherProvider.notifier).searchCity(v);
  }

  void _selectCity(CityResult city) {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() => _searchOpen = false);
    _searchBarCtrl.reverse();
    ref.read(weatherProvider.notifier).selectCity(city);
    _contentCtrl
      ..reset()
      ..forward();
  }

  /// Map an Open-Meteo / wttr WMO weather code to an emoji icon.
  static String _wmoIcon(int code) {
    if (code == 0)                          return '\u2600\uFE0F';  // Clear
    if (code <= 2)                          return '\u26C5';       // Partly cloudy
    if (code == 3)                          return '\u2601\uFE0F'; // Overcast
    if (code >= 45 && code <= 48)           return '\uD83C\uDF2B\uFE0F'; // Fog
    if (code >= 51 && code <= 67)           return '\uD83C\uDF27\uFE0F'; // Drizzle/Rain
    if (code >= 71 && code <= 77)           return '\u2744\uFE0F'; // Snow
    if (code >= 80 && code <= 82)           return '\uD83C\uDF26\uFE0F'; // Rain showers
    if (code >= 95 && code <= 99)           return '\u26C8\uFE0F'; // Thunderstorm
    return '\uD83C\uDF24\uFE0F';
  }

  static String _wmoDesc(int code) {
    if (code == 0)                          return 'Clear Sky';
    if (code <= 2)                          return 'Partly Cloudy';
    if (code == 3)                          return 'Overcast';
    if (code >= 45 && code <= 48)           return 'Foggy';
    if (code >= 51 && code <= 67)           return 'Rain';
    if (code >= 71 && code <= 77)           return 'Snow';
    if (code >= 80 && code <= 82)           return 'Rain Showers';
    if (code >= 95 && code <= 99)           return 'Thunderstorm';
    return 'Cloudy';
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(weatherProvider);
    final t  = RiverColors.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // ── 3D App bar ─────────────────────────────────────────────
              Td3AppBar(
                title: ws.cityName,
                subtitle: 'Weather Command',
                actions: [
                  IconButton(
                    icon: AnimatedBuilder(
                      animation: _rotateCtrl,
                      builder: (_, child) => Transform.rotate(
                        angle: _searchOpen
                            ? 0
                            : _rotateCtrl.value * 2 * math.pi,
                        child: child,
                      ),
                      child: Icon(Icons.refresh_rounded,
                          color: t.accent, size: 22),
                    ),
                    tooltip: 'Refresh',
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _contentCtrl.reset();
                      ref
                          .read(weatherProvider.notifier)
                          .fetchWeather(forceRefresh: true);
                      _contentCtrl.forward();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _searchOpen
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      color: t.accent,
                    ),
                    onPressed: _toggleSearch,
                  ),
                ],
              ),

              // ── Search bar (animated) ──────────────────────────────────
              SliverToBoxAdapter(
                child: SizeTransition(
                  sizeFactor: _searchBarAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      children: [
                        Td3InputField(
                          controller: _searchCtrl,
                          label: 'City',
                          hint: 'Search city\u2026',
                          icon: Icons.location_city_rounded,
                          required: false,
                          readOnly: false,
                          onChanged: _onSearchChanged,
                          suffixWidget: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: t.textSecondary, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    ref
                                        .read(weatherProvider.notifier)
                                        .clearSearch();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        // Search results dropdown
                        if (ws.searchResults.isNotEmpty)
                          Td3Card(
                            elevation: Td3.elevFloat,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: ws.searchResults
                                  .map(
                                    (c) => ListTile(
                                      dense: true,
                                      leading: Icon(Icons.location_on,
                                          color: t.accent, size: 18),
                                      title: Text(c.name,
                                          style: TextStyle(
                                              color: t.textPrimary,
                                              fontWeight: FontWeight.w600)),
                                      // CityResult has `admin1` not `state`
                                      subtitle: Text(
                                          c.admin1.isNotEmpty
                                              ? '${c.admin1}, ${c.country}'
                                              : c.country,
                                          style: TextStyle(
                                              color: t.textSecondary,
                                              fontSize: 11)),
                                      onTap: () => _selectCity(c),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _contentAnim,
                  child: _WeatherContent(
                    ws: ws,
                    t: t,
                    wmoIcon: _wmoIcon,
                    wmoDesc: _wmoDesc,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weather content (loading / error / data)
// ─────────────────────────────────────────────────────────────────────────────

class _WeatherContent extends StatelessWidget {
  final WeatherState ws;
  final RiverColors  t;
  final String Function(int code) wmoIcon;
  final String Function(int code) wmoDesc;

  const _WeatherContent({
    required this.ws,
    required this.t,
    required this.wmoIcon,
    required this.wmoDesc,
  });

  @override
  Widget build(BuildContext context) {
    // --- Loading ---
    if (ws.status == WeatherStatus.loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: t.accent),
        ),
      );
    }

    // --- Error ---
    if (ws.status == WeatherStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // RiverColors has riverDanger, not danger
            Icon(Icons.cloud_off_rounded, size: 56, color: t.riverDanger),
            const SizedBox(height: 12),
            Text(
              ws.error,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (ws.isRateLimited && ws.retryInSeconds > 0) ...[  
              const SizedBox(height: 8),
              Text(
                'Retrying in ${ws.retryInSeconds}s',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      );
    }

    // --- No data yet ---
    if (ws.current == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text('No weather data',
              style: TextStyle(color: t.textSecondary)),
        ),
      );
    }

    final w    = ws.current!;
    final icon = wmoIcon(w.weatherCode);
    final desc = wmoDesc(w.weatherCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Hero condition card ─────────────────────────────────────
          Td3Card(
            accentColor: t.accent,
            elevation: Td3.elevHigh,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // WeatherCurrent uses `tempC`, not `temperature`
                      Text(
                        '${w.tempC.toStringAsFixed(1)}\u00B0C',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          shadows: [
                            Shadow(
                                color: t.accent.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc.toUpperCase(),
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      // `feelsLikeC`, not `feelsLike`
                      Text(
                        'Feels like ${w.feelsLikeC.toStringAsFixed(1)}\u00B0C',
                        style:
                            TextStyle(color: t.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(icon, style: const TextStyle(fontSize: 72)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── KPI stat tiles ──────────────────────────────────────────
          Td3SectionHeader('Conditions', accentColor: t.accent),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: [
              Td3StatTile(
                value: '${w.humidity}%',
                label: 'HUMIDITY',
                valueColor: Colors.lightBlue,
                icon: Icons.water_drop_rounded,
              ),
              // `windKph`, not `windSpeed`
              Td3StatTile(
                value: '${(w.windKph / 3.6).toStringAsFixed(1)} m/s',
                label: 'WIND SPEED',
                valueColor: t.accent,
                icon: Icons.air_rounded,
              ),
              // `surfacePressure`, not `pressure`
              Td3StatTile(
                value: '${w.surfacePressure.toStringAsFixed(0)} hPa',
                label: 'PRESSURE',
                valueColor: AppPalette.gold,
                icon: Icons.compress_rounded,
              ),
              // `visibilityKm`, not `visibility`
              Td3StatTile(
                value: '${w.visibilityKm.toStringAsFixed(0)} km',
                label: 'VISIBILITY',
                valueColor: AppPalette.safe,
                icon: Icons.visibility_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 7-Day forecast ──────────────────────────────────────────
          // WeatherState has `forecast` (List<WeatherDay>),
          // not `dailyForecast` or `hourlyForecast`.
          if (ws.forecast.isNotEmpty) ...[
            Td3SectionHeader('7-Day Forecast', accentColor: t.accent),
            const SizedBox(height: 10),
            ...ws.forecast.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Td3Card(
                    elevation: Td3.elevMid,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            // WeatherDay.date is a String ("2026-06-13")
                            _fmtDate(d.date),
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12),
                          ),
                        ),
                        Text(wmoIcon(d.weatherCode),
                            style: const TextStyle(fontSize: 22)),
                        const Spacer(),
                        // WeatherDay uses `minC` / `maxC`, not `tempMin` / `tempMax`
                        Text(
                          '${d.minC.toStringAsFixed(0)}\u00B0 / '
                          '${d.maxC.toStringAsFixed(0)}\u00B0',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        const SizedBox(width: 10),
                        // WeatherDay uses `precipProb`, not `precipChance`
                        if (d.precipProb > 0)
                          Td3Chip(
                            label: '${d.precipProb.toStringAsFixed(0)}%',
                            color: Colors.lightBlue,
                            icon: Icons.grain,
                            fontSize: 10,
                          ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  static String _fmtDate(String iso) {
    try {
      return DateFormat('EEE, d MMM').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
