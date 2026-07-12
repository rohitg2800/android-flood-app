// lib/services/station_history_store.dart
// OpsFlood — StationHistoryStore
//
// Persists the last known LIVE reading for every WRD Bihar station.
// When a new fetch returns NA for a station, the store injects the
// last good snapshot so the UI always has something to show.
//
// Storage: in-memory (session) + SharedPreferences for cross-launch persistence.
// Key format: "wrd_hist_{site_key}" → JSON encoded _HistEntry
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wrd_bihar_service.dart';

class HistoricalReading {
  final double level;
  final double? dangerLevel;
  final double? warningLevel;
  final double? hfl;
  final double? diff24h;
  final String? trend;
  final DateTime recordedAt;
  final String source; // always 'WRD_BIHAR'

  const HistoricalReading({
    required this.level,
    this.dangerLevel,
    this.warningLevel,
    this.hfl,
    this.diff24h,
    this.trend,
    required this.recordedAt,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'level': level,
        'dangerLevel': dangerLevel,
        'warningLevel': warningLevel,
        'hfl': hfl,
        'diff24h': diff24h,
        'trend': trend,
        'recordedAt': recordedAt.toIso8601String(),
        'source': source,
      };

  factory HistoricalReading.fromJson(Map<String, dynamic> j) =>
      HistoricalReading(
        level: (j['level'] as num).toDouble(),
        dangerLevel: (j['dangerLevel'] as num?)?.toDouble(),
        warningLevel: (j['warningLevel'] as num?)?.toDouble(),
        hfl: (j['hfl'] as num?)?.toDouble(),
        diff24h: (j['diff24h'] as num?)?.toDouble(),
        trend: j['trend'] as String?,
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        source: j['source'] as String? ?? 'WRD_BIHAR',
      );

  /// Human-readable staleness string.
  String get agoLabel {
    final d = DateTime.now().difference(recordedAt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class StationHistoryStore {
  StationHistoryStore._();
  static final StationHistoryStore instance = StationHistoryStore._();

  // In-memory map: site key → last good reading
  final Map<String, HistoricalReading> _cache = {};
  bool _loaded = false;

  static String _key(String site) =>
      'wrd_hist_${site.toLowerCase().replaceAll(' ', '_')}';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Load persisted readings from SharedPreferences (call once at startup).
  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('wrd_hist_'));
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        try {
          final r = HistoricalReading.fromJson(
              jsonDecode(raw) as Map<String, dynamic>);
          _cache[k] = r;
        } catch (_) {}
      }
      if (kDebugMode) {
        debugPrint('[HistStore] loaded ${_cache.length} historical readings');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HistStore] init error: $e');
    }
    _loaded = true;
  }

  /// Record a live reading for a station (called after every successful fetch).
  Future<void> record(WrdStation s) async {
    if (!s.hasLiveData) return;
    final reading = HistoricalReading(
      level: s.currentLevel!,
      dangerLevel: s.dangerLevel,
      warningLevel: s.warningLevel,
      hfl: s.hfl,
      diff24h: s.diff24h,
      trend: s.trend,
      recordedAt: s.fetchedAt,
      source: s.source,
    );
    final k = _key(s.site);
    _cache[k] = reading;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(k, jsonEncode(reading.toJson()));
    } catch (_) {}
  }

  /// Batch-record all live stations in a fetch result.
  HistoricalReading? get(String stationId) => _cache[_key(stationId)];

  Future<void> recordAll(List<WrdStation> stations) async {
    for (final s in stations) {
      await record(s);
    }
  }

  /// Get the last known reading for a station site name.
  /// Returns null if no historical data exists yet.
  HistoricalReading? getHistory(String site) => _cache[_key(site)];

  /// Merge: for every NA station, inject last known reading.
  /// Returns a new list where NA stations carry past data in
  /// the [WrdStationWithHistory] wrapper.
  List<WrdStationWithHistory> mergeWithHistory(List<WrdStation> fresh) {
    return fresh.map((s) {
      final hist = s.hasLiveData ? null : getHistory(s.site);
      return WrdStationWithHistory(station: s, history: hist);
    }).toList();
  }
}

// ── Extended model carrying optional past data ─────────────────────────────

class WrdStationWithHistory {
  final WrdStation station;
  final HistoricalReading? history;

  const WrdStationWithHistory({
    required this.station,
    required this.history,
  });

  /// True when current fetch returned live data.
  bool get isLive => station.hasLiveData;

  /// True when there is no live data but past data exists.
  bool get hasPastData => !isLive && history != null;

  /// True when there is neither live nor past data.
  bool get isBlind => !isLive && history == null;

  // ─ Display helpers (prefer live, fall back to past, then '—') ─

  String get displayLevel {
    if (isLive) return station.displayLevel;
    if (hasPastData) return '${history!.level.toStringAsFixed(2)} m';
    return 'NA';
  }

  String get displayDanger {
    final dl = station.dangerLevel ?? history?.dangerLevel;
    if (dl != null) return '${dl.toStringAsFixed(2)} m';
    return '—';
  }

  String get displayWarning {
    final wl = station.warningLevel ?? history?.warningLevel;
    if (wl != null) return '${wl.toStringAsFixed(2)} m';
    return '—';
  }

  String get displayHfl {
    final h = station.hfl ?? history?.hfl;
    if (h != null) return '${h.toStringAsFixed(2)} m';
    return '—';
  }

  String? get displayTrend => station.trend ?? history?.trend;

  String get displayDiff {
    final d = station.diff24h ?? (hasPastData ? history!.diff24h : null);
    if (d == null) return '—';
    final sign = d >= 0 ? '+' : '';
    return '$sign${d.toStringAsFixed(2)} m';
  }

  double? get effectivePct {
    final cur = station.currentLevel ?? history?.level;
    final dl = station.dangerLevel ?? history?.dangerLevel;
    if (cur == null || dl == null || dl <= 0) return null;
    return (cur / dl) * 100.0;
  }

  String get displayPct {
    final p = effectivePct;
    return p != null ? '${p.toStringAsFixed(0)}%' : '—';
  }

  String get riskLabel {
    if (isLive) return station.riskLabel;
    if (hasPastData) {
      final cur = history!.level;
      final dl = station.dangerLevel ?? history!.dangerLevel;
      if (dl == null || dl <= 0) return 'PAST';
      final bd = dl - cur;
      if (bd <= 0) return 'CRITICAL*';
      if (bd <= 1.0) return 'HIGH*';
      if (bd <= 2.5) return 'MODERATE*';
      return 'LOW*';
    }
    return station.riskLabel; // PRE-MONSOON / UNKNOWN
  }

  /// Staleness label for the badge.
  String get staleLabel => hasPastData ? history!.agoLabel : '';
}
