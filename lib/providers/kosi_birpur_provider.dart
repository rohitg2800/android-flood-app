// lib/providers/kosi_birpur_provider.dart  v2.1
//
// CHANGE v2.1 (12 Jun 2026) — eliminate 210 / 212 m seed cards
//
//   PROBLEM:
//     When all external sources fail, kosiBirpurProvider returned a
//     KosiBirpurReading with level=210.80 (a hardcoded seed constant).
//     That propagated into mergedStationsProvider as current=210.80 which
//     rendered as a "210 m" card on the dashboard.
//
//     Additionally cwcStationsWithBirpurProvider had its own
//     currentLevel: 210.80 fallback that showed a second 210m card via
//     the CWC/Bihar live panel path.
//
//   FIX:
//     • kosiBirpurProvider returns null when all sources are down so the
//       caller (mergedStationsProvider v8.5) uses its current=0.0 sentinel.
//     • cwcStationsWithBirpurProvider fallback uses currentLevel: 0.0 so
//       the card shows '——' / NORMAL instead of a fake 210 m value.
//
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../services/kosi_birpur_service.dart';
import '../services/befiqr_cwc_service.dart';
import '../services/data_fetch_engine.dart';
import 'cwc_provider.dart';
import 'data_fetch_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────────
// 1. Raw enrichment from KosiBirpurService (discharge, trend, WRIS)
// ─────────────────────────────────────────────────────────────────────────────────
final _birpurEnrichmentProvider =
    FutureProvider.autoDispose<KosiBirpurReading?>((ref) async {
  try {
    final r = await KosiBirpurService().fetchLive();
    // Only return live readings — discard SEED to avoid 210m ghost cards
    return (r == null || r.source == 'SEED') ? null : r;
  } catch (e) {
    debugPrint('[KosiBirpur] enrichment failed: $e');
    return null;
  }
});

// ─────────────────────────────────────────────────────────────────────────────────
// 2. kosiBirpurProvider — THE canonical Birpur entry
//
//  v2.1: returns null (not a SEED reading) when all sources are down.
//  mergedStationsProvider handles null by using its own current=0.0
//  sentinel — card shows '——' / NORMAL, NOT a fake 210 m value.
// ─────────────────────────────────────────────────────────────────────────────────
final kosiBirpurProvider =
    FutureProvider.autoDispose<KosiBirpurReading?>((ref) async {
  final enrichFuture = ref.watch(_birpurEnrichmentProvider.future);
  final dfSnap       = DataFetchEngine.instance.last;

  final dfBirpur = dfSnap?.stations.where((s) =>
      s.stationName.toLowerCase().contains('birpur')).firstOrNull;

  final enrich = await enrichFuture;

  // ── Level resolution ─────────────────────────────────────────────────────────────
  if (enrich != null) {
    // KosiBirpurService got a live reading — use its level (AMSL, precise)
    final discharge = enrich.dischargeCumecs ?? dfBirpur?.flowRateCumecs;
    if (kDebugMode) {
      debugPrint('[KosiBirpur] ✅ live level=${enrich.levelM} (${enrich.source})'
          '${discharge != null ? " Q=${discharge.toStringAsFixed(0)}" : ""}');
    }
    return KosiBirpurReading(
      levelM:          enrich.levelM,
      dangerLevel:     enrich.dangerLevel,
      warningLevel:    enrich.warningLevel,
      dischargeCumecs: discharge,
      trend:           enrich.trend,
      observedAt:      enrich.observedAt,
      source:          enrich.source,
    );
  }

  if (dfBirpur != null && dfBirpur.isLive) {
    // DataFetch has a GloFAS-estimated level — validate it is plausible
    // (Birpur gauge ~74 m MSL; reject discharge values read as m MSL)
    final dl = dfBirpur.dangerLevel;
    if (dl >= 50.0 && dl <= 90.0) {
      if (kDebugMode) {
        debugPrint('[KosiBirpur] ⚠ GloFAS fallback level=${dfBirpur.currentLevel}');
      }
      return KosiBirpurReading(
        levelM:          dfBirpur.currentLevel,
        dangerLevel:     dl,
        warningLevel:    dfBirpur.warningLevel ?? (dl - 1.0),
        dischargeCumecs: dfBirpur.flowRateCumecs,
        trend:           null,
        observedAt:      dfBirpur.fetchedAt ?? DateTime.now(),
        source:          'GloFAS',
      );
    }
  }

  // v2.1: ALL sources down — return null so mergedStationsProvider uses
  // current=0.0 SEED sentinel.  Never return a fake 210/212 m level.
  debugPrint('[KosiBirpur] all sources down — returning null (SEED suppressed)');
  return null;
});

// ─────────────────────────────────────────────────────────────────────────────────
// 3. As a CwcStation (drop-in for any existing widget)
// ─────────────────────────────────────────────────────────────────────────────────
final kosiBirpurStationProvider =
    Provider.autoDispose<AsyncValue<CwcStation?>>((ref) {
  return ref.watch(kosiBirpurProvider).whenData((r) => r?.toCwcStation());
});

// ─────────────────────────────────────────────────────────────────────────────────
// 4. Combined: all Bihar CWC stations + enriched Birpur injected
//
//  v2.1: fallback CwcStation uses currentLevel: 0.0 (was 210.80)
// ─────────────────────────────────────────────────────────────────────────────────
final cwcStationsWithBirpurProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  final allAsync    = ref.watch(cwcStationsProvider);
  final birpurAsync = ref.watch(kosiBirpurStationProvider);

  return allAsync.whenData((allStations) {
    final filtered = allStations
        .where((s) =>
            !(s.river.toLowerCase().contains('kosi') &&
              s.site.toLowerCase().contains('birpur')))
        .toList();

    final liveBirpur = birpurAsync.value;
    if (liveBirpur != null) {
      // Live reading available — inject it
      filtered.add(liveBirpur);
    } else {
      // All sources down — inject a 0.0 sentinel so no fake level is shown
      filtered.add(CwcStation(
        river:        'Kosi',
        site:         'Birpur',
        currentLevel: 0.0,   // v2.1: was 210.80 (fake seed level)
        dangerLevel:  kBirpurDangerLevel,
        isFromSeed:   true,
        fetchedAt:    DateTime(2026, 6, 1),
      ));
    }

    filtered.sort((a, b) {
      if (a.river == 'Kosi' && b.river != 'Kosi') return -1;
      if (b.river == 'Kosi' && a.river != 'Kosi') return  1;
      final r = a.river.compareTo(b.river);
      return r != 0 ? r : a.site.compareTo(b.site);
    });
    return filtered;
  });
});

// ─────────────────────────────────────────────────────────────────────────────────
// 5. Kosi-only list
// ─────────────────────────────────────────────────────────────────────────────────
final kosiStationsProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  return ref.watch(cwcStationsWithBirpurProvider).whenData(
    (list) => list
        .where((s) => s.river.toLowerCase().contains('kosi'))
        .toList()
      ..sort((a, b) => a.site.compareTo(b.site)),
  );
});

// ─────────────────────────────────────────────────────────────────────────────────
// 6. BirpurBadge (dashboard tile convenience)
//
//  v2.1: whenData returns null when kosiBirpurProvider is null.
//  Callers that consumed birpurBadgeProvider should guard .value == null
//  and show a '——' / loading state instead of a 210 m reading.
// ─────────────────────────────────────────────────────────────────────────────────
class BirpurBadge {
  final double   level;
  final double   dangerLevel;
  final String   status;
  final String   source;
  final DateTime observedAt;
  final bool     isStale;
  final double?  dischargeCumecs;
  final String?  trend;

  const BirpurBadge({
    required this.level,
    required this.dangerLevel,
    required this.status,
    required this.source,
    required this.observedAt,
    required this.isStale,
    this.dischargeCumecs,
    this.trend,
  });

  double get gap          => dangerLevel - level;
  double get fillFraction => (level / dangerLevel).clamp(0.0, 1.1);
}

final birpurBadgeProvider =
    Provider.autoDispose<AsyncValue<BirpurBadge?>>((ref) {
  return ref.watch(kosiBirpurProvider).whenData((r) {
    if (r == null) return null; // v2.1: no seed badge
    return BirpurBadge(
      level:           r.levelM,
      dangerLevel:     r.dangerLevel,
      status:          r.statusLabel,
      source:          r.source,
      observedAt:      r.observedAt,
      isStale:         DateTime.now().difference(r.observedAt).inHours >= 2,
      dischargeCumecs: r.dischargeCumecs,
      trend:           r.trend,
    );
  });
});
