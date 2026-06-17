// lib/providers/bihar_live_provider.dart  (v3.5)
//
// OpsFlood — All-Stations Live Provider
//
// v3.5 (15 Jun 2026) — Fix city-card blank data (city lookup mismatch).
//   _index was keyed by s.city.trim().toLowerCase() which kept parenthetical
//   qualifiers like "(CWC)", "(D/S)", "(U/S)" intact.
//   byCity() also did a plain lowercase lookup.
//   Result: live.byCity("Birpur") never matched "birpur (cwc)" → every card
//   showed grey NO DATA even though the feed had live readings.
//
//   Fix: both _index key construction and byCity() input now go through
//   _normCityKey(), which strips (...) qualifiers and normalises whitespace.
//   This is the same normalisation already used by _buildState dedup (Step 2)
//   and by BiharLiveEngine._gaugeKeys(), so all three pipelines now agree.
//
// v3.4 (15 Jun 2026) — Deduplicate stations by city key inside _buildState.
// v3.3 (12 Jun 2026) — Three city-card load-time fixes.
// v3.2: removed dead StationsUnifiedBridge / LiveFetchEngine attach().
// v3.1: single-engine BiharLiveEngine wiring.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/bihar_station_metadata.dart';

import '../services/bihar_live_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BiharStationData
// ─────────────────────────────────────────────────────────────────────────────
class BiharStationData {
  final String  id;
  final String  city;
  final String  river;
  final String  district;
  final String  state;
  final double? currentLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final double? diff24h;
  final double? forecast24h;
  final String  trend;        // '↑' / '↓' / '→'
  final String  riskLabel;    // CRITICAL / SEVERE / HIGH / MODERATE / LOW / NORMAL
  final String  source;       // LIVE / STATIC
  final String  fetchedAt;    // ISO-8601 string

  final double? discharge;
  final double? dischargeMean;
  final double? rainfall24h;

  const BiharStationData({
    required this.id,
    required this.city,
    required this.river,
    required this.district,
    required this.state,
    this.currentLevel,
    this.dangerLevel,
    this.warningLevel,
    this.diff24h,
    this.forecast24h,
    required this.trend,
    required this.riskLabel,
    required this.source,
    required this.fetchedAt,
    this.discharge,
    this.dischargeMean,
    this.rainfall24h,
  });

  // ── Factory: BiharFeedItem → BiharStationData ─────────────────────────────
  factory BiharStationData.fromFeedItem(BiharFeedItem item) {
    final rawLevel  = item.raw['level'];
    final curDouble = rawLevel != null
        ? _safeLevel(rawLevel)
        : _parseLevelString(item.value);

    final dan = _safeThreshold(item.raw['danger'],  fallback: 99.0);
    final war = _safeThreshold(item.raw['warning'], fallback: dan * 0.85);

    double? diff;
    if (item.changeStr != null) {
      final numStr = item.changeStr!.replaceAll(RegExp(r'[^0-9.+-]'), '');
      diff = _safeLevel(double.tryParse(numStr));
    }

    String trend = '→';
    if (item.changeStr != null) {
      if (item.changeStr!.contains('↑')) trend = '↑';
      if (item.changeStr!.contains('↓')) trend = '↓';
    } else if (curDouble != null && war > 0) {
      if (curDouble > war)       trend = '↑';
      if (curDouble < war * 0.9) trend = '↓';
    }

    final risk = _normaliseRisk((item.dangerLevel ?? '').trim().toUpperCase());

    String river = '';
    if (item.raw['river'] is String) {
      river = (item.raw['river'] as String).trim();
    }
    if (river.isEmpty && item.subtitle.startsWith('River: ')) {
      river = item.subtitle.substring('River: '.length).trim();
    }

    final _rawDistrict = (item.raw['district'] as String?)?.trim() ?? '';
    final district = _rawDistrict.isNotEmpty
        ? _rawDistrict
        : (BiharStationRegistry.forSite(item.title) ??
               BiharStationRegistry.forSite(
                   item.title.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim()))
              ?.district ?? '';
    final state    = (item.raw['state'] as String?)?.trim().isNotEmpty == true
        ? (item.raw['state'] as String).trim()
        : 'Bihar';

    return BiharStationData(
      id:            item.id,
      city:          item.title,
      river:         river,
      district:      district,
      state:         state,
      currentLevel:  curDouble,
      dangerLevel:   dan,
      warningLevel:  war,
      diff24h:       diff,
      forecast24h:   null,
      trend:         trend,
      riskLabel:     risk,
      source:        'LIVE',
      fetchedAt:     item.fetchedAt.toIso8601String(),
      discharge:     null,
      dischargeMean: null,
      rainfall24h:   _safeLevel(item.raw['rainfall']),
    );
  }

  // ── Gauge helpers ─────────────────────────────────────────────────────────
  double get dangerPercent {
    final cur = currentLevel;
    final dan = dangerLevel;
    if (cur == null || dan == null || dan <= 0) return 0;
    return ((cur / dan) * 100).clamp(0, 150).toDouble();
  }

  bool get isCritical => riskLabel == 'CRITICAL';
  bool get isSevere   => riskLabel == 'SEVERE';
  bool get isWarning  =>
      riskLabel == 'HIGH' || riskLabel == 'WARNING' || riskLabel == 'MODERATE';
  bool get isSafe     => riskLabel == 'LOW' || riskLabel == 'NORMAL';
  bool get hasNoData  => riskLabel == 'UNKNOWN' || source == 'STATIC';

  // ── Private safe-parse helpers ────────────────────────────────────────────
  static double? _parseLevelString(String? s) {
    if (s == null || s.isEmpty || s == '—') return null;
    final numStr = RegExp(r'[-+]?\d+\.?\d*').firstMatch(s)?.group(0);
    return _safeLevel(double.tryParse(numStr ?? ''));
  }

  static double? _safeLevel(dynamic v) {
    if (v == null) return null;
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else {
      d = double.tryParse(v.toString());
    }
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d.clamp(0.0, double.maxFinite);
  }

  static double _safeThreshold(dynamic v, {required double fallback}) {
    final d = _safeLevel(v);
    if (d == null || d <= 0) return fallback;
    return d;
  }

  static String _normaliseRisk(String raw) {
    if (raw.contains('DANGER')   || raw.contains('BREACH')   ||
        raw.contains('EXTREME')  || raw.contains('CRITICAL'))
      return 'CRITICAL';
    if (raw.contains('SEVERE')   || raw.contains('ABOVE_HFL') ||
        raw.contains('ABOVE DANGER'))
      return 'SEVERE';
    if (raw.contains('WARNING')  || raw.contains('HIGH')     ||
        raw.contains('ABOVE')    || raw.contains('MODERATE'))
      return 'HIGH';
    if (raw.contains('WATCH')    || raw.contains('CAUTION'))
      return 'MODERATE';
    if (raw == 'LOW' || raw == 'SAFE'   || raw == 'NORMAL' ||
        raw == 'PRE-MONSOON'            || raw == 'BELOW WARNING')
      return 'LOW';
    return 'NORMAL';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BiharLiveState  (v3.5 — _index and byCity both use _normCityKey)
// ─────────────────────────────────────────────────────────────────────────────
class BiharLiveState {
  final List<BiharStationData>        stations;
  final DateTime?                      lastFetched;
  // v3.5: keyed by _normCityKey(s.city) so "(CWC)", "(D/S)" etc. are stripped.
  final Map<String, BiharStationData> _index;

  BiharLiveState({this.stations = const [], this.lastFetched})
      : _index = {
          for (final s in stations)
            _normCityKey(s.city): s,
        };

  /// O(1) lookup by city name — normalised so "Birpur" matches "Birpur (CWC)".
  BiharStationData? byCity(String city) =>
      _index[_normCityKey(city)];

  int get criticalCount => stations.where((s) => s.isCritical).length;
  int get severeCount   => stations.where((s) => s.isSevere).length;
  int get warningCount  => stations.where((s) => s.isWarning).length;
  int get safeCount     => stations.where((s) => s.isSafe).length;
  int get noDataCount   => stations.where((s) => s.hasNoData).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk order used for dedup and sort.
// ─────────────────────────────────────────────────────────────────────────────
const _kRiskOrder = {
  'CRITICAL': 0,
  'SEVERE':   1,
  'HIGH':     2,
  'MODERATE': 3,
  'LOW':      4,
  'NORMAL':   5,
  'UNKNOWN':  6,
};

// ─────────────────────────────────────────────────────────────────────────────
// City-key normalisation — shared by _buildState dedup, _index construction,
// and byCity() so all three pipelines agree on the canonical city key.
// ─────────────────────────────────────────────────────────────────────────────
String _normCityKey(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')   // strip qualifiers like "(U/S)"
    .replaceAll(RegExp(r'[^a-z0-9\s]'),  ' ')
    .replaceAll(RegExp(r' +'),            ' ')
    .trim();

// ─────────────────────────────────────────────────────────────────────────────
// Notifier  (v3.5 — no logic change; only BiharLiveState construction changed)
// ─────────────────────────────────────────────────────────────────────────────

class BiharLiveNotifier extends AsyncNotifier<BiharLiveState> {
  StreamSubscription<BiharLiveFeed>? _sub;

  @override
  Future<BiharLiveState> build() async {
    final engine = BiharLiveEngine.instance;

    // Start engine if not already running (idempotent).
    if (!engine.running) engine.start();

    // Cancel any previous subscription (hot-reload safety).
    _sub?.cancel();
    _sub = engine.stream.listen(_onFeed);
    ref.onDispose(() => _sub?.cancel());

    // Fix 1 (v3.3): Fast path — engine already has data (e.g. after hot-reload).
    if (engine.latest != null) return _buildState(engine.latest);

    // Fix 1 (v3.3): Slow path — suspend build() so provider stays AsyncLoading.
    final completer = Completer<BiharLiveState>();
    late StreamSubscription<BiharLiveFeed> onceSub;
    onceSub = engine.stream.listen((feed) {
      if (!completer.isCompleted) {
        completer.complete(_buildState(feed));
      }
      onceSub.cancel();
    });
    return completer.future;
  }

  void _onFeed(BiharLiveFeed feed) {
    state = AsyncData(_buildState(feed));
  }

  BiharLiveState _buildState(BiharLiveFeed? feed) {
    if (feed == null || feed.items.isEmpty) {
      return BiharLiveState(lastFetched: feed?.generatedAt);
    }

    // Step 1 — parse raw feed items into BiharStationData objects.
    final rawStations = feed.items
        .where((i) =>
            i.kind == FeedItemKind.riverGauge ||
            i.kind == FeedItemKind.barrage    ||
            i.kind == FeedItemKind.telemetry)
        .map(BiharStationData.fromFeedItem)
        .toList();

    // Step 2 — deduplicate by normalised city key.
    // The raw WRD/CWC feed can emit multiple gauge records for the same city
    // (e.g. Birpur appears 3× on the Kosi at different cross-sections).
    // Keep the entry with the highest risk; on tie, keep the highest level.
    final deduped = <String, BiharStationData>{};
    for (final s in rawStations) {
      final key = s.id.isNotEmpty ? s.id : _normCityKey(s.city);
      if (!deduped.containsKey(key)) {
        deduped[key] = s;
      } else {
        final existing     = deduped[key]!;
        final incomingRank = _kRiskOrder[s.riskLabel]        ?? 6;
        final existingRank = _kRiskOrder[existing.riskLabel] ?? 6;
        if (incomingRank < existingRank) {
          // Incoming is higher risk — replace.
          deduped[key] = s;
        } else if (incomingRank == existingRank) {
          // Same risk — keep the higher observed level.
          final incomingLevel = s.currentLevel        ?? 0;
          final existingLevel = existing.currentLevel ?? 0;
          if (incomingLevel > existingLevel) deduped[key] = s;
        }
        // else: existing is higher risk — keep it.
      }
    }

    // Step 3 — sort by risk (most critical first).
    final stations = deduped.values.toList()
      ..sort((a, b) =>
          (_kRiskOrder[a.riskLabel] ?? 5)
              .compareTo(_kRiskOrder[b.riskLabel] ?? 5));

    return BiharLiveState(
      stations:    stations,
      lastFetched: feed.generatedAt,
    );
  }

  /// Force an immediate full refresh (e.g. user taps Refresh button).
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      await BiharLiveEngine.instance.refresh();
      // _onFeed() fires automatically from the stream.
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
final biharLiveProvider =
    AsyncNotifierProvider<BiharLiveNotifier, BiharLiveState>(
  BiharLiveNotifier.new,
);
