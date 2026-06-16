// lib/services/befiqr_cwc_service.dart  v3.3
//
// Live CWC + WRD Bihar station data — 5-source parallel scraper
//
// v3.3 (15 Jun 2026) — resilience hardening:
//   • Per-request timeout kept at 12s (set in v3.1).
//   • Rate-limit guard: on HTTP 429 or 503, read Retry-After header and
//     wait that duration (capped at 30s) before retrying once.
//   • Max 3 attempts per source with exponential back-off (0s, 2s, 4s).
//   • Structured error logging via debugPrint with source tag, attempt
//     number, status code, and elapsed time for easy logcat filtering.
//   • _doGet() helper centralises timeout + retry logic so each source
//     method stays clean.
//
// v3.2 — expose static seedStations getter (source_policy_provider.dart).
// v3.1 — individual source timeouts bumped 6s→12s; race timeout 8s→15s.
//
// SOURCE PRIORITY — all fired in parallel, first non-empty list wins:
//  A. CWC Open Data REST API     (data.gov.in / cwc.gov.in)  — stable JSON
//  B. BEAMS Bihar HTML           (beams.fmiscwrdbihar.gov.in) — most stations
//  C. CWC Flood Bulletin JSON    (cwc.gov.in/fld_mng)         — daily snapshot
//  D. GloFAS CEMS Bihar stations (emergency.copernicus.eu)    — EU-hosted
//  E. irrigation.befiqr.in HTML  (legacy)                     — mirror
//
// Seed returned when all 5 sources return empty within 15s.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// WRD → AMSL offset table (metres)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, double> _kWrdToAmslOffset = {
  'kosi':         139.30,
  'gandak':         0.00,
  'ganga':          0.00,
  'ghaghra':        0.00,
  'bagmati':        0.00,
  'burhi gandak':   0.00,
  'mahananda':      0.00,
  'kamla':          0.00,
  'kamalabalan':    0.00,
  'adhwara':        0.00,
  'punpun':         0.00,
  'son':            0.00,
  'budhi gandak':   0.00,
  'buri gandak':    0.00,
};

double _wrdOffset(String river) {
  final key = river.toLowerCase().trim();
  for (final entry in _kWrdToAmslOffset.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// CwcStation model
// ─────────────────────────────────────────────────────────────────────────────

class CwcStation {
  final String  river;
  final String  site;
  final double  currentLevel;
  final double  dangerLevel;
  final double? warningLevel;
  final String? trend;
  final String? status;
  final String  source;
  final bool    isFromSeed;
  final DateTime fetchedAt;

  const CwcStation({
    required this.river,
    required this.site,
    required this.currentLevel,
    required this.dangerLevel,
    this.warningLevel,
    this.trend,
    this.status,
    this.source = 'SEED',
    this.isFromSeed = false,
    required this.fetchedAt,
  });

  double get gap        => dangerLevel - currentLevel;
  bool   get isDanger   => gap <= 0;
  bool   get isWarning  => gap > 0 && gap <= 1.5;
  bool   get isElevated => gap > 1.5 && gap <= 3.0;

  String get statusLabel {
    if (isDanger)   return 'DANGER';
    if (isWarning)  return 'WARNING';
    if (isElevated) return 'ELEVATED';
    return 'NORMAL';
  }

  double get fillFraction =>
      (currentLevel / dangerLevel).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'river':        river,
    'site':         site,
    'currentLevel': currentLevel,
    'dangerLevel':  dangerLevel,
    if (warningLevel != null) 'warningLevel': warningLevel,
    if (trend  != null) 'trend':  trend,
    if (status != null) 'status': status,
    'source':      source,
    'isFromSeed':  isFromSeed,
    'fetchedAt':   fetchedAt.toIso8601String(),
  };

  factory CwcStation.fromJson(Map<String, dynamic> j) => CwcStation(
    river:        j['river']  as String,
    site:         j['site']   as String,
    currentLevel: (j['currentLevel'] as num).toDouble(),
    dangerLevel:  (j['dangerLevel']  as num).toDouble(),
    warningLevel: j['warningLevel'] != null
        ? (j['warningLevel'] as num).toDouble() : null,
    trend:      j['trend']      as String?,
    status:     j['status']     as String?,
    source:     (j['source']    as String?) ?? 'SEED',
    isFromSeed: (j['isFromSeed'] as bool?)  ?? false,
    fetchedAt:  DateTime.parse(j['fetchedAt'] as String),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 32-station seed snapshot (CWC official, June 2026)
// ─────────────────────────────────────────────────────────────────────────────

List<CwcStation> get _seedStations {
  final now = DateTime.now();
  CwcStation s(String river, String site, double level, double danger,
      {double? warning}) =>
      CwcStation(
        river: river, site: site,
        currentLevel: level, dangerLevel: danger, warningLevel: warning,
        source: 'SEED', isFromSeed: true, fetchedAt: now,
      );
  return [
    s('Adhwara',      'Ekmighat',                  40.62, 46.94),
    s('Adhwara',      'Kamtaul',                   46.54, 50.00),
    s('Adhwara',      'Sonbarsa',                  78.78, 81.85),
    s('Bagmati',      'Benibad',                   46.25, 48.68),
    s('Bagmati',      'Dheng Bridge',              68.35, 71.00),
    s('Bagmati',      'Hayaghat',                  39.26, 45.72),
    s('Burhi Gandak', 'Khagaria',                  29.99, 36.58),
    s('Burhi Gandak', 'Rosera',                    36.31, 42.63),
    s('Burhi Gandak', 'Samastipur',                39.28, 46.00),
    s('Burhi Gandak', 'Sikandarpur (Muzzafarpur)', 45.18, 52.53),
    s('Gandak',       'Chatia',                    64.99, 69.15),
    s('Gandak',       'Dumariaghat',               60.46, 62.22),
    s('Gandak',       'Hajipur',                   44.54, 50.32),
    s('Gandak',       'Rewaghat',                  51.12, 54.41),
    s('Ganga',        'Bhagalpur',                 25.74, 33.68),
    s('Ganga',        'Buxar',                     49.19, 60.30),
    s('Ganga',        'Dighaghat',                 43.05, 50.45),
    s('Ganga',        'Gandhighat',                42.61, 48.60),
    s('Ganga',        'Hathidah',                  34.60, 41.76),
    s('Ganga',        'Kahalgaon',                 24.64, 31.09),
    s('Ganga',        'Munger',                    30.76, 39.33),
    s('Ghaghra',      'Darauli',                   56.20, 60.82),
    s('Ghaghra',      'Gangpur Siswan',            51.89, 57.04),
    s('Kamalabalan',  'Jhanjharpur',               48.15, 50.00),
    s('Kamla',        'Jainagar',                  66.28, 67.75),
    s('Kosi',         'Baltara',                   31.28, 33.85),
    s('Kosi',         'Basua',                     45.82, 47.75),
    s('Kosi',         'Birpur',                    72.75,  74.70, warning: 73.70),
    s('Kosi',         'Kursela',                   24.40, 30.00),
    s('Mahananda',    'Dhengraghat',               33.30, 35.65),
    s('Mahananda',    'Taibpur',                   63.72, 66.00),
    s('Punpun',       'Sripalpur',                 44.81, 50.60),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BefiqrCwcService
// ─────────────────────────────────────────────────────────────────────────────

class BefiqrCwcService {
  static const _beamsUrl    = 'https://beams.fmiscwrdbihar.gov.in/Alerttotalinfo/realtimetotal.aspx';
  static const _befiqrUrl   = 'https://irrigation.befiqr.in/state/table/cwc-stations';
  static const _cwcApiUrl   =
      'https://api.data.gov.in/resource/6176b6b7-77a1-4bf7-bc37-a2e4a67f3e4d'
      '?api-key=579b464db66ec23bdd000001cdd3946e44ce4aebb209dbe7b49b3c55'
      '&format=json&limit=50&filters%5Bstate%5D=Bihar';
  static const _cwcBulletinUrl =
      'https://cwc.gov.in/fld_mng/bihar_flood_bulletin.json';
  static const _glofasUrl =
      'https://emergency.copernicus.eu/CEMS-fis/api/v1/stations'
      '?country=IN&state=Bihar&format=json';

  static const _raceTimeout   = Duration(seconds: 15);
  static const _perReqTimeout = Duration(seconds: 12);
  static const _maxRetries    = 3;
  // back-off delays: attempt 0 → 0s, 1 → 2s, 2 → 4s
  static const _backOffSeconds = [0, 2, 4];
  // cap on Retry-After wait to avoid blocking the race for too long
  static const _maxRetryAfterSeconds = 30;

  // ── v3.2: public static accessor for the embedded seed snapshot ──────────
  static List<CwcStation> get seedStations => _seedStations;

  // ── v3.3: centralised HTTP helper with timeout + retry-after + back-off ──
  //
  // tag    : source name for logcat filtering (e.g. 'BEAMS', 'CWC-OpenData')
  // headers: request headers
  // Returns the successful [http.Response] or throws the last exception.
  Future<http.Response> _doGet(
    String tag,
    String url,
    Map<String, String> headers,
  ) async {
    Object? lastErr;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      // exponential back-off before retry (skip on first attempt)
      if (attempt > 0) {
        await Future.delayed(
            Duration(seconds: _backOffSeconds[attempt]));
      }
      final sw = Stopwatch()..start();
      try {
        final resp = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(_perReqTimeout);
        sw.stop();

        // Rate-limit / overload guard
        if (resp.statusCode == 429 || resp.statusCode == 503) {
          final retryAfterRaw = resp.headers['retry-after'];
          final waitSeconds   = int.tryParse(retryAfterRaw ?? '') ?? 5;
          final capped        = waitSeconds.clamp(1, _maxRetryAfterSeconds);
          debugPrint(
              '[BefiqrCwcService][$tag] attempt $attempt — '
              'HTTP ${resp.statusCode}, Retry-After ${capped}s '
              '(elapsed ${sw.elapsedMilliseconds}ms)');
          await Future.delayed(Duration(seconds: capped));
          lastErr = Exception('HTTP ${resp.statusCode}');
          continue;
        }

        debugPrint(
            '[BefiqrCwcService][$tag] attempt $attempt — '
            'HTTP ${resp.statusCode} (${sw.elapsedMilliseconds}ms)');
        return resp;
      } catch (e) {
        sw.stop();
        lastErr = e;
        debugPrint(
            '[BefiqrCwcService][$tag] attempt $attempt — '
            'error: $e (${sw.elapsedMilliseconds}ms)');
      }
    }
    throw lastErr ?? Exception('[$tag] failed after $_maxRetries attempts');
  }

  /// Fetch all Bihar CWC stations.
  /// Fires 5 sources in parallel — first non-empty list wins.
  /// Never throws — falls back to seed if all fail within 15s.
  Future<List<CwcStation>> fetchStations() async {
    final futures = <Future<List<CwcStation>>>[
      _tryCwcOpenData(),
      _fetchBeams(),
      _tryCwcBulletin(),
      _tryGloFAS(),
      _tryBefiqr(),
    ];

    final completer = Completer<List<CwcStation>>();
    int pending = futures.length;

    for (final f in futures) {
      f.then((result) {
        if (result.isNotEmpty && !completer.isCompleted) {
          completer.complete(result);
        } else {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete([]);
          }
        }
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete([]);
        }
      });
    }

    final result = await completer.future.timeout(
      _raceTimeout,
      onTimeout: () => [],
    );

    if (result.isNotEmpty) return result;
    debugPrint('[BefiqrCwcService] ⚠️  all 5 sources failed — using seed (${_seedStations.length} stations)');
    return _seedStations;
  }

  // ── Source A: CWC Open Data REST API ───────────────────────────────────────
  Future<List<CwcStation>> _tryCwcOpenData() async {
    try {
      final resp = await _doGet('CWC-OpenData', _cwcApiUrl, {
        'Accept':     'application/json',
        'User-Agent': 'OpsFlood/3.3',
      });
      if (resp.statusCode == 200) {
        final body  = jsonDecode(resp.body) as Map<String, dynamic>;
        final recs  = (body['records'] as List?)?.cast<Map<String, dynamic>>();
        if (recs == null || recs.isEmpty) return [];
        final now      = DateTime.now();
        final stations = <CwcStation>[];
        for (final r in recs) {
          final level  = _parseDbl(r['current_level']);
          final danger = _parseDbl(r['danger_level']);
          if (level == null || danger == null || danger <= 0) continue;
          stations.add(CwcStation(
            river:        r['river_name']?.toString() ?? '',
            site:         r['station_name']?.toString() ?? '',
            currentLevel: level,
            dangerLevel:  danger,
            warningLevel: _parseDbl(r['warning_level']),
            trend:        r['trend']?.toString(),
            source:       'CWC-OpenData',
            isFromSeed:   false,
            fetchedAt:    DateTime.tryParse(r['obs_date']?.toString() ?? '') ?? now,
          ));
        }
        if (stations.isNotEmpty) debugPrint('[BefiqrCwcService][CWC-OpenData] ✅ ${stations.length} stations');
        return stations;
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService][CWC-OpenData] ❌ $e');
    }
    return [];
  }

  // ── Source B: BEAMS Bihar HTML ──────────────────────────────────────────────
  Future<List<CwcStation>> _fetchBeams() async {
    try {
      final resp = await _doGet('BEAMS', _beamsUrl, {
        'Accept':          'text/html,application/xhtml+xml',
        'User-Agent':      'Mozilla/5.0 (OpsFlood/3.3)',
        'Accept-Language': 'en-IN,en;q=0.9',
      });
      if (resp.statusCode == 200) {
        final stations = _parseBeamsHtml(resp.body);
        if (stations.isNotEmpty) debugPrint('[BefiqrCwcService][BEAMS] ✅ ${stations.length} stations');
        return stations;
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService][BEAMS] ❌ $e');
    }
    return [];
  }

  // ── Source C: CWC Bihar Bulletin JSON ────────────────────────────────────
  Future<List<CwcStation>> _tryCwcBulletin() async {
    try {
      final resp = await _doGet('CWC-Bulletin', _cwcBulletinUrl, {
        'Accept':     'application/json',
        'User-Agent': 'OpsFlood/3.3',
      });
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body['stations'] as List? ?? body as List?)?.cast<Map<String, dynamic>>();
        if (list == null || list.isEmpty) return [];
        final now      = DateTime.now();
        final stations = <CwcStation>[];
        for (final r in list) {
          final level  = _parseDbl(r['current_level'] ?? r['wl']);
          final danger = _parseDbl(r['danger_level']  ?? r['dl']);
          if (level == null || danger == null || danger <= 0) continue;
          stations.add(CwcStation(
            river:        r['river']?.toString() ?? '',
            site:         r['site']?.toString()  ?? r['station']?.toString() ?? '',
            currentLevel: level,
            dangerLevel:  danger,
            warningLevel: _parseDbl(r['warning_level'] ?? r['wl_warn']),
            trend:        r['trend']?.toString(),
            source:       'CWC-Bulletin',
            isFromSeed:   false,
            fetchedAt:    DateTime.tryParse(r['obs_date']?.toString() ?? '') ?? now,
          ));
        }
        if (stations.isNotEmpty) debugPrint('[BefiqrCwcService][CWC-Bulletin] ✅ ${stations.length} stations');
        return stations;
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService][CWC-Bulletin] ❌ $e');
    }
    return [];
  }

  // ── Source D: GloFAS CEMS Bihar stations ──────────────────────────────────
  Future<List<CwcStation>> _tryGloFAS() async {
    try {
      final resp = await _doGet('GloFAS', _glofasUrl, {
        'Accept':     'application/json',
        'User-Agent': 'OpsFlood/3.3',
      });
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body['features'] as List? ??
                      body['stations'] as List?)?.cast<Map<String, dynamic>>();
        if (list == null || list.isEmpty) return [];
        final now      = DateTime.now();
        final stations = <CwcStation>[];
        for (final feat in list) {
          final props  = feat['properties'] as Map<String, dynamic>? ?? feat;
          final level  = _parseDbl(props['water_level'] ?? props['level_m']);
          final danger = _parseDbl(props['danger_level'] ?? props['threshold_m']);
          if (level == null || danger == null || danger <= 0) continue;
          stations.add(CwcStation(
            river:        props['river']?.toString() ?? '',
            site:         props['name']?.toString()  ?? props['station_name']?.toString() ?? '',
            currentLevel: level,
            dangerLevel:  danger,
            warningLevel: _parseDbl(props['warning_level']),
            trend:        props['trend']?.toString(),
            source:       'GloFAS',
            isFromSeed:   false,
            fetchedAt:    DateTime.tryParse(props['valid_time']?.toString() ?? '') ?? now,
          ));
        }
        if (stations.isNotEmpty) debugPrint('[BefiqrCwcService][GloFAS] ✅ ${stations.length} stations');
        return stations;
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService][GloFAS] ❌ $e');
    }
    return [];
  }

  // ── Source E: befiqr HTML mirror (legacy) ───────────────────────────────
  Future<List<CwcStation>> _tryBefiqr() async {
    try {
      final resp = await _doGet('befiqr', _befiqrUrl, {
        'Accept': 'text/html,application/xhtml+xml',
        'User-Agent': 'OpsFlood/3.3',
      });
      if (resp.statusCode == 200) {
        final stations = parseHtmlTable(resp.body);
        if (stations.isNotEmpty) debugPrint('[BefiqrCwcService][befiqr] ✅ ${stations.length} stations');
        return stations;
      }
    } catch (e) {
      debugPrint('[BefiqrCwcService][befiqr] ❌ $e');
    }
    return [];
  }

  // ── BEAMS HTML parser ──────────────────────────────────────────────────────
  static List<CwcStation> _parseBeamsHtml(String htmlBody) {
    final stations = <CwcStation>[];
    final now      = DateTime.now();
    final doc      = html_parser.parse(htmlBody);
    final rows     = doc.querySelectorAll('table tr');
    bool headerSkipped = false;

    for (final row in rows) {
      final cells = row
          .querySelectorAll('td')
          .map((td) => td.text.trim())
          .toList();
      if (cells.length < 15) continue;
      if (!headerSkipped) { headerSkipped = true; continue; }

      final riverRaw   = cells[1].trim();
      final siteRaw    = cells[2].trim();
      if (riverRaw.isEmpty || siteRaw.isEmpty) continue;

      final wrdLevel   = _parseDbl(cells[14]);
      final wrdDanger  = _parseDbl(cells[8]);
      final wrdWarning = _parseDbl(cells[9]);
      final trend      = cells.length > 17 ? cells[17].trim() : null;
      final status     = cells.length > 18 ? cells[18].trim() : null;
      final obsDate    = cells.length > 13 ? (_parseBEAMSDate(cells[13]) ?? now) : now;

      if (wrdLevel  == null || wrdLevel  <= 0) continue;
      if (wrdDanger == null || wrdDanger <= 0) continue;

      final offset      = _wrdOffset(riverRaw);
      final amslLevel   = wrdLevel   + offset;
      final amslDanger  = wrdDanger  + offset;
      final amslWarning = wrdWarning != null ? wrdWarning + offset : null;

      stations.add(CwcStation(
        river:        riverRaw,
        site:         siteRaw,
        currentLevel: amslLevel,
        dangerLevel:  amslDanger,
        warningLevel: amslWarning,
        trend:        trend?.isNotEmpty == true  ? trend  : null,
        status:       status?.isNotEmpty == true ? status : null,
        source:       'BEAMS',
        isFromSeed:   false,
        fetchedAt:    obsDate,
      ));
    }
    return stations;
  }

  // ── befiqr HTML parser (public — used by KosiBirpurService) ───────────────
  static List<CwcStation> parseHtmlTable(String html) {
    final stations = <CwcStation>[];
    final now      = DateTime.now();
    final rowRe    = RegExp(r'<tr[^>]*>(.*?)</tr>',    dotAll: true);
    final cellRe   = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true);
    final tagRe    = RegExp(r'<[^>]+>');
    bool headerSkipped = false;

    for (final rowMatch in rowRe.allMatches(html)) {
      final cells = cellRe
          .allMatches(rowMatch.group(1)!)
          .map((m) => m.group(1)!.replaceAll(tagRe, '').trim())
          .toList();
      if (cells.length < 4) continue;
      if (!headerSkipped) { headerSkipped = true; continue; }

      final current = double.tryParse(cells[2].replaceAll(',', ''));
      final danger  = double.tryParse(cells[3].replaceAll(',', ''));
      if (current == null || danger == null) continue;

      stations.add(CwcStation(
        river:        cells[0],
        site:         cells[1],
        currentLevel: current,
        dangerLevel:  danger,
        source:       'befiqr',
        isFromSeed:   false,
        fetchedAt:    now,
      ));
    }
    return stations;
  }

  // ── Utilities ────────────────────────────────────────────────────────────
  static DateTime? _parseBEAMSDate(String s) {
    try {
      const months = {
        'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
        'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
        'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
      };
      var cleaned = s.replaceAll(RegExp(r'\s+HRS?', caseSensitive: false), ':00');
      for (final e in months.entries) { cleaned = cleaned.replaceAll(e.key, e.value); }
      final parts = cleaned.split(' ');
      if (parts.length >= 2) {
        final dp = parts[0].split('-');
        if (dp.length == 3) {
          return DateTime.tryParse('${dp[2]}-${dp[1]}-${dp[0]}T${parts[1]}:00');
        }
      }
    } catch (_) {}
    return null;
  }

  static double? _parseDbl(dynamic v) {
    if (v == null) return null;
    if (v is num)  return v.toDouble();
    return double.tryParse(
        v.toString().replaceAll(RegExp(r'[^\d.]'), '').trim());
  }

  // ── Analytics helpers ────────────────────────────────────────────────────
  static double riskScore(CwcStation s) =>
      (s.currentLevel / s.dangerLevel * 100).clamp(0, 100);

  static List<CwcStation> topRisk(List<CwcStation> stations, {int n = 5}) {
    final sorted = [...stations]
        ..sort((a, b) => riskScore(b).compareTo(riskScore(a)));
    return sorted.take(n).toList();
  }

  static String toJsonString(List<CwcStation> list) =>
      jsonEncode(list.map((s) => s.toJson()).toList());

  static List<CwcStation> fromJsonString(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CwcStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
