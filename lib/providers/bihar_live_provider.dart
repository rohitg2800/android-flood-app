// lib/providers/bihar_live_provider.dart  (v3.6)
//
// v3.6 (17 Jun 2026) — Dataflow audit fixes:
//
//   FIX-1: _normaliseRisk() was collapsing 'DANGER' → 'CRITICAL'.
//     The WRD/CWC API sends 'DANGER' for above-warning-level stations.
//     That tier is now preserved as 'DANGER' (matches gaugeRiskFromLevels output).
//     Old behaviour: DANGER → CRITICAL (skipping severity tier entirely).
//     New behaviour:
//       CRITICAL / BREACH / EXTREME   → 'CRITICAL'
//       ABOVE_HFL / ABOVE DANGER      → 'EXTREME'
//       SEVERE                         → 'SEVERE'
//       DANGER / WARNING / ABOVE       → 'DANGER'
//       HIGH / MODERATE / CAUTION     → 'WARNING'
//       LOW / SAFE / NORMAL / PRE-MONSOON / BELOW WARNING → 'NORMAL'
//
//   FIX-2: _kRiskOrder was missing 'DANGER', 'WARNING', 'EXTREME' keys.
//     Both fell to ?? 5 (= NORMAL rank) during dedup sort, so a
//     DANGER-level station could be replaced by a safe reading.
//     All 6 severity labels now have explicit ranks:
//       EXTREME=0, CRITICAL=1, SEVERE=2, DANGER=3, WARNING=4, NORMAL=5, UNKNOWN=6
//
// v3.5 (15 Jun 2026): city-key normalisation fix.
// v3.4 (15 Jun 2026): dedup by city key.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/threshold_override_store.dart';
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
  final String  riskLabel;    // EXTREME / CRITICAL / SEVERE / DANGER / WARNING / NORMAL
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

    final rawDan = _safeThreshold(item.raw['danger'],  fallback: 99.0);
    final rawWar = _safeThreshold(item.raw['warning'], fallback: rawDan * 0.85);

    // Override with verified thresholds from ThresholdOverrideStore if available
    final normTitle = item.title.toLowerCase()
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
    final override = ThresholdOverrideStore.instance.get(normTitle);
    final dan = (override?.dl != null && override!.dl! > 0)
        ? override.dl!
        : rawDan;
    final war = (override?.wl != null && override!.wl! > 0)
        ? override.wl!
        : rawWar;

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

    final rawDistrict = (item.raw['district'] as String?)?.trim() ?? '';
    final district = rawDistrict.isNotEmpty
        ? rawDistrict
        : (BiharStationRegistry.forSite(item.title) ??
               BiharStationRegistry.forSite(
                   item.title.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim()))
              ?.district ?? '';
    final state = (item.raw['state'] as String?)?.trim().isNotEmpty == true
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

  bool get isCritical => riskLabel == 'CRITICAL' || riskLabel == 'EXTREME';
  bool get isSevere   => riskLabel == 'SEVERE';
  bool get isWarning  => riskLabel == 'DANGER'  || riskLabel == 'WARNING';
  bool get isSafe     => riskLabel == 'NORMAL';
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

  // FIX-1 (v3.6): DANGER tier preserved — was incorrectly collapsed to CRITICAL.
  // New 6-tier hierarchy matches gaugeRiskFromLevels() in bihar_rivers.dart:
  //   EXTREME  = above HFL
  //   CRITICAL = at/above danger level
  //   SEVERE   = severe (API label)
  //   DANGER   = above warning level (API sends 'DANGER' for this)
  //   WARNING  = near warning level
  //   NORMAL   = below warning level
  static String _normaliseRisk(String raw) {
    // Tier 0 — EXTREME (above HFL)
    if (raw.contains('ABOVE_HFL') || raw.contains('ABOVE HFL') ||
        raw.contains('EXTREME'))
      return 'EXTREME';
    // Tier 1 — CRITICAL (breach / at danger level)
    if (raw.contains('BREACH') || raw.contains('CRITICAL'))
      return 'CRITICAL';
    // Tier 2 — SEVERE
    if (raw.contains('SEVERE'))
      return 'SEVERE';
    // Tier 3 — DANGER (above warning level; API literal is 'DANGER')
    if (raw == 'DANGER' || raw.contains('ABOVE DANGER') ||
        raw.contains('ABOVE WARNING') || raw == 'ABOVE')
      return 'DANGER';
    // Tier 4 — WARNING (near warning / elevated)
    if (raw.contains('WARNING') || raw.contains('HIGH') ||
        raw.contains('MODERATE') || raw.contains('WATCH') ||
        raw.contains('CAUTION'))
      return 'WARNING';
    // Tier 5 — NORMAL
    if (raw == 'LOW'  || raw == 'SAFE'  || raw == 'NORMAL' ||
        raw == 'PRE-MONSOON'            || raw == 'BELOW WARNING' ||
        raw.isEmpty)
      return 'NORMAL';
    // Unknown API label — default to NORMAL (not UNKNOWN) so station stays visible
    return 'NORMAL';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BiharLiveState  (v3.5 — _index and byCity both use _normCityKey)
// ─────────────────────────────────────────────────────────────────────────────
class BiharLiveState {
  final List<BiharStationData>        stations;
  final DateTime?                      lastFetched;
  final Map<String, BiharStationData> _index;

  BiharLiveState({this.stations = const [], this.lastFetched})
      : _index = {
          for (final s in stations)
            _normCityKey(s.city): s,
        };

  BiharStationData? byCity(String city) =>
      _index[_normCityKey(city)];

  int get criticalCount => stations.where((s) => s.isCritical).length;
  int get severeCount   => stations.where((s) => s.isSevere).length;
  int get warningCount  => stations.where((s) => s.isWarning).length;
  int get safeCount     => stations.where((s) => s.isSafe).length;
  int get noDataCount   => stations.where((s) => s.hasNoData).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// FIX-2 (v3.6): _kRiskOrder now covers all 7 labels incl. EXTREME/DANGER/WARNING.
// Previously missing EXTREME/DANGER/WARNING fell to ?? 5 (= NORMAL rank)
// during dedup, so a safe reading could silently replace a danger-level station.
// ─────────────────────────────────────────────────────────────────────────────
const _kRiskOrder = {
  'EXTREME':  0,
  'CRITICAL': 1,
  'SEVERE':   2,
  'DANGER':   3,
  'WARNING':  4,
  'NORMAL':   5,
  'UNKNOWN':  6,
};

// ─────────────────────────────────────────────────────────────────────────────
// City-key normalisation
// ─────────────────────────────────────────────────────────────────────────────
String _normCityKey(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'),  ' ')
    .replaceAll(RegExp(r' +'),            ' ')
    .trim();

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────
class BiharLiveNotifier extends AsyncNotifier<BiharLiveState> {
  StreamSubscription<BiharLiveFeed>? _sub;

  @override
  Future<BiharLiveState> build() async {
    final engine = BiharLiveEngine.instance;
    if (!engine.running) engine.start();
    _sub?.cancel();
    _sub = engine.stream.listen(_onFeed);
    ref.onDispose(() => _sub?.cancel());
    if (engine.latest != null) return _buildState(engine.latest);
    final completer = Completer<BiharLiveState>();
    late StreamSubscription<BiharLiveFeed> onceSub;
    onceSub = engine.stream.listen((feed) {
      if (!completer.isCompleted) completer.complete(_buildState(feed));
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

    final rawStations = feed.items
        .where((i) =>
            i.kind == FeedItemKind.riverGauge ||
            i.kind == FeedItemKind.barrage    ||
            i.kind == FeedItemKind.telemetry)
        .map(BiharStationData.fromFeedItem)
        .toList();

    // Dedup by normalised city key — keep highest risk; tie → highest level.
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
          deduped[key] = s;
        } else if (incomingRank == existingRank) {
          final incomingLevel = s.currentLevel        ?? 0;
          final existingLevel = existing.currentLevel ?? 0;
          if (incomingLevel > existingLevel) deduped[key] = s;
        }
      }
    }

    final stations = deduped.values.toList()
      ..sort((a, b) =>
          (_kRiskOrder[a.riskLabel] ?? 5)
              .compareTo(_kRiskOrder[b.riskLabel] ?? 5));

    return BiharLiveState(
      stations:    stations,
      lastFetched: feed.generatedAt,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      await BiharLiveEngine.instance.refresh();
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
