// lib/screens/weather_screen.dart
// OpsFlood — WeatherScreen v4.0 — 3D theme
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
  final _searchCtrl   = TextEditingController();
  final _searchFocus  = FocusNode();
  bool  _searchOpen   = false;
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
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      children: [
                        Td3InputField(
                          controller: _searchCtrl,
                          label: 'City',
                          hint: 'Search city…',
                          icon: Icons.location_city_rounded,
                          required: false,
                          readOnly: false,
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
                                              fontWeight:
                                                  FontWeight.w600)),
                                      subtitle: Text(
                                          '${c.state}, ${c.country}',
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
                    contentAnim: _contentAnim,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: 80)),
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
  final WeatherState    ws;
  final RiverColors     t;
  final Animation<double> contentAnim;
  const _WeatherContent(
      {required this.ws, required this.t, required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    if (ws.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: t.accent),
        ),
      );
    }
    if (ws.error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: t.danger),
            const SizedBox(height: 12),
            Text(
              ws.error!,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (ws.current == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text('No weather data',
              style: TextStyle(color: t.textSecondary)),
        ),
      );
    }

    final w = ws.current!;

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
                      Text(
                        '${w.temperature.toStringAsFixed(1)}°C',
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
                        w.description.toUpperCase(),
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Feels like ${w.feelsLike.toStringAsFixed(1)}°C',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  w.icon,
                  style: const TextStyle(fontSize: 72),
                ),
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
              Td3StatTile(
                value: '${w.windSpeed.toStringAsFixed(1)} m/s',
                label: 'WIND SPEED',
                valueColor: t.accent,
                icon: Icons.air_rounded,
              ),
              Td3StatTile(
                value: '${w.pressure} hPa',
                label: 'PRESSURE',
                valueColor: AppPalette.gold,
                icon: Icons.compress_rounded,
              ),
              Td3StatTile(
                value: '${w.visibility.toStringAsFixed(0)} km',
                label: 'VISIBILITY',
                valueColor: AppPalette.safe,
                icon: Icons.visibility_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Condition tags ──────────────────────────────────────────
          if (ws.conditionTags.isNotEmpty) ...[
            Td3SectionHeader('Conditions', accentColor: t.accent),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ws.conditionTags
                  .map((tag) => Td3Chip(
                        label: tag.label,
                        color: tag.color,
                        icon: tag.icon,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Hourly / daily forecast ─────────────────────────────────
          if (ws.hourlyForecast.isNotEmpty) ...[
            Td3SectionHeader('Hourly Forecast', accentColor: t.accent),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ws.hourlyForecast.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final h = ws.hourlyForecast[i];
                  return Td3Card(
                    accentColor: t.accent,
                    elevation: Td3.elevMid,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('HH:mm')
                              .format(h.time.toLocal()),
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(h.icon,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          '${h.temperature.toStringAsFixed(0)}°',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Daily forecast ──────────────────────────────────────────
          if (ws.dailyForecast.isNotEmpty) ...[
            Td3SectionHeader('7-Day Forecast', accentColor: t.accent),
            const SizedBox(height: 10),
            ...ws.dailyForecast.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Td3Card(
                    elevation: Td3.elevMid,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            DateFormat('EEE, d MMM')
                                .format(d.date.toLocal()),
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12),
                          ),
                        ),
                        Text(d.icon,
                            style: const TextStyle(fontSize: 22)),
                        const Spacer(),
                        Text(
                          '${d.tempMin.toStringAsFixed(0)}° / '
                          '${d.tempMax.toStringAsFixed(0)}°',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        const SizedBox(width: 10),
                        if (d.precipChance > 0)
                          Td3Chip(
                            label: '${d.precipChance}%',
                            color: Colors.lightBlue,
                            icon: Icons.grain,
                            fontSize: 10,
                          ),
                      ],
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
