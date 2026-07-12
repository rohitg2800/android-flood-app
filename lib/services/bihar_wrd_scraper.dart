// lib/services/bihar_wrd_scraper.dart
//
// OpsFlood — BiharWrdScraper (v1.0)
//
// Source: https://irrigation.befiqr.in/state/table/cwc-stations
// Bihar WRD Central Flood Control Cell — 103 CWC stations, updated every hour.
//
// HOW IT WORKS
// ─────────────
// One HTTP GET fetches the HTML table for ALL 103 Bihar stations.
// The table is parsed into a flat List<BiharStationReading>.
// A shared 10-minute cache means every Bihar city lookup hits the cache —
// only ONE network call is made per polling cycle regardless of how many
// Bihar cities are in the list.
//
// INTEGRATION
// ───────────
// • CwcDirectService calls BiharWrdScraper.instance.fetchForCity(city) as
//   its Source-3 (WRD Bihar), replacing the old JSON endpoint that returned
//   very little data.
// • StateDataPrefetcher.prefetchBihar() can be called when the user opens
//   the Bihar state screen — it warms the cache so all city cards load
//   instantly without individual HTTP calls.
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/india_cities.dart';
import 'cwc_direct_service.dart'; // for CwcReading

// ── Station reading model ─────────────────────────────────────────────────
class BiharStationReading {
  final String stationName;
  final String river;
  final String district;
  final double currentLevel; // m MSL
  final double dangerLevel; // m MSL
  final double hfl; // m MSL
  final double? yesterdayLevel;
  final double? diff; // current − yesterday
  final String trend; // Rising / Falling / Steady
  final DateTime observedAt;

  const BiharStationReading({
    required this.stationName,
    required this.river,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.hfl,
    this.yesterdayLevel,
    this.diff,
    required this.trend,
    required this.observedAt,
  });

  double get belowDanger => dangerLevel - currentLevel;

  String get status {
    if (currentLevel >= hfl) return 'ABOVE_HFL';
    if (currentLevel >= dangerLevel) return 'ABOVE_DANGER';
    if (belowDanger <= 0.5) return 'NEAR_DANGER';
    return 'NORMAL';
  }
}

// ── Scraper singleton ─────────────────────────────────────────────────────
class BiharWrdScraper {
  BiharWrdScraper._();
  static final BiharWrdScraper instance = BiharWrdScraper._();

  final http.Client _client = http.Client();

  static const _kUrl = 'https://irrigation.befiqr.in/state/table/cwc-stations';
  static const _kTimeout = Duration(seconds: 15);
  static const _kCacheTtl = Duration(minutes: 10);

  List<BiharStationReading> _cache = [];
  DateTime? _cacheAt;

  // ── Public: fetch all Bihar stations (cached) ────────────────────────
  Future<List<BiharStationReading>> fetchAll(
      {bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _kCacheTtl &&
        _cache.isNotEmpty) {
      return _cache;
    }
    try {
      final res = await _client.get(Uri.parse(_kUrl)).timeout(_kTimeout);
      if (res.statusCode != 200) return _cache; // return stale on error
      final rows = _parseHtmlTable(res.body);
      if (rows.isNotEmpty) {
        _cache = rows;
        _cacheAt = now;
        if (kDebugMode) {
          debugPrint('[BiharWRD] fetched ${rows.length} stations at $now');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BiharWRD] fetch error: $e');
    }
    return _cache;
  }

  // ── Public: match a single city ──────────────────────────────────────
  static double _amslOffset(String stationName) {
    const offsets = {
      'Birpur': 60.069,
      'Baltara': 47.24,
    };
    return offsets[stationName] ?? 0.0;
  }

  Future<CwcReading?> fetchForCity(IndiaCity city) async {
    if (!city.state.toLowerCase().contains('bihar')) return null;
    final all = await fetchAll();
    if (all.isEmpty) return null;

    final reading = _bestMatch(all, city);
    if (reading == null) return null;

    return CwcReading(
      level: reading.currentLevel - _amslOffset(reading.stationName),
      warning: city.warningLevel,
      danger: reading.dangerLevel > 0 ? reading.dangerLevel : city.dangerLevel,
      hfl: reading.hfl > 0 ? reading.hfl : null,
      source: 'WRD_BIHAR_LIVE',
      stationName: reading.stationName,
      fetchedAt: reading.observedAt,
    );
  }

  // ── HTML table parser ─────────────────────────────────────────────────
  // The BeFIQR table columns (1-indexed):
  // 1=SL  2=River  3=Station  4=HFL  5=DL  6=Yesterday  7=Current
  // 8=Diff(7-6)  9=Trend  10=Diff(7-5)  11=Date&Time  12=District
  List<BiharStationReading> _parseHtmlTable(String html) {
    final rows = <BiharStationReading>[];
    // Match <tr> blocks that contain <td> cells
    final rowRe =
        RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellRe = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>',
        dotAll: true, caseSensitive: false);
    final tagRe = RegExp(r'<[^>]+>');

    for (final rowMatch in rowRe.allMatches(html)) {
      final cells = cellRe
          .allMatches(rowMatch.group(1)!)
          .map((m) => m.group(1)!.replaceAll(tagRe, '').trim())
          .toList();

      // Need at least 11 columns; skip header rows
      if (cells.length < 11) continue;
      final slText = cells[0];
      if (int.tryParse(slText) == null) continue; // skip header

      final river = cells[1];
      final station = cells[2];
      final hfl = double.tryParse(cells[3]) ?? 0.0;
      final dl = double.tryParse(cells[4]) ?? 0.0;
      final yest = double.tryParse(cells[5]);
      final curr = double.tryParse(cells[6]);
      final diff = double.tryParse(cells[7]);
      final trend = _inferTrend(diff);
      final dateStr = cells[10];
      final district = cells.length > 11 ? cells[11] : '';

      if (curr == null || curr <= 0) continue;

      rows.add(BiharStationReading(
        stationName: station,
        river: river,
        district: district,
        currentLevel: curr,
        dangerLevel: dl,
        hfl: hfl,
        yesterdayLevel: yest,
        diff: diff,
        trend: trend,
        observedAt: _parseDate(dateStr),
      ));
    }
    return rows;
  }

  // ── City→station fuzzy matcher ────────────────────────────────────────
  // Priority: exact station-name match > city-name in station > river match
  // Hardcoded best-station overrides for all 13 Bihar app cities:
  static const Map<String, String> _cityToStation = {
    'patna': 'Gandhighat',
    'bhagalpur': 'Bhagalpur',
    'munger': 'Munger',
    'begusarai': 'Hathidah',
    'katihar': 'Kursela',
    'supaul': 'Birpur',
    'darbhanga': 'Hayaghat',
    'muzaffarpur': 'Rosera',
    'sitamarhi': 'Dheng Bridge',
    'gopalganj': 'Kukraha',
    'siwan': 'Darauli',
    'khagaria': 'Khagaria',
    'purnia': 'Dhengraghat',
  };

  BiharStationReading? _bestMatch(
      List<BiharStationReading> all, IndiaCity city) {
    final preferred = _cityToStation[city.id.toLowerCase()];
    if (preferred != null) {
      final exact = all
          .where((r) => r.stationName.toLowerCase() == preferred.toLowerCase())
          .toList();
      if (exact.isNotEmpty) return exact.first;
    }

    // Fallback: fuzzy match on city name + river
    final lc = city.name.toLowerCase();
    final lr = city.river.toLowerCase();
    BiharStationReading? best;
    int bestScore = 0;
    for (final r in all) {
      final sn = r.stationName.toLowerCase();
      final rv = r.river.toLowerCase();
      int score = 0;
      if (sn == lc || sn.contains(lc) || lc.contains(sn)) score += 3;
      if (rv.contains(lr) || lr.contains(rv)) score += 2;
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    return bestScore >= 2 ? best : null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _inferTrend(double? diff) {
    if (diff == null) return 'Steady';
    if (diff > 0.02) return 'Rising';
    if (diff < -0.02) return 'Falling';
    return 'Steady';
  }

  DateTime _parseDate(String s) {
    // e.g. "25 May 2026 1:00 PM"  or  "25 May 2026 8:00 AM"
    try {
      final clean = s.trim();
      // split: "25 May 2026" + "1:00 PM"
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length < 4) return DateTime.now();
      final day = int.parse(parts[0]);
      const months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };
      final month = months[parts[1]] ?? 1;
      final year = int.parse(parts[2]);
      final timeParts = parts[3].split(':');
      int hour = int.parse(timeParts[0]);
      final min = int.parse(timeParts[1]);
      if (parts.length > 4) {
        final ampm = parts[4].toUpperCase();
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
      }
      return DateTime(year, month, day, hour, min);
    } catch (_) {
      return DateTime.now();
    }
  }
}
