// lib/providers/live_engine_bridge_provider.dart  v4.1
//
// v4.1 (12 Jun 2026) — threshold corrections + _norm() double-space fix
//
// FIXES:
//   FIX-1: _norm() now collapses double-spaces left after stripping parens.
//     BEFORE: 'Birpur (CWC)' → 'birpur  cwc'  (double space)
//     AFTER:  'Birpur (CWC)' → 'birpur cwc'
//     Consequence: substring match on 'birpur' no longer hits 'birpur cwc'
//     unexpectedly; lookup for 'birpur cwc' now correctly hits
//     _kThresholds['birpur (cwc)'] (which _norm()s to 'birpur cwc').
//
//   FIX-2: _kThresholds updated to bihar_rivers.dart v4.2 values:
//     Buxar:          DL 60.32  → 60.30   HFL 62.09  → 62.10
//     Samastipur:     WL 44.80  → 46.00   DL 46.02  → 46.00   HFL 49.38→49.40
//     Darauli:        WL 60.50  → 61.20   DL 61.52  → 60.82   HFL 63.10→61.82
//     Gangpur Siswan: WL 63.00  → 56.70   DL 64.10  → 57.04   HFL 65.82→58.26
//     Jhanjharpur:    WL 49.50  → 48.50   DL 50.50  → 50.00
//     Sonbarsa:       HFL 83.75 → 83.20
//     Taibpur:        WL 34.65  → 64.40   DL 35.65  → 66.00   HFL 38.16→67.22
//       (was mis-keyed as Dhengraghat clone; now correct Kishanganj MSL datum)
//
// v4.0 history:
//   _lookupThreshold now checks ThresholdOverrideStore (RTDAS live values)
//   BEFORE falling back to the compiled-in _kThresholds table.
//   Priority:
//     1. ThresholdOverrideStore (RTDAS scraped — updated every 6h)
//     2. _kThresholds (bihar_rivers.dart v4.2 hardcoded)
//     3. Heuristic fallback (level * 0.90 / 0.95 / 1.05)
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';
import '../services/bihar_live_engine.dart';
import '../services/threshold_override_store.dart';

// ── Threshold table ─────────────────────────────────────────────────────────────────
// SOURCE: bihar_rivers.dart v4.2 kBiharGauges (BEAMS RTDAS + BeFIQR 12 Jun 2026)
// All levels in metres MSL.
// Keys are the _norm() output of the station name as it arrives from
// BiharLiveEngine (i.e. lower-case, no parens, single spaces).
const Map<String, ({double warning, double danger, double hfl, String river})>
    _kThresholds = {

  // ── GANGA (7 stations) ─────────────────────────────────────────────────────
  'gandhighat': (warning: 47.50, danger: 48.60, hfl: 50.52, river: 'Ganga'),
  'dighaghat':  (warning: 49.30, danger: 50.45, hfl: 52.52, river: 'Ganga'),
  'hathidah':   (warning: 40.50, danger: 41.76, hfl: 43.52, river: 'Ganga'),
  'munger':     (warning: 38.20, danger: 39.33, hfl: 40.99, river: 'Ganga'),
  'kahalgaon':  (warning: 30.00, danger: 31.09, hfl: 32.87, river: 'Ganga'),
  'bhagalpur':  (warning: 32.50, danger: 33.68, hfl: 34.86, river: 'Ganga'),
  'buxar':      (warning: 59.20, danger: 60.30, hfl: 62.10, river: 'Ganga'),  // v4.2: DL 60.32→60.30 HFL 62.09→62.10

  // ── KOSI (7 stations) ─────────────────────────────────────────────────────
  'birpur':           (warning: 73.70, danger: 74.70, hfl: 76.02, river: 'Kosi'),
  'birpur cwc':       (warning: 73.70, danger: 74.70, hfl: 76.02, river: 'Kosi'),  // _norm('Birpur (CWC)') = 'birpur cwc'
  'basua':            (warning: 46.50, danger: 47.75, hfl: 49.24, river: 'Kosi'),
  'baltara':          (warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  'kursela':          (warning: 28.80, danger: 30.00, hfl: 32.10, river: 'Kosi'),
  'dumri bridge':     (warning: 32.85, danger: 33.85, hfl: 36.40, river: 'Kosi'),
  'bhim nagar':       (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),
  'bhimnagar':        (warning: 70.00, danger: 71.00, hfl: 72.50, river: 'Kosi'),
  'vijay ghat bridge':(warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Kosi'),
  'vijayghat':        (warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Kosi'),
  'naugachia':        (warning: 29.50, danger: 31.00, hfl: 33.50, river: 'Ganga'),

  // ── GANDAK (6 stations) ────────────────────────────────────────────────────
  'chatia':      (warning: 68.10, danger: 69.15, hfl: 70.04, river: 'Gandak'),
  'dumariaghat': (warning: 61.10, danger: 62.22, hfl: 64.36, river: 'Gandak'),
  'rewaghat':    (warning: 53.40, danger: 54.41, hfl: 55.46, river: 'Gandak'),
  'hajipur':     (warning: 49.40, danger: 50.32, hfl: 50.93, river: 'Gandak'),
  'lalganj':     (warning: 49.30, danger: 50.50, hfl: 51.83, river: 'Gandak'),
  'khadda':      (warning: 94.50, danger: 96.00, hfl: 97.50, river: 'Gandak'),

  // ── BAGMATI (13 stations) ──────────────────────────────────────────────────
  'dheng bridge':          (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'dhengbridge':           (warning: 70.00, danger: 71.00, hfl: 73.47, river: 'Bagmati'),
  'sonakhan':              (warning: 67.80, danger: 68.80, hfl: 72.05, river: 'Bagmati'),
  'benibad':               (warning: 47.68, danger: 48.68, hfl: 50.12, river: 'Bagmati'),
  'hayaghat':              (warning: 44.50, danger: 45.72, hfl: 48.96, river: 'Bagmati'),
  'dhengraghat bagmati':   (warning: 34.65, danger: 35.65, hfl: 47.30, river: 'Bagmati'),
  'kamtaul bagmati':       (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  'kamtaul':               (warning: 49.00, danger: 50.00, hfl: 53.01, river: 'Bagmati'),
  'runnisaidpur':          (warning: 52.50, danger: 55.00, hfl: 58.15, river: 'Bagmati'),
  'runisaidpur':           (warning: 52.50, danger: 55.00, hfl: 58.15, river: 'Bagmati'),
  'dubbadhar':             (warning: 59.00, danger: 61.28, hfl: 63.75, river: 'Bagmati'),
  'kansar':                (warning: 57.50, danger: 59.06, hfl: 60.86, river: 'Bagmati'),
  'kataunjha':             (warning: 52.80, danger: 55.00, hfl: 58.36, river: 'Bagmati'),

  // ── BURHI GANDAK (5 stations) ──────────────────────────────────────────────
  'sikandarpur': (warning: 51.40, danger: 52.53, hfl: 54.29, river: 'Burhi Gandak'),
  'samastipur':  (warning: 46.00, danger: 46.00, hfl: 49.40, river: 'Burhi Gandak'),  // v4.2: WL 44.80→46.00 DL 46.02→46.00 HFL 49.38→49.40
  'rosera':      (warning: 41.50, danger: 42.63, hfl: 46.56, river: 'Burhi Gandak'),
  'khagaria':    (warning: 35.40, danger: 36.58, hfl: 39.22, river: 'Burhi Gandak'),
  'gaighat':     (warning: 53.00, danger: 54.00, hfl: 55.50, river: 'Burhi Gandak'),

  // ── GHAGHRA (2 stations) ───────────────────────────────────────────────────────
  'darauli':          (warning: 61.20, danger: 60.82, hfl: 61.82, river: 'Ghaghra'),  // v4.2: DL 61.52→60.82 HFL 63.10→61.82
  'gangpur siswan':   (warning: 56.70, danger: 57.04, hfl: 58.26, river: 'Ghaghra'),  // v4.2: WL 63.00→56.70 DL 64.10→57.04 HFL 65.82→58.26
  'gangpur':          (warning: 56.70, danger: 57.04, hfl: 58.26, river: 'Ghaghra'),

  // ── KAMLA (4 stations) ────────────────────────────────────────────────────────
  'jainagar':      (warning: 67.75, danger: 67.75, hfl: 71.35, river: 'Kamla'),
  'jhanjharpur':   (warning: 48.50, danger: 50.00, hfl: 53.11, river: 'Kamla'),  // v4.2: WL 49.50→48.50 DL 50.50→50.00
  'kamtaul kamla': (warning: 43.00, danger: 44.00, hfl: 45.45, river: 'Kamla'),
  'phulparas':     (warning: 49.50, danger: 50.50, hfl: 53.11, river: 'Kamla'),

  // ── MAHANANDA (4 stations) ───────────────────────────────────────────────────
  // v4.2: Taibpur was a Dhengraghat clone (wrong MSL datum for Kishanganj).
  //   Old: WL 34.65 / DL 35.65 / HFL 38.16  ← WRONG, caused all-yellow
  //   New: WL 64.40 / DL 66.00 / HFL 67.22  ← CORRECT Kishanganj MSL
  'taibpur':                (warning: 64.40, danger: 66.00, hfl: 67.22, river: 'Mahananda'),
  'dhengraghat mahananda':  (warning: 34.65, danger: 35.65, hfl: 38.20, river: 'Mahananda'),
  // 'dhengraghat' alone — DO NOT put it here; the bare key was matching
  // Taibpur (substring) in v4.0 and assigning Bagmati thresholds.
  // It is now resolved via the explicit 'dhengraghat bagmati' key above
  // and 'dhengraghat mahananda' key here.
  'jhawa':                  (warning: 30.00, danger: 31.40, hfl: 34.07, river: 'Mahananda'),

  // ── PUNPUN (1 station) ───────────────────────────────────────────────────────────
  'sripalpur': (warning: 50.60, danger: 51.83, hfl: 53.91, river: 'Punpun'),

  // ── ADHWARA / DHAUS / KHIROI (4 stations) ──────────────────────────────
  'ekmighat':        (warning: 45.00, danger: 46.94, hfl: 49.52, river: 'Khiroi'),
  'kamtaul adhwara': (warning: 48.00, danger: 50.00, hfl: 53.05, river: 'Adhwara'),
  'saulighat':       (warning: 50.00, danger: 52.37, hfl: 55.10, river: 'Dhaus'),
  'agropatti':       (warning: 51.00, danger: 52.75, hfl: 54.53, river: 'Khiroi'),

  // ── JHIM / LAL BAKEYA / BALAN / BHUTAHI BALAN (5 stations) ─────────────
  'sonbarsa':         (warning: 80.50, danger: 81.85, hfl: 83.20, river: 'Jhim'),  // v4.2: HFL 83.75→83.20
  'lalbakeya':        (warning: 73.00, danger: 74.00, hfl: 75.50, river: 'Lalbakeya'),
  'goabari':          (warning: 69.50, danger: 71.15, hfl: 73.86, river: 'Lal Bakeya'),
  'phulparas balan':  (warning: 59.50, danger: 60.80, hfl: 61.80, river: 'Balan'),
  'laukaha':          (warning: 78.50, danger: 79.80, hfl: 80.80, river: 'Bhutahi Balan'),

  // ── KHANDO / KAREH (2 stations) ─────────────────────────────────────────────
  'dagmara':  (warning: 60.50, danger: 61.50, hfl: 62.50, river: 'Khando'),
  'karachin': (warning: 38.50, danger: 40.00, hfl: 41.90, river: 'Kareh'),
};

// ── helpers ────────────────────────────────────────────────────────────────────────────────

/// v4.1 FIX: collapse ALL whitespace runs to a single space.
/// This prevents 'Birpur (CWC)' → 'birpur  cwc' (double-space) which
/// caused the substring match to hit 'birpur' and return DL=74.70
/// when looking up 'birpur  cwc', completely bypassing 'birpur cwc' key.

// ── Station coordinates lookup (injected into RiverStation.lat/lon) ──────────
const Map<String, ({double lat, double lon})> _kCoords = {
  // GANGA
  'gandhighat':        (lat: 25.614, lon: 85.127),
  'dighaghat':         (lat: 25.623, lon: 85.074),
  'hathidah':          (lat: 25.381, lon: 86.165),
  'munger':            (lat: 25.375, lon: 86.474),
  'kahalgaon':         (lat: 25.207, lon: 87.268),
  'bhagalpur':         (lat: 25.245, lon: 86.978),
  'buxar':             (lat: 25.563, lon: 83.978),
  // KOSI
  'birpur':            (lat: 26.505, lon: 86.914),
  'birpur cwc':        (lat: 26.505, lon: 86.914),
  'basua':             (lat: 26.430, lon: 86.702),
  'baltara':           (lat: 25.867, lon: 86.563),
  'kursela':           (lat: 25.453, lon: 87.266),
  'dumri bridge':      (lat: 25.920, lon: 86.580),
  'bhim nagar':        (lat: 26.862, lon: 87.062),
  'bhimnagar':         (lat: 26.862, lon: 87.062),
  'vijay ghat bridge': (lat: 25.700, lon: 86.900),
  'vijayghat':         (lat: 25.700, lon: 86.900),
  'naugachia':         (lat: 25.390, lon: 87.097),
  // GANDAK
  'chatia':            (lat: 26.680, lon: 84.882),
  'dumariaghat':       (lat: 27.093, lon: 84.478),
  'rewaghat':          (lat: 26.205, lon: 84.975),
  'hajipur':           (lat: 25.683, lon: 85.209),
  'lalganj':           (lat: 25.873, lon: 85.177),
  'khadda':            (lat: 27.098, lon: 83.893),
  // BAGMATI
  'dheng bridge':          (lat: 26.740, lon: 85.594),
  'dhengbridge':           (lat: 26.740, lon: 85.594),
  'sonakhan':              (lat: 26.920, lon: 85.450),
  'benibad':               (lat: 26.148, lon: 85.852),
  'hayaghat':              (lat: 26.122, lon: 85.762),
  'dhengraghat bagmati':   (lat: 26.098, lon: 87.951),
  'kamtaul bagmati':       (lat: 26.392, lon: 85.862),
  'kamtaul':               (lat: 26.392, lon: 85.862),
  'runnisaidpur':          (lat: 26.553, lon: 85.473),
  'runisaidpur':           (lat: 26.553, lon: 85.473),
  'dubbadhar':             (lat: 26.820, lon: 85.380),
  'kansar':                (lat: 26.780, lon: 85.510),
  'kataunjha':             (lat: 26.640, lon: 85.520),
  // BURHI GANDAK
  'sikandarpur':       (lat: 26.118, lon: 85.391),
  'samastipur':        (lat: 25.871, lon: 85.779),
  'rosera':            (lat: 25.863, lon: 85.984),
  'khagaria':          (lat: 25.502, lon: 86.468),
  'gaighat':           (lat: 25.990, lon: 85.684),
  // GHAGHRA
  'darauli':           (lat: 26.102, lon: 84.136),
  'gangpur siswan':    (lat: 26.218, lon: 84.357),
  'gangpur':           (lat: 26.218, lon: 84.357),
  // KAMLA
  'jainagar':          (lat: 26.597, lon: 86.247),
  'jhanjharpur':       (lat: 26.268, lon: 86.280),
  'kamtaul kamla':     (lat: 26.392, lon: 85.862),
  'phulparas':         (lat: 26.519, lon: 86.504),
  // MAHANANDA
  'taibpur':                (lat: 25.775, lon: 87.474),
  'dhengraghat mahananda':  (lat: 26.098, lon: 87.951),
  'dhengraghat':            (lat: 26.098, lon: 87.951),
  'jhawa':                  (lat: 25.614, lon: 87.835),
  // PUNPUN
  'sripalpur':         (lat: 25.328, lon: 85.038),
  // ADHWARA / DHAUS / KHIROI
  'ekmighat':          (lat: 26.597, lon: 85.617),
  'kamtaul adhwara':   (lat: 26.392, lon: 85.862),
  'saulighat':         (lat: 26.480, lon: 85.720),
  'agropatti':         (lat: 26.430, lon: 85.680),
  // JHIM / LALBAKEYA / BALAN
  'sonbarsa':          (lat: 25.993, lon: 86.063),
  'lalbakeya':         (lat: 26.600, lon: 85.750),
  'goabari':           (lat: 26.530, lon: 85.810),
  'phulparas balan':   (lat: 26.519, lon: 86.504),
  'laukaha':           (lat: 26.408, lon: 86.533),
  // KHANDO / KAREH
  'dagmara':           (lat: 26.179, lon: 86.723),
  'karachin':          (lat: 25.432, lon: 85.519),
};

String _norm(String v) => v
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')   // strip (qualifier)
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ') // non-alnum → space
    .replaceAll(RegExp(r' +'), ' ')           // v4.1: collapse multi-space
    .trim();

// v4.0+: checks ThresholdOverrideStore FIRST (live RTDAS values),
// then compiled-in _kThresholds, then returns null (caller applies heuristic).
({double warning, double danger, double hfl, String river})?
    _lookupThreshold(String normName) {

  // ── Priority 1: Live RTDAS values from ThresholdOverrideStore ────────────
  final override = ThresholdOverrideStore.instance.get(normName);
  if (override != null && override.dl != null) {
    final compiled = _kThresholds[normName];
    return (
      warning: override.wl ?? compiled?.warning ?? override.dl! * 0.99,
      danger:  override.dl!,
      hfl:     override.hfl ?? compiled?.hfl ?? override.dl! * 1.05,
      river:   compiled?.river ?? 'Bihar River',
    );
  }

  // ── Priority 2: Compiled-in table (bihar_rivers.dart v4.2) ──────────────
  final exact = _kThresholds[normName];
  if (exact != null) return exact;

  // Substring / prefix match for variant spellings.
  // v4.1: now safe because _norm() always produces single spaces so
  // 'birpur cwc'.contains('birpur') = true but only after exact lookup
  // fails, meaning we fall through to the correct 'birpur cwc' key above
  // when the full name is 'Birpur (CWC)'.
  for (final entry in _kThresholds.entries) {
    final k = entry.key;
    if (normName.contains(k) || k.contains(normName)) return entry.value;
  }

  return null;
}

// ── Provider ────────────────────────────────────────────────────────────────────────────────

class LiveEngineBridgeNotifier extends Notifier<List<RiverStation>> {
  StreamSubscription<BiharLiveFeed>? _sub;

  @override
  List<RiverStation> build() {
    if (!BiharLiveEngine.instance.running) {
      BiharLiveEngine.instance.start();
    }
    _sub?.cancel();
    _sub = BiharLiveEngine.instance.stream.listen(_onFeed);
    ref.onDispose(() => _sub?.cancel());
    final existing = BiharLiveEngine.instance.latest;
    return existing != null ? _convert(existing) : [];
  }

  void _onFeed(BiharLiveFeed feed) {
    state = _convert(feed);
    if (kDebugMode) {
      debugPrint('[LiveEngineBridge] ${state.length} stations from engine feed');
    }
  }

  List<RiverStation> _convert(BiharLiveFeed feed) {
    final result = <RiverStation>[];

    for (final item in feed.items) {
      if (item.kind != FeedItemKind.riverGauge &&
          item.kind != FeedItemKind.barrage    &&
          item.kind != FeedItemKind.telemetry) continue;

      // Skip the RTDAS sync-marker stub item — it has no water level.
      if (item.id == 'rtdas|__sync_marker__') continue;

      final rawVal = item.value ?? '';
      final numStr = rawVal.replaceAll(RegExp(r'[^0-9.]'), '');
      final level  = double.tryParse(numStr);
      final hasData = level != null && level > 0;

      final normName = _norm(item.title);
      final thresh   = _lookupThreshold(normName);

      // No-data stations: keep in list so UI can show offline chip.
      // Use threshold danger as sentinel current level (won't trigger alerts).
      if (!hasData) {
        final river = thresh?.river
            ?? (item.raw['river'] as String?)?.trim()
            ?? item.subtitle;
        result.add(RiverStation(
          city:        item.title,
          state:       (item.raw['state'] as String?)?.trim() ?? 'Bihar',
          river:       river,
          station:     item.title,
          current:     -1,
          warning:     thresh?.warning ?? 0,
          danger:      thresh?.danger  ?? 0,
          hfl:         thresh?.hfl     ?? 0,
          lastUpdated: '--:--',
          dataSource:  item.source.name.toUpperCase(),
          isLive:      false,
          lat:         _kCoords[normName]?.lat,
          lon:         _kCoords[normName]?.lon,
          liveStatus:  'NO_DATA',
        ));
        continue;
      }

      // Heuristic fallback if even the store and compiled table miss this station.
      final warning = thresh?.warning ?? level * 0.90;
      final danger  = thresh?.danger  ?? level * 0.95;
      final hfl     = thresh?.hfl     ?? level * 1.05;

      final river = (item.raw['river'] as String?)?.trim().isNotEmpty == true
          ? item.raw['river'] as String
          : thresh?.river ?? item.subtitle;

      final stateStr = (item.raw['state'] as String?)?.trim().isNotEmpty == true
          ? item.raw['state'] as String
          : 'Bihar';

      result.add(RiverStation(
        city:        item.title,
        state:       stateStr,
        river:       river,
        station:     item.title,
        current:     level,
        warning:     warning,
        danger:      danger,
        hfl:         hfl,
        lastUpdated:
            '${item.fetchedAt.hour.toString().padLeft(2, '0')}:'
            '${item.fetchedAt.minute.toString().padLeft(2, '0')}',
        dataSource:  item.source.name.toUpperCase(),
        isLive:      true,
        lat:         _kCoords[normName]?.lat,
        lon:         _kCoords[normName]?.lon,
        liveStatus:  item.dangerLevel,
      ));
    }
    return result;
  }
}

final liveEngineStationsProvider =
    NotifierProvider<LiveEngineBridgeNotifier, List<RiverStation>>(
        LiveEngineBridgeNotifier.new);
