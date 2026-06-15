// lib/screens/dashboard_screen.dart  v8.8
//
// v8.8 (15 Jun 2026) — ML severity fields wired throughout
//
//   Changes from v8.7:
//   • Remove bare library; directive
//   • _AtRiskTile: predictedSeverity chip, riskScore bar,
//     willBreachDanger banner, peakLevel72h label
//   • _LiveStationTile: predictedSeverity micro-chip, riskScore bar,
//     confidencePercent subtitle
//   • _buildAtRiskCities: sorted by riskScore desc
//   • Summary row: breach count chip (willBreachDanger stations)
//   • All existing v8.7 logic unchanged

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../models/river_station.dart';
import '../models/flood_data.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/flood_provider.dart';
import '../providers/alert_provider.dart';
import 'city_detail_screen.dart';
import 'alerts_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'bihar_river_map_screen.dart';
import 'sos_screen.dart';
import 'weather_screen.dart';
import 'news_feed_screen.dart';
import 'ai_prediction_screen.dart';
import 'incident_report_screen.dart';
import 'crowd_report_feed_screen.dart';
import 'evacuation_routes_screen.dart';
import 'india_river_explorer_screen.dart';
import 'rainfall_forecast_screen.dart';
import 'community_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  static const String route = '/dashboard';

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(floodProvider).refresh();
  }

  String _sourceLabel(String src) {
    if (src.contains('LIVE_ENGINE') || src.contains('LiveEngine') ||
        src.contains('BIHAR_LIVE_ENGINE')) return 'LiveEngine';
    if (src.contains('WRD')) return 'WRD';
    if (src.contains('CWC') || src.contains('cwc') || src.contains('BEFIQR'))
      return 'CWC';
    if (src.contains('SEED')) return 'SEED';
    return 'DataFetch';
  }

  Color _sourceColor(String src) {
    switch (_sourceLabel(src)) {
      case 'LiveEngine': return const Color(0xFF00E676);
      case 'WRD':        return const Color(0xFF00B0FF);
      case 'CWC':        return const Color(0xFFFFD740);
      case 'SEED':       return const Color(0xFF9E9E9E);
      default:           return const Color(0xFFFF6E40);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t      = RiverColors.of(context);
    final fp     = ref.watch(floodProvider);
    final ap     = ref.watch(alertProvider);
    final merged = ref.watch(mergedStationsProvider);
    final live   = ref.watch(liveFloodDataProvider);

    final totalCount   = merged.length;
    final liveCount    = merged.where((s) => s.isLive).length;
    final extremeCount = merged.where((s) => s.dangerClass == DangerClass.extreme).length;
    final severeCount  = merged.where((s) =>
        s.dangerClass == DangerClass.severe ||
        s.dangerClass == DangerClass.extreme).length;
    final warningCount = merged.where((s) => s.dangerClass == DangerClass.aboveNormal).length;
    final normalCount  = merged.where((s) => s.dangerClass == DangerClass.normal).length;

    // ML breach count from liveFloodData
    final breachCount = live.where((fd) => fd.willBreachDanger == true).length;

    final leCount   = merged.where((s) => _sourceLabel(s.dataSource ?? '') == 'LiveEngine').length;
    final cwcCount  = merged.where((s) => _sourceLabel(s.dataSource ?? '') == 'CWC').length;
    final dfCount   = merged.where((s) => _sourceLabel(s.dataSource ?? '') == 'DataFetch').length;
    final wrdCount  = merged.where((s) => _sourceLabel(s.dataSource ?? '') == 'WRD').length;
    final seedCount = merged.where((s) => _sourceLabel(s.dataSource ?? '') == 'SEED').length;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: RefreshIndicator(
        color: t.accent,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            Td3AppBar(
              title: 'OpsFlood Bihar',
              subtitle: '$totalCount stations · $liveCount live'
                  '${breachCount > 0 ? "  ⚠ $breachCount breach" : ""}',
              actions: [
                IconButton(
                  icon: Icon(Icons.sos_rounded, color: t.riverDanger, size: 26),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SosScreen())),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSummaryRow(t, extremeCount, severeCount, warningCount, normalCount, breachCount),
                  const SizedBox(height: 12),
                  _buildSourceBreakdown(t, totalCount, leCount, cwcCount, dfCount, wrdCount, seedCount),
                  const SizedBox(height: 16),
                  _buildQuickActions(context, t),
                  const SizedBox(height: 16),
                  _buildAtRiskCities(context, t, merged, live),
                  const SizedBox(height: 16),
                  _buildLiveStations(context, t, merged, live),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary row ─────────────────────────────────────────────────────────
  Widget _buildSummaryRow(RiverColors t, int extreme, int severe,
      int warning, int normal, int breach) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'CRITICAL',
                value: '$severe',
                valueColor: t.riverDanger,
                icon: Icons.warning_rounded,
                iconColor: t.riverDanger,
                onTap: () => Navigator.pushNamed(context, AlertsScreen.route),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'WARNING',
                value: '$warning',
                valueColor: t.riverWarning,
                icon: Icons.notifications_active_rounded,
                iconColor: t.riverWarning,
                onTap: () => Navigator.pushNamed(context, AlertsScreen.route),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'NORMAL',
                value: '$normal',
                valueColor: t.riverNormal,
                icon: Icons.check_circle_outline_rounded,
                iconColor: t.riverNormal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'EXTREME',
                value: '$extreme',
                valueColor: const Color(0xFFFF1744),
                icon: Icons.flood_rounded,
                iconColor: const Color(0xFFFF1744),
                onTap: () => Navigator.pushNamed(context, AlertsScreen.route),
              ),
            ),
          ],
        ),
        // ML breach prediction banner
        if (breach > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1744).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF1744).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.query_stats_rounded,
                    color: Color(0xFFFF1744), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ML Model: $breach station${breach > 1 ? "s" : ""} predicted to breach danger level within 72h',
                    style: const TextStyle(
                        color: Color(0xFFFF1744),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Source breakdown banner ────────────────────────────────────────────
  Widget _buildSourceBreakdown(RiverColors t, int total,
      int le, int cwc, int df, int wrd, int seed) {
    return Td3Card(
      elevation: Td3.elevLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulseDot(color: const Color(0xFF00E676)),
                const SizedBox(width: 6),
                Text(
                  'LIVE DATA  ·  $total stations monitoring Bihar',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3),
                ),
                const Spacer(),
                // ML severity health dot
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2FF7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF7B2FF7).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_graph, color: Color(0xFF7B2FF7), size: 10),
                      SizedBox(width: 3),
                      Text('ML', style: TextStyle(
                          color: Color(0xFF7B2FF7),
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SourceBar(total: total, le: le, cwc: cwc, df: df, wrd: wrd, seed: seed),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (le   > 0) _SourceLegend(color: const Color(0xFF00E676), label: 'LiveEngine $le'),
                if (cwc  > 0) _SourceLegend(color: const Color(0xFFFFD740), label: 'CWC $cwc'),
                if (df   > 0) _SourceLegend(color: const Color(0xFFFF6E40), label: 'DataFetch $df'),
                if (wrd  > 0) _SourceLegend(color: const Color(0xFF00B0FF), label: 'WRD $wrd'),
                if (seed > 0) _SourceLegend(color: const Color(0xFF9E9E9E), label: 'Seed $seed'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions grid ────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, RiverColors t) {
    const actions = [
      _QA('AI Predictor',   Icons.auto_graph,              Color(0xFF7B2FF7), AiPredictionScreen.route),
      _QA('Rainfall',       Icons.cloudy_snowing,          Color(0xFF00B0FF), RainfallForecastScreen.route),
      _QA('River Map',      Icons.map_outlined,            Colors.blue,       BiharRiverMapScreen.route),
      _QA('Evacuation',     Icons.directions_run,          Colors.deepOrange, EvacuationRoutesScreen.route),
      _QA('Report',         Icons.report_problem_outlined, Colors.red,        IncidentReportScreen.route),
      _QA('Crowd Feed',     Icons.dynamic_feed_outlined,   Colors.teal,       CrowdReportFeedScreen.route),
      _QA('River Explorer', Icons.water_outlined,          Color(0xFF00E5FF), IndiaRiverExplorerScreen.route),
      _QA('Community',      Icons.people_outline,          Colors.green,      CommunityScreen.route),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: actions
              .map((a) => _QuickActionTile(
                    qa: a,
                    theme: t,
                    onTap: () => Navigator.pushNamed(context, a.route),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── At-Risk Cities ─────────────────────────────────────────────────────────
  Widget _buildAtRiskCities(
      BuildContext context, RiverColors t,
      List<RiverStation> merged, List<FloodData> live) {
    // Build lookup: city key -> FloodData (for ML fields)
    final fdMap = <String, FloodData>{
      for (final fd in live) fd.city.toLowerCase().trim(): fd,
    };

    final atRisk = merged
        .where((s) => s.dangerClass != DangerClass.normal)
        .toList()
      // Sort by ML riskScore desc, fall back to dangerClass ordinal
      ..sort((a, b) {
          final fdA = fdMap[a.city.toLowerCase().trim()];
          final fdB = fdMap[b.city.toLowerCase().trim()];
          final scoreA = fdA?.riskScore ?? (a.dangerClass.index * 20);
          final scoreB = fdB?.riskScore ?? (b.dangerClass.index * 20);
          return scoreB.compareTo(scoreA);
        });

    final topRisk = atRisk.take(8).toList();
    if (topRisk.isEmpty) return const SizedBox.shrink();

    return Td3Card(
      elevation: Td3.elevMid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(Icons.location_city_rounded,
                    color: t.riverDanger, size: 16),
                const SizedBox(width: 6),
                Text('At-Risk Cities',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const Spacer(),
                // ML badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2FF7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ML ranked',
                      style: TextStyle(
                          color: Color(0xFF7B2FF7),
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text('${topRisk.length} stations',
                    style: TextStyle(color: t.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...topRisk.map((s) => _AtRiskTile(
                station: s,
                floodData: fdMap[s.city.toLowerCase().trim()],
                theme: t,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            CityDetailScreen(cityName: s.city))),
              )),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Live Stations list ────────────────────────────────────────────────────
  Widget _buildLiveStations(
      BuildContext context, RiverColors t,
      List<RiverStation> merged, List<FloodData> live) {
    final fdMap = <String, FloodData>{
      for (final fd in live) fd.city.toLowerCase().trim(): fd,
    };

    final liveStations = merged.where((s) => s.isLive).toList()
      ..sort((a, b) {
          final fdA = fdMap[a.city.toLowerCase().trim()];
          final fdB = fdMap[b.city.toLowerCase().trim()];
          final scoreA = fdA?.riskScore ?? 0;
          final scoreB = fdB?.riskScore ?? 0;
          return scoreB.compareTo(scoreA);
        });

    final top = liveStations.take(12).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return Td3Card(
      elevation: Td3.elevMid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                _PulseDot(color: const Color(0xFF00E676)),
                const SizedBox(width: 6),
                Text('Live Stations',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const Spacer(),
                Text('${merged.where((s) => s.isLive).length} live',
                    style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...top.map((s) => _LiveStationTile(
                station: s,
                floodData: fdMap[s.city.toLowerCase().trim()],
                theme: t)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AtRiskTile  — v8.8: ML fields wired
// ─────────────────────────────────────────────────────────────────────────────
class _AtRiskTile extends StatelessWidget {
  final RiverStation station;
  final FloodData?   floodData; // may be null if not in liveFloodData
  final RiverColors  theme;
  final VoidCallback onTap;
  const _AtRiskTile({
    required this.station,
    required this.floodData,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t  = theme;
    final s  = station;
    final fd = floodData;
    final dc = s.dangerClass;

    Color  barColor;
    String dcLabel;
    switch (dc) {
      case DangerClass.extreme:     barColor = const Color(0xFFFF1744); dcLabel = 'EXTREME'; break;
      case DangerClass.severe:      barColor = const Color(0xFFFF6D00); dcLabel = 'DANGER';  break;
      case DangerClass.aboveNormal: barColor = const Color(0xFFFFD740); dcLabel = 'WARNING'; break;
      default:                      barColor = const Color(0xFF69F0AE); dcLabel = 'NORMAL';  break;
    }

    // Prefer ML severity colour if available
    final mlSev = fd?.predictedSeverity?.toUpperCase();
    Color mlColor = barColor;
    if (mlSev != null) {
      switch (mlSev) {
        case 'CRITICAL': mlColor = const Color(0xFFFF1744); break;
        case 'SEVERE':   mlColor = const Color(0xFFFF5500); break;
        case 'MODERATE': mlColor = const Color(0xFF10E88A); break;
        default:         mlColor = const Color(0xFF10E88A);
      }
    }

    final riskScore      = fd?.riskScore;
    final confidence     = fd?.confidencePercent;
    final willBreach     = fd?.willBreachDanger ?? false;
    final peak           = fd?.peakLevel72h;
    final max   = s.hfl    > 0 ? s.hfl    : (s.danger > 0 ? s.danger + 2 : 1.0);
    final frac  = (s.current / max).clamp(0.0, 1.0);
    final dFrac = (s.danger  / max).clamp(0.0, 1.0);
    final srcLabel = s.dataSource ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Breach warning banner
            if (willBreach)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1744).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF1744).withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.crisis_alert_rounded,
                        color: Color(0xFFFF1744), size: 11),
                    const SizedBox(width: 4),
                    Text(
                      peak != null
                          ? 'BREACH PREDICTED  ·  Peak ${peak.toStringAsFixed(2)} m'
                          : 'DANGER BREACH PREDICTED within 72h',
                      style: const TextStyle(
                          color: Color(0xFFFF1744),
                          fontSize: 9,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.city,
                          style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text('${s.river}  ·  $srcLabel',
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                // ML predicted severity chip
                if (mlSev != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: mlColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: mlColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_graph,
                            color: Color(0xFF7B2FF7), size: 9),
                        const SizedBox(width: 3),
                        Text(mlSev,
                            style: TextStyle(
                                color: mlColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // DangerClass badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: barColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: barColor.withOpacity(0.5)),
                  ),
                  child: Text(dcLabel,
                      style: TextStyle(
                          color: barColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 4),
                Text(
                  s.current > 0 ? '${s.current.toStringAsFixed(2)} m' : '——',
                  style: TextStyle(
                      color: barColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),

            const SizedBox(height: 5),

            // Level bar
            LayoutBuilder(builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 5, width: w,
                    decoration: BoxDecoration(
                      color: t.divider.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 5,
                    width: w * frac,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  if (dFrac > 0)
                    Positioned(
                      left: (w * dFrac).clamp(0, w - 1.5),
                      child: Container(
                          width: 1.5, height: 5,
                          color: t.riverDanger),
                    ),
                ],
              );
            }),

            // ML risk score + confidence row
            if (riskScore != null) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.query_stats_rounded,
                      color: Color(0xFF7B2FF7), size: 11),
                  const SizedBox(width: 4),
                  Text('Risk Score: $riskScore / 100',
                      style: const TextStyle(
                          color: Color(0xFF7B2FF7),
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (confidence != null)
                    Text(
                      'Conf: ${confidence.toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 9)),
                  const SizedBox(width: 8),
                  Text(
                    'DL: ${s.danger.toStringAsFixed(2)} m',
                    style: TextStyle(
                        color: t.riverDanger.withOpacity(0.8),
                        fontSize: 9)),
                ],
              ),
              const SizedBox(height: 3),
              // Risk score bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: riskScore / 100.0,
                  minHeight: 3,
                  backgroundColor: const Color(0xFF7B2FF7).withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(
                    riskScore >= 80
                        ? const Color(0xFFFF1744)
                        : riskScore >= 60
                            ? const Color(0xFFFF6D00)
                            : const Color(0xFF7B2FF7),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current: ${s.current > 0 ? s.current.toStringAsFixed(2) : "——"} m',
                      style: TextStyle(color: t.textSecondary, fontSize: 9)),
                  Text('DL: ${s.danger.toStringAsFixed(2)} m',
                      style: TextStyle(
                          color: t.riverDanger.withOpacity(0.8), fontSize: 9)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LiveStationTile  — v8.8: ML fields wired
// ─────────────────────────────────────────────────────────────────────────────
class _LiveStationTile extends StatelessWidget {
  final RiverStation station;
  final FloodData?   floodData;
  final RiverColors  theme;
  const _LiveStationTile({
    required this.station,
    required this.floodData,
    required this.theme,
  });

  String _srcLabel(String src) {
    if (src.contains('LIVE_ENGINE') || src.contains('LiveEngine') ||
        src.contains('BIHAR_LIVE_ENGINE')) return 'LE';
    if (src.contains('WRD'))                            return 'WRD';
    if (src.contains('CWC') || src.contains('BEFIQR')) return 'CWC';
    return 'DF';
  }

  Color _srcColor(String src) {
    switch (_srcLabel(src)) {
      case 'LE':  return const Color(0xFF00E676);
      case 'WRD': return const Color(0xFF00B0FF);
      case 'CWC': return const Color(0xFFFFD740);
      default:    return const Color(0xFFFF6E40);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t  = theme;
    final s  = station;
    final fd = floodData;
    final dc = s.dangerClass;

    Color levelColor;
    switch (dc) {
      case DangerClass.extreme:     levelColor = const Color(0xFFFF1744); break;
      case DangerClass.severe:      levelColor = const Color(0xFFFF6D00); break;
      case DangerClass.aboveNormal: levelColor = const Color(0xFFFFD740); break;
      default:                      levelColor = const Color(0xFF69F0AE); break;
    }

    final max        = s.hfl   > 0 ? s.hfl   : (s.danger > 0 ? s.danger + 2 : 1.0);
    final frac       = (s.current / max).clamp(0.0, 1.0);
    final src        = s.dataSource  ?? '';
    final time       = s.lastUpdated ?? '--:--';
    final sc         = _srcLabel(src);
    final scCol      = _srcColor(src);
    final mlSev      = fd?.predictedSeverity?.toUpperCase();
    final riskScore  = fd?.riskScore;
    final confidence = fd?.confidencePercent;
    final willBreach = fd?.willBreachDanger ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Source badge
              Container(
                width: 30,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: scCol.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: scCol.withOpacity(0.5)),
                ),
                child: Text(sc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: scCol,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.city,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        // ML severity micro-chip
                        if (mlSev != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B2FF7).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(mlSev,
                                style: const TextStyle(
                                    color: Color(0xFF7B2FF7),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Breach indicator
                        if (willBreach) ...[
                          const Icon(Icons.crisis_alert_rounded,
                              color: Color(0xFFFF1744), size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          s.current > 0
                              ? '${s.current.toStringAsFixed(2)} m'
                              : '——',
                          style: TextStyle(
                              color: levelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 3,
                        backgroundColor: t.divider.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                      ),
                    ),
                    // ML risk score micro-bar
                    if (riskScore != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: riskScore / 100.0,
                                minHeight: 2,
                                backgroundColor:
                                    const Color(0xFF7B2FF7).withOpacity(0.10),
                                valueColor: AlwaysStoppedAnimation(
                                  riskScore >= 80
                                      ? const Color(0xFFFF1744)
                                      : const Color(0xFF7B2FF7),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (confidence != null)
                            Text('${confidence.toStringAsFixed(0)}%✓',
                                style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 8)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(time,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source proportional bar
// ─────────────────────────────────────────────────────────────────────────────
class _SourceBar extends StatelessWidget {
  final int total, le, cwc, df, wrd, seed;
  const _SourceBar({
    required this.total, required this.le, required this.cwc,
    required this.df,    required this.wrd, required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            if (le   > 0) _seg(w, le   / total, const Color(0xFF00E676)),
            if (cwc  > 0) _seg(w, cwc  / total, const Color(0xFFFFD740)),
            if (df   > 0) _seg(w, df   / total, const Color(0xFFFF6E40)),
            if (wrd  > 0) _seg(w, wrd  / total, const Color(0xFF00B0FF)),
            if (seed > 0) _seg(w, seed / total, const Color(0xFF9E9E9E)),
          ],
        ),
      );
    });
  }

  Widget _seg(double w, double frac, Color c) =>
      Container(width: w * frac, height: 6, color: c);
}

class _SourceLegend extends StatelessWidget {
  final Color  color;
  final String label;
  const _SourceLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: RiverColors.of(context).textSecondary,
                  fontSize: 10)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulse dot
// ─────────────────────────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: widget.color, shape: BoxShape.circle)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Action model & tile
// ─────────────────────────────────────────────────────────────────────────────
class _QA {
  final String   label;
  final IconData icon;
  final Color    color;
  final String   route;
  const _QA(this.label, this.icon, this.color, this.route);
}

class _QuickActionTile extends StatelessWidget {
  final _QA        qa;
  final RiverColors theme;
  final VoidCallback onTap;
  const _QuickActionTile(
      {required this.qa, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: qa.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: qa.color.withOpacity(0.5), width: 1),
            ),
            child: Icon(qa.icon, color: qa.color, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            qa.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String   label;
  final String   value;
  final Color    valueColor;
  final IconData icon;
  final Color    iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Td3Card(
        elevation: Td3.elevLow,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      color: valueColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      color: t.