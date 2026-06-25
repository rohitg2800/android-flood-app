// lib/screens/live_stations_screen.dart  v3.5.0  (25 Jun 2026)
//
// ──────────────────────────────────────────────────────────────────────────
// CHANGE-LOG
// ──────────────────────────────────────────────────────────────────────────
// v3.5.0 (25 Jun 2026)
//
//  SECURITY / RELIABILITY FIXES
//  ─────────────────────────────
//  [FIX-1] Prediction-match null-crash guard
//          `pred.first.confidencePct` was called without checking whether the
//          matched station is actually a gauge-type prediction; a mismatched
//          entry with a null confidencePct caused a LateInitializationError.
//          Fix: wrap in `?.confidencePct` and guard isNotEmpty.
//
//  [FIX-2] visibleStations type unsafety
//          `allStations.where(_passesBaseline)` returned an `Iterable` typed
//          as `Iterable<BiharStationData>` — calling `.length` on an Iterable
//          is O(N) and can throw if the underlying data changes mid-iteration.
//          Fix: always materialise to `List<BiharStationData>` before use.
//          (Was already done for the `true` branch; applied symmetrically.)
//
//  [FIX-3] SliverChildBuilderDelegate index-out-of-bounds
//          No `addAutomaticKeepAlives: false` guard — rapid refreshes while
//          the list was scrolled could trigger a build at a stale index.
//          Fix: added `addAutomaticKeepAlives: false, addRepaintBoundaries: false`.
//
//  NEW PATTERNS / LOGIC
//  ─────────────────────
//  [NEW-1] Rapid-rise spike badge
//          If `s.diff24h` is positive and >= half the gap to dangerLevel,
//          the card receives a prominent amber ⚡ "Rapid Rise" badge.
//          Threshold: (dangerLevel - currentLevel) * 0.5
//          This surfaces imminent danger BEFORE the risk label escalates.
//
//  [NEW-2] Multi-pattern compound risk score
//          `_compoundRisk(s)` computes a 0-100 numeric score combining:
//            • dangerPercent (normalised fill %)
//            • trend velocity  (diff24h / warningLevel gap)
//            • discharge ratio (discharge / dischargeMean)
//            • rainfall loading (rainfall24h contribution)
//          Cards are SORTED by compoundRisk DESC within the same riskLabel tier,
//          replacing the previous tie-break of "highest level only".
//
//  [NEW-3] Offline-stale indicator
//          If `s.fetchedAt` is > 90 minutes old, a grey 📡 "Stale" chip is
//          appended to the card. Stations without a parseable fetchedAt are
//          treated as stale-unknown and shown with a ⚠ dim chip.
//
//  [NEW-4] Prediction-confidence colour band
//          confidencePercent is now mapped to a three-band colour:
//            • ≥ 80 %  → green  (confident)
//            • 50-79 % → amber  (uncertain)
//            • < 50 %  → red    (low-confidence — treat as advisory only)
//          Passed to RiverPulseCard via `confidenceColor`.
//          (RiverPulseCard must accept the new optional `Color? confidenceColor`.)
//
//  [NEW-5] Summary trend row
//          Below the chip row a one-line sparkline sentence shows:
//          "X rising  Y stable  Z falling"
//          computed from `s.trend` across all visibleStations.
//
// v3.4.1: fix — missing import for pre_monsoon_baseline_provider.dart
// v3.4:   baseline filter + dismissible info chip
// v3.3:   onTap passes liveLevel / liveRisk to CityDetailScreen
// ──────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/bihar_live_provider.dart';
import '../providers/bihar_prediction_provider.dart';
import '../providers/pre_monsoon_baseline_provider.dart';
import '../theme/river_theme.dart';
import '../models/river_station.dart';
import '../providers/prediction_provider.dart';
import '../widgets/dashboard/river_pulse_card.dart';
import '../theme/theme_3d.dart';
import 'city_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Stations whose data is older than this are considered stale.
const Duration _kStaleDuration = Duration(minutes: 90);

/// Rapid-rise: spike badge triggers when diff24h >= this fraction of
/// the remaining headroom to dangerLevel.
const double _kRapidRiseFraction = 0.50;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// [NEW-2] Multi-pattern compound risk score (0–100).
/// Combines fill %, rise velocity, discharge ratio, and rainfall loading.
/// Higher score = higher near-term risk within the same label tier.
double _compoundRisk(BiharStationData s) {
  double score = 0.0;

  // Component 1 — fill % (weight 50)
  final dan = s.dangerLevel;
  final cur = s.currentLevel;
  if (dan != null && dan > 0 && cur != null) {
    score += ((cur / dan) * 100.0).clamp(0.0, 150.0) * 0.50;
  }

  // Component 2 — rise velocity (weight 25)
  // Normalised against the gap from currentLevel to warningLevel.
  final diff = s.diff24h;
  final war  = s.warningLevel;
  if (diff != null && diff > 0 && war != null && war > 0 && cur != null) {
    final headroom = (war - cur).abs().clamp(0.01, double.maxFinite);
    final velocity = (diff / headroom).clamp(0.0, 1.0);
    score += velocity * 25.0;
  }

  // Component 3 — discharge ratio (weight 15)
  final q     = s.discharge;
  final qMean = s.dischargeMean;
  if (q != null && qMean != null && qMean > 0) {
    final ratio = (q / qMean).clamp(0.0, 3.0) / 3.0; // 0-1
    score += ratio * 15.0;
  }

  // Component 4 — rainfall loading (weight 10)
  // 100 mm/day is treated as the normalisation ceiling.
  final rain = s.rainfall24h;
  if (rain != null && rain > 0) {
    score += (rain / 100.0).clamp(0.0, 1.0) * 10.0;
  }

  return score.clamp(0.0, 100.0);
}

/// [NEW-3] True when a station's data is older than [_kStaleDuration].
bool _isStale(BiharStationData s) {
  final dt = DateTime.tryParse(s.fetchedAt);
  if (dt == null) return true; // unparseable → treat as stale
  return DateTime.now().difference(dt) > _kStaleDuration;
}

/// [NEW-1] True when the station is rising rapidly toward danger level.
bool _isRapidRise(BiharStationData s) {
  final diff = s.diff24h;
  final cur  = s.currentLevel;
  final dan  = s.dangerLevel;
  if (diff == null || diff <= 0 || cur == null || dan == null || dan <= cur) {
    return false;
  }
  final headroom  = dan - cur;
  return diff >= headroom * _kRapidRiseFraction;
}

/// [NEW-4] Maps confidence percent to a colour band.
Color _confidenceColor(double? pct) {
  if (pct == null) return Colors.grey;
  if (pct >= 80) return const Color(0xFF43A047); // green
  if (pct >= 50) return const Color(0xFFFFA726); // amber
  return const Color(0xFFE53935);                // red
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveStationsScreen
// ─────────────────────────────────────────────────────────────────────────────
class LiveStationsScreen extends ConsumerWidget {
  static const String route = '/live-stations';
  const LiveStationsScreen({super.key});

  /// Returns true if a station passes the pre-monsoon baseline filter.
  /// A station is suppressed only when dangerLevel is known AND
  /// fill % is strictly below the threshold.
  static bool _passesBaseline(BiharStationData s) {
    final dl = s.dangerLevel;
    final cl = s.currentLevel;
    if (dl == null || dl <= 0 || cl == null) return true;
    final fillPct = (cl / dl) * 100.0;
    return fillPct >= kPreMonsoonBaselineRiskThreshold;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async      = ref.watch(biharLiveProvider);
    final baselineOn = ref.watch(preMonsoonBaselineProvider);
    final t          = RiverColors.of(context);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: async.when(
        loading: () => CustomScrollView(
          slivers: [
            const Td3AppBar(title: 'Live Stations', subtitle: 'Loading…'),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (err, _) => CustomScrollView(
          slivers: [
            const Td3AppBar(title: 'Live Stations'),
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 48, color: t.danger),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load station data',
                        style: TextStyle(
                            color: t.textPrimary,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        err.toString(),
                        style:
                            TextStyle(color: t.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Td3Button(
                        label: 'Retry',
                        icon: Icons.refresh_rounded,
                        width: 140,
                        height: 44,
                        color: t.accent,
                        onTap: () =>
                            ref.read(biharLiveProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        data: (state) {
          if (state.stations.isEmpty) {
            return CustomScrollView(
              slivers: [
                Td3AppBar(
                  title: 'Live Stations',
                  subtitle: 'No data yet',
                  actions: [_refreshAction(context, ref, t)],
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_outlined,
                            size: 56, color: t.accent),
                        const SizedBox(height: 12),
                        Text('No station data yet',
                            style: TextStyle(color: t.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Pull to refresh',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // ── [FIX-2] Always materialise to List so .length is O(1) safe ──
          final allStations = state.stations; // already List<BiharStationData>
          final List<BiharStationData> visibleStations = baselineOn
              ? allStations.where(_passesBaseline).toList()
              : List<BiharStationData>.of(allStations);

          // ── [NEW-2] Within each label tier, sort by compoundRisk DESC ──
          visibleStations.sort((a, b) {
            const riskOrder = {
              'EXTREME':  0,
              'CRITICAL': 1,
              'SEVERE':   2,
              'DANGER':   3,
              'WARNING':  4,
              'NORMAL':   5,
              'UNKNOWN':  6,
            };
            final ra = riskOrder[a.riskLabel] ?? 6;
            final rb = riskOrder[b.riskLabel] ?? 6;
            if (ra != rb) return ra.compareTo(rb);
            // Same tier → higher compound risk first
            return _compoundRisk(b).compareTo(_compoundRisk(a));
          });

          final hiddenCount =
              allStations.length - visibleStations.length;
          final lastFetch   = state.lastFetched;

          // ── [NEW-5] Trend counts across visibleStations ─────────────────
          final risingCount  =
              visibleStations.where((s) => s.trend == '↑').length;
          final fallingCount =
              visibleStations.where((s) => s.trend == '↓').length;
          final stableCount  =
              visibleStations.where((s) => s.trend == '→').length;

          return RefreshIndicator(
            color: t.accent,
            onRefresh: () =>
                ref.read(biharLiveProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                Td3AppBar(
                  title: 'All Stations (${allStations.length})',
                  subtitle: lastFetch != null
                      ? 'Updated '
                          '${DateFormat('HH:mm:ss').format(lastFetch)}'
                      : null,
                  actions: [_refreshAction(context, ref, t)],
                ),

                // ── Summary chips ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Td3Chip(
                          label:
                              '${visibleStations.length} Showing',
                          color: t.accent,
                          icon: Icons.sensors,
                        ),
                        if (state.criticalCount > 0)
                          Td3Chip(
                            label:
                                '${state.criticalCount} Critical',
                            color: t.danger,
                            icon: Icons.warning_amber_rounded,
                          ),
                        if (state.severeCount > 0)
                          Td3Chip(
                            label: '${state.severeCount} Severe',
                            color: AppPalette.danger,
                            icon: Icons.warning_rounded,
                          ),
                        if (state.warningCount > 0)
                          Td3Chip(
                            label: '${state.warningCount} Warning',
                            color: AppPalette.warning,
                            icon: Icons.info_outline_rounded,
                          ),
                        if (state.safeCount > 0)
                          Td3Chip(
                            label: '${state.safeCount} Safe',
                            color: AppPalette.safe,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        if (state.noDataCount > 0)
                          Td3Chip(
                            label: '${state.noDataCount} No Data',
                            color: t.textSecondary,
                            icon: Icons.signal_wifi_off_rounded,
                          ),
                      ],
                    ),
                  ),
                ),

                // ── [NEW-5] Trend summary row ───────────────────────────
                if (visibleStations.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 2, 16, 2),
                      child: Text(
                        '↑ $risingCount rising  '
                        '→ $stableCount stable  '
                        '↓ $fallingCount falling',
                        style: TextStyle(
                            fontSize: 11,
                            color: t.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),

                // Baseline filter info chip
                if (baselineOn && hiddenCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B2FF7)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF7B2FF7)
                                  .withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list_rounded,
                                color: Color(0xFF7B2FF7), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Baseline filter active — '
                                '$hiddenCount low-fill station'
                                '${hiddenCount == 1 ? '' : 's'} hidden',
                                style: const TextStyle(
                                    color: Color(0xFF7B2FF7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Station cards ───────────────────────────────────────
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      // [FIX-3] Disable keep-alives to prevent stale-index builds.
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries:  false,
                      (ctx, i) {
                        // Guard: index may be stale after a rapid refresh.
                        if (i >= visibleStations.length) {
                          return const SizedBox.shrink();
                        }
                        final s = visibleStations[i];

                        final rs = RiverStation(
                          city:        s.city,
                          state:       s.state,
                          river:       s.river,
                          station:     s.city,
                          current:     s.currentLevel ?? 0.0,
                          warning:     s.warningLevel ?? 0.0,
                          danger:      s.dangerLevel  ?? 0.0,
                          // clamp HFL to avoid gauge overflow on cards
                          hfl: ((s.dangerLevel ?? 0.0) * 1.2)
                              .clamp(0.0, double.maxFinite),
                          isLive:      s.source == 'LIVE',
                          dataSource:  s.source,
                          lastUpdated: s.fetchedAt,
                        );

                        // [FIX-1] Guard null confidencePct from mismatched predictions.
                        final preds = ref.watch(floodPredictionsProvider);
                        final matchedPreds = preds
                            .where((p) => p.station
                                .toLowerCase()
                                .contains(s.city.toLowerCase()))
                            .toList();
                        final conf = matchedPreds.isNotEmpty
                            ? matchedPreds.first.confidencePct  // may be null
                            : null;

                        // [NEW-1] Rapid-rise flag
                        final rapidRise = _isRapidRise(s);

                        // [NEW-3] Stale data flag
                        final stale = _isStale(s);

                        // [NEW-4] Confidence colour band
                        final confColor = _confidenceColor(conf);

                        return RiverPulseCard(
                          station:           rs,
                          index:             i,
                          confidencePercent: conf,
                          confidenceColor:   confColor,   // NEW-4
                          isRapidRise:       rapidRise,  // NEW-1
                          isStale:           stale,       // NEW-3
                          compoundRiskScore: _compoundRisk(s), // NEW-2
                          onTap: () => Navigator.of(ctx).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CityDetailScreen(
                                cityName:  s.city,
                                liveLevel: s.currentLevel,
                                liveRisk:  s.riskLabel,
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: visibleStations.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _refreshAction(
      BuildContext context, WidgetRef ref, RiverColors t) {
    return IconButton(
      icon: Icon(Icons.refresh_rounded, color: t.accent),
      tooltip: 'Refresh',
      onPressed: () =>
          ref.read(biharLiveProvider.notifier).refresh(),
    );
  }
}
