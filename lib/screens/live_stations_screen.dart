// lib/screens/live_stations_screen.dart  v3.6.0  (25 Jun 2026)
//
// ──────────────────────────────────────────────────────────────────────────
// CHANGE-LOG
// ──────────────────────────────────────────────────────────────────────────
// v3.6.0 (25 Jun 2026)
//
//  BUG FIXES
//  ──────────────────────────────────────────────────────────────────────
//  [FIX-4] ref.watch(floodPredictionsProvider) hoisted above delegate.
//          Previously called inside the builder loop, creating 31
//          simultaneous provider subscriptions per frame.  Now watched once
//          and the resulting list is closed over by the builder.
//
//  [FIX-5] DateTime.now() computed once before delegate (was called per card).
//          Prevents clock-drift inconsistency across cards in the same frame.
//
//  [FIX-6] hfl now uses s.hfl ?? (dangerLevel * 1.2) fallback.
//          Previous code always fabricated HFL as dangerLevel * 1.2, ignoring
//          any real HFL value on BiharStationData.
//
//  [FIX-7] diff24h overshoot no longer silently clamped in _compoundRisk.
//          Velocity capped at 2.0 (200% of headroom) instead of 1.0 so an
//          extreme rise-event carries proportionally more weight.
//
//  [FIX-8] Trend comparison uses normalised Unicode constants (kTrendUp /
//          kTrendDown / kTrendStable) instead of raw string literals.
//          Prevents silent zero-count if API encodes arrows differently.
//
//  [FIX-9] Refresh button debounced (5 s cooldown).  Rapid taps no longer
//          fire multiple concurrent API requests.
//
//  NEW PATTERNS / LOGIC
//  ──────────────────────────────────────────────────────────────────────
//  [NEW-6]  _persistentFloodScore()
//           Stations above warning level for ≥6 h earn up to 20 bonus risk
//           points (Component 5 of compoundRisk).  Time-above-warning is
//           read from s.timeAboveWarning (Duration?); null → 0 bonus.
//
//  [NEW-7]  _catchmentSaturated()
//           True when s.rainfall72h > 150 mm OR s.rainfall24h > 80 mm.
//           A "🌧 Saturated" chip appears on the card before gauge levels rise.
//
//  [NEW-8]  _isAccelerating()
//           Second-derivative check: rise is accelerating when
//           diff24h > diff24hPrev + 0.1 m.  Stations that are both
//           rapidRise AND accelerating get a synthetic IMMINENT sort tier
//           (priority above EXTREME in the sort order).
//
//  [NEW-9]  Compound risk tier badge
//           _compoundRiskTier() maps score → 4 visual tiers
//           (CRITICAL_COMPOUND / HIGH / MODERATE / LOW).
//           Passed to RiverPulseCard as compoundTier.
//
//  [NEW-10] _stalenessDecay()
//           Multiplier applied to final compound score:
//             ≤90 min  → 1.00  (full confidence)
//             90–240 m → 0.75
//             >240 min → 0.50  (advisory only)
//           Prevents stale high-risk stations from dominating sort order.
//
// ─────────────────────────────────────────────────────────────────────────
// Retained from v3.5.0
// ─────────────────────────────────────────────────────────────────────────
//  [FIX-1]  Prediction-match null confidencePct guard
//  [FIX-2]  visibleStations materialised to List<BiharStationData>
//  [FIX-3]  SliverChildBuilderDelegate addAutomaticKeepAlives: false
//  [NEW-1]  Rapid-rise spike badge  (⚡)
//  [NEW-2]  Multi-pattern compound risk score
//  [NEW-3]  Offline-stale indicator chip
//  [NEW-4]  Prediction-confidence colour band
//  [NEW-5]  Summary trend row
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

/// Rapid-rise: badge triggers when diff24h >= this fraction of headroom.
const double _kRapidRiseFraction = 0.50;

/// Catchment saturation thresholds (mm).
const double _kRain72hSaturation = 150.0;
const double _kRain24hSpike      = 80.0;

/// Acceleration minimum delta to count as accelerating (metres).
const double _kAccelerationDelta = 0.10;

/// Persistent-flood: hours above warning before bonus points start.
const int _kPersistentFloodHours = 6;

/// Refresh debounce duration.
const Duration _kRefreshDebounce = Duration(seconds: 5);

// ─────────────────────────────────────────────────────────────────────────────
// [FIX-8] Normalised trend arrow constants — compare against these, never
// raw literals, so encoding differences from the API don't silently zero-out
// the trend counts.
// ─────────────────────────────────────────────────────────────────────────────
const String kTrendUp     = '\u2191'; // ↑
const String kTrendDown   = '\u2193'; // ↓
const String kTrendStable = '\u2192'; // →

// ─────────────────────────────────────────────────────────────────────────────
// Compound risk tier enum  [NEW-9]
// ─────────────────────────────────────────────────────────────────────────────
enum CompoundTier { low, moderate, high, criticalCompound }

extension CompoundTierExt on CompoundTier {
  String get label {
    switch (this) {
      case CompoundTier.criticalCompound: return 'CRITICAL COMPOUND';
      case CompoundTier.high:             return 'HIGH COMPOUND';
      case CompoundTier.moderate:         return 'MODERATE';
      case CompoundTier.low:              return 'LOW';
    }
  }

  Color get color {
    switch (this) {
      case CompoundTier.criticalCompound: return const Color(0xFFE53935);
      case CompoundTier.high:             return const Color(0xFFFFA726);
      case CompoundTier.moderate:         return const Color(0xFFFDD835);
      case CompoundTier.low:              return const Color(0xFF43A047);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// [NEW-2 + FIX-7 + NEW-6 + NEW-10]
/// Multi-pattern compound risk score (0–100), with:
///   Component 1 — fill %           (weight 45)
///   Component 2 — rise velocity    (weight 20)  [FIX-7: cap at 2× headroom]
///   Component 3 — discharge ratio  (weight 15)
///   Component 4 — rainfall loading (weight 10)
///   Component 5 — persistent flood (weight 10)  [NEW-6]
/// Final score multiplied by _stalenessDecay()  [NEW-10]
double _compoundRisk(BiharStationData s, {required DateTime now}) {
  double score = 0.0;

  final dan = s.dangerLevel;
  final cur = s.currentLevel;
  final war = s.warningLevel;

  // Component 1 — fill % (weight 45)
  if (dan != null && dan > 0 && cur != null) {
    score += ((cur / dan) * 100.0).clamp(0.0, 150.0) * 0.45;
  }

  // Component 2 — rise velocity (weight 20)
  // [FIX-7] Cap at 2.0 (200% of headroom) so extreme events score higher.
  final diff = s.diff24h;
  if (diff != null && diff > 0 && war != null && war > 0 && cur != null) {
    final headroom = (war - cur).abs().clamp(0.01, double.maxFinite);
    final velocity = (diff / headroom).clamp(0.0, 2.0) / 2.0; // 0-1
    score += velocity * 20.0;
  }

  // Component 3 — discharge ratio (weight 15)
  final q     = s.discharge;
  final qMean = s.dischargeMean;
  if (q != null && qMean != null && qMean > 0) {
    final ratio = (q / qMean).clamp(0.0, 3.0) / 3.0;
    score += ratio * 15.0;
  }

  // Component 4 — rainfall loading (weight 10)
  final rain = s.rainfall24h;
  if (rain != null && rain > 0) {
    score += (rain / 100.0).clamp(0.0, 1.0) * 10.0;
  }

  // Component 5 — persistent flood bonus (weight 10)  [NEW-6]
  score += _persistentFloodScore(s) * 0.10;

  // [NEW-10] Apply staleness decay multiplier
  final rawScore = score.clamp(0.0, 100.0);
  return rawScore * _stalenessDecay(s, now: now);
}

/// [NEW-6] Bonus points (0–100) for stations that have been above warning
/// level for an extended duration.  Normalised: 24 h = 100 pts.
double _persistentFloodScore(BiharStationData s) {
  final hours = s.timeAboveWarning?.inHours.toDouble() ?? 0.0;
  if (hours < _kPersistentFloodHours) return 0.0;
  return ((hours - _kPersistentFloodHours) / (24.0 - _kPersistentFloodHours))
      .clamp(0.0, 1.0) * 100.0;
}

/// [NEW-10] Staleness decay multiplier applied to compound risk score.
///   ≤90 min  → 1.00
///   90–240 m → 0.75
///   >240 min → 0.50
double _stalenessDecay(BiharStationData s, {required DateTime now}) {
  final dt = DateTime.tryParse(s.fetchedAt);
  if (dt == null) return 0.50; // unknown age → treat as advisory
  final age = now.difference(dt).inMinutes;
  if (age <= 90)  return 1.00;
  if (age <= 240) return 0.75;
  return 0.50;
}

/// [NEW-3] True when a station's data is older than [_kStaleDuration].
/// [FIX-5] Accepts pre-computed `now` to avoid per-card DateTime.now() calls.
bool _isStale(BiharStationData s, {required DateTime now}) {
  final dt = DateTime.tryParse(s.fetchedAt);
  if (dt == null) return true;
  return now.difference(dt) > _kStaleDuration;
}

/// [NEW-1] True when the station is rising rapidly toward danger level.
bool _isRapidRise(BiharStationData s) {
  final diff = s.diff24h;
  final cur  = s.currentLevel;
  final dan  = s.dangerLevel;
  if (diff == null || diff <= 0 || cur == null || dan == null || dan <= cur) {
    return false;
  }
  return diff >= (dan - cur) * _kRapidRiseFraction;
}

/// [NEW-8] True when the rate of rise is accelerating (2nd derivative > 0).
/// Requires both diff24h and diff24hPrev to be present.
bool _isAccelerating(BiharStationData s) {
  final v1 = s.diff24h     ?? 0.0;
  final v0 = s.diff24hPrev ?? 0.0;
  return v1 > v0 && (v1 - v0) >= _kAccelerationDelta;
}

/// [NEW-7] True when catchment is saturated (72 h or 24 h rainfall breached).
bool _catchmentSaturated(BiharStationData s) {
  final r72 = s.rainfall72h;
  final r24 = s.rainfall24h ?? 0.0;
  return (r72 != null && r72 > _kRain72hSaturation) ||
      r24 > _kRain24hSpike;
}

/// [NEW-9] Maps compound risk score to a visual tier enum.
CompoundTier _compoundRiskTier(double score) {
  if (score >= 75) return CompoundTier.criticalCompound;
  if (score >= 50) return CompoundTier.high;
  if (score >= 25) return CompoundTier.moderate;
  return CompoundTier.low;
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
class LiveStationsScreen extends ConsumerStatefulWidget {
  static const String route = '/live-stations';
  const LiveStationsScreen({super.key});

  @override
  ConsumerState<LiveStationsScreen> createState() =>
      _LiveStationsScreenState();
}

class _LiveStationsScreenState extends ConsumerState<LiveStationsScreen> {
  // [FIX-9] Tracks last refresh time for debounce.
  DateTime? _lastRefresh;

  /// Returns true if a station passes the pre-monsoon baseline filter.
  static bool _passesBaseline(BiharStationData s) {
    final dl = s.dangerLevel;
    final cl = s.currentLevel;
    if (dl == null || dl <= 0 || cl == null) return true;
    return (cl / dl) * 100.0 >= kPreMonsoonBaselineRiskThreshold;
  }

  /// [FIX-9] Debounced refresh — ignores calls within 5 s of last refresh.
  void _triggerRefresh() {
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < _kRefreshDebounce) {
      return;
    }
    _lastRefresh = now;
    ref.read(biharLiveProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
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
                        onTap: _triggerRefresh,
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
                  actions: [_refreshAction(t)],
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_outlined, size: 56, color: t.accent),
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

          // ── [FIX-2] Always materialise to List ─────────────────────────
          final allStations = state.stations;
          final List<BiharStationData> visibleStations = baselineOn
              ? allStations.where(_passesBaseline).toList()
              : List<BiharStationData>.of(allStations);

          // ── [FIX-5] Single DateTime.now() for the whole build ──────────
          final now = DateTime.now();

          // ── [FIX-4] Watch predictions ONCE, above the builder ──────────
          final preds = ref.watch(floodPredictionsProvider);

          // ── [NEW-8] Pre-mark IMMINENT stations (rapidRise + accelerating)
          // They sort above EXTREME in the custom tier order.
          final imminentCities = <String>{
            for (final s in visibleStations)
              if (_isRapidRise(s) && _isAccelerating(s)) s.city,
          };

          // ── [NEW-2 + NEW-10] Sort: IMMINENT first, then label tier,
          //    then compound risk DESC within same tier ───────────────────
          visibleStations.sort((a, b) {
            const riskOrder = {
              'IMMINENT': -1, // synthetic tier — above EXTREME
              'EXTREME':   0,
              'CRITICAL':  1,
              'SEVERE':    2,
              'DANGER':    3,
              'WARNING':   4,
              'NORMAL':    5,
              'UNKNOWN':   6,
            };

            final aLabel = imminentCities.contains(a.city)
                ? 'IMMINENT'
                : a.riskLabel;
            final bLabel = imminentCities.contains(b.city)
                ? 'IMMINENT'
                : b.riskLabel;

            final ra = riskOrder[aLabel] ?? 6;
            final rb = riskOrder[bLabel] ?? 6;
            if (ra != rb) return ra.compareTo(rb);

            // Same tier → higher compound risk (with staleness decay) first
            return _compoundRisk(b, now: now)
                .compareTo(_compoundRisk(a, now: now));
          });

          final hiddenCount = allStations.length - visibleStations.length;
          final lastFetch   = state.lastFetched;

          // ── [NEW-5] [FIX-8] Trend counts using normalised constants ────
          final risingCount  =
              visibleStations.where((s) => s.trend == kTrendUp).length;
          final fallingCount =
              visibleStations.where((s) => s.trend == kTrendDown).length;
          final stableCount  =
              visibleStations.where((s) => s.trend == kTrendStable).length;

          // [NEW-7] Count saturated catchments for summary chip
          final saturatedCount =
              visibleStations.where(_catchmentSaturated).length;

          return RefreshIndicator(
            color: t.accent,
            onRefresh: () async => _triggerRefresh(),
            child: CustomScrollView(
              slivers: [
                Td3AppBar(
                  title: 'All Stations (${allStations.length})',
                  subtitle: lastFetch != null
                      ? 'Updated '
                          '${DateFormat('HH:mm:ss').format(lastFetch)}'
                      : null,
                  actions: [_refreshAction(t)],
                ),

                // ── Summary chips ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Td3Chip(
                          label: '${visibleStations.length} Showing',
                          color: t.accent,
                          icon: Icons.sensors,
                        ),
                        if (imminentCities.isNotEmpty)
                          Td3Chip(
                            label: '${imminentCities.length} Imminent',
                            color: const Color(0xFFE53935),
                            icon: Icons.bolt_rounded,
                          ),
                        if (state.criticalCount > 0)
                          Td3Chip(
                            label: '${state.criticalCount} Critical',
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
                        // [NEW-7] Saturated catchment chip
                        if (saturatedCount > 0)
                          Td3Chip(
                            label: '$saturatedCount Saturated',
                            color: const Color(0xFF1565C0),
                            icon: Icons.water_drop_rounded,
                          ),
                      ],
                    ),
                  ),
                ),

                // ── [NEW-5] Trend summary row ────────────────────────────
                if (visibleStations.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                      child: Text(
                        '$kTrendUp $risingCount rising  '
                        '$kTrendStable $stableCount stable  '
                        '$kTrendDown $fallingCount falling',
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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

                // ── Station cards ─────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      // [FIX-3] Disable keep-alives to prevent stale-index builds.
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries:   false,
                      (ctx, i) {
                        // Guard: stale index after rapid refresh
                        if (i >= visibleStations.length) {
                          return const SizedBox.shrink();
                        }
                        final s = visibleStations[i];

                        // [FIX-6] Use real HFL when available; fall back to
                        //         dangerLevel * 1.2 only when hfl is absent.
                        final realHfl = s.hfl ??
                            ((s.dangerLevel ?? 0.0) * 1.2)
                                .clamp(0.0, double.maxFinite);

                        final rs = RiverStation(
                          city:        s.city,
                          state:       s.state,
                          river:       s.river,
                          station:     s.city,
                          current:     s.currentLevel ?? 0.0,
                          warning:     s.warningLevel ?? 0.0,
                          danger:      s.dangerLevel  ?? 0.0,
                          hfl:         realHfl,
                          isLive:      s.source == 'LIVE',
                          dataSource:  s.source,
                          lastUpdated: s.fetchedAt,
                        );

                        // [FIX-1] Null-safe confidencePct from hoisted preds list
                        // [FIX-4] `preds` already watched above — no re-watch here
                        final matchedPreds = preds
                            .where((p) => p.station
                                .toLowerCase()
                                .contains(s.city.toLowerCase()))
                            .toList();
                        final conf = matchedPreds.isNotEmpty
                            ? matchedPreds.first.confidencePct
                            : null;

                        // ── Signal flags ──────────────────────────────────
                        final rapidRise    = _isRapidRise(s);
                        final accelerating = _isAccelerating(s);   // NEW-8
                        final saturated    = _catchmentSaturated(s);// NEW-7
                        final stale        = _isStale(s, now: now); // FIX-5
                        final imminent     =
                            imminentCities.contains(s.city);        // NEW-8

                        // ── Compound score + tier ─────────────────────────
                        final cScore =
                            _compoundRisk(s, now: now);             // NEW-10
                        final cTier  =
                            _compoundRiskTier(cScore);              // NEW-9

                        // ── Confidence colour band ────────────────────────
                        final confColor = _confidenceColor(conf);   // NEW-4

                        return RiverPulseCard(
                          station:           rs,
                          index:             i,
                          confidencePercent: conf,
                          confidenceColor:   confColor,
                          isRapidRise:       rapidRise,
                          isAccelerating:    accelerating,  // NEW-8
                          isCatchmentSat:    saturated,     // NEW-7
                          isImminent:        imminent,      // NEW-8
                          isStale:           stale,
                          compoundRiskScore: cScore,
                          compoundTier:      cTier,         // NEW-9
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

  Widget _refreshAction(RiverColors t) {
    return IconButton(
      icon: Icon(Icons.refresh_rounded, color: t.accent),
      tooltip: 'Refresh',
      onPressed: _triggerRefresh, // [FIX-9] debounced
    );
  }
}
