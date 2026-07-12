// lib/services/cwc_direct_service.dart
//
// OpsFlood — CwcDirectService (v3.3 — Bihar-only)
//
// v3.3 change: Removed all non-Bihar entries from _cwcFfemKey().
//   FFEM map now covers only Bihar CWC gauge stations.
//   Also removed non-Bihar entries from _ffsBase / _ffsApiBase usage
//   (they were already guarded by IndiaCity.cwcStation == null for
//   non-Bihar cities, but the map itself is now clean).
//
// SOURCES (in priority order per city):
//   1. CWC FFEM national JSON  — Bihar stations only
//   2. CWC FFS per-station bulletin — needs cwcStation code (Bihar only)
//   3. BiharWrdScraper         — Bihar only, HTML table, 103 stations
//   4. CWC BEAMS Bihar         — Bihar only
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/india_cities.dart';
import 'bihar_wrd_scraper.dart';

// ── Reading model ───────────────────────────────────────────────────────────────
class CwcReading {
  final double level;
  final double warning;
  final double danger;
  final double? hfl;
  final String source;
  final String? stationName;
  final DateTime fetchedAt;

  const CwcReading({
    required this.level,
    required this.warning,
    required this.danger,
    this.hfl,
    required this.source,
    this.stationName,
    required this.fetchedAt,
  });
}

// ── Private cache entry ───────────────────────────────────────────────────────────
class _CacheEntry {
  final CwcReading reading;
  final DateTime fetchedAt;
  const _CacheEntry({required this.reading, required this.fetchedAt});
}

// ── Service ───────────────────────────────────────────────────────────────────
class CwcDirectService {
  CwcDirectService._();
  static final CwcDirectService instance = CwcDirectService._();

  final http.Client _client = http.Client();

  static const _kTimeout = Duration(seconds: 14);
  static const _kGaugeMin = 0.5; // m MSL
  static const _kGaugeMax = 250.0; // m MSL

  // Per-city result cache (10-min TTL)
  final Map<String, _CacheEntry> _cache = {};
  static const _kCacheTTL = Duration(minutes: 10);

  // ── Public fetch ───────────────────────────────────────────────────────────────
  Future<CwcReading?> fetch(IndiaCity city) async {
    final key = city.id;
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _kCacheTTL) {
      return cached.reading;
    }

    CwcReading? reading;
    reading ??= await _fetchFromCwcFfem(city);
    reading ??= await _fetchFromCwcFfs(city);
    // Source 3: Bihar WRD HTML table scraper (103 stations, shared 10-min cache)
    reading ??= await BiharWrdScraper.instance.fetchForCity(city);
    reading ??= await _fetchFromBiharBeams(city);

    if (reading != null) {
      _cache[key] = _CacheEntry(reading: reading, fetchedAt: DateTime.now());
    }
    return reading;
  }

  void clearCache() => _cache.clear();

  // ── Source 1: CWC FFEM national JSON (Bihar stations only) ───────────────
  static const _ffemUrl = 'https://cwc.gov.in/sites/default/files/ffem.json';
  static Map<String, dynamic>? _ffemCache;
  static DateTime? _ffemCacheTime;

  Future<CwcReading?> _fetchFromCwcFfem(IndiaCity city) async {
    final stationKey = _cwcFfemKey(city);
    if (stationKey == null) return null;

    try {
      final now = DateTime.now();
      if (_ffemCache == null ||
          _ffemCacheTime == null ||
          now.difference(_ffemCacheTime!) > const Duration(minutes: 15)) {
        final res = await _client.get(Uri.parse(_ffemUrl)).timeout(_kTimeout);
        if (res.statusCode != 200) return null;
        final body = res.body.trim();
        if (body.startsWith('<')) return null;
        _ffemCache = jsonDecode(body) as Map<String, dynamic>;
        _ffemCacheTime = now;
        if (kDebugMode) {
          debugPrint(
              '[CwcDirect] FFEM fetched: ${_ffemCache!.length} stations');
        }
      }

      Map<String, dynamic>? entry =
          _ffemCache![stationKey] as Map<String, dynamic>?;
      if (entry == null) {
        final uk = stationKey.toUpperCase();
        for (final k in _ffemCache!.keys) {
          if (k.toUpperCase() == uk) {
            entry = _ffemCache![k] as Map<String, dynamic>?;
            break;
          }
        }
      }
      if (entry == null) return null;

      final cl =
          _parseLevel(entry['CL'] ?? entry['cl'] ?? entry['current_level']);
      final dl =
          _parseLevel(entry['DL'] ?? entry['dl'] ?? entry['danger_level']);
      final wl =
          _parseLevel(entry['WL'] ?? entry['wl'] ?? entry['warning_level']);
      if (cl == null || cl <= 0) return null;

      return CwcReading(
        level: cl,
        warning: wl ?? city.warningLevel,
        danger: dl ?? city.dangerLevel,
        source: 'CWC_FFEM',
        stationName: stationKey,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcDirect] FFEM ${city.name}: $e');
      return null;
    }
  }

  // ── Source 2: CWC FFS per-station bulletin ───────────────────────────────────
  static const _ffsBase = 'https://cwc.gov.in/ffnew/stationwise_bulletin.php';
  static const _ffsApiBase = 'https://cwc.gov.in/api/v1/stations';

  static final Map<String, _CacheEntry> _ffsCache = {};
  static const _kFfsCacheTTL = Duration(minutes: 15);

  Future<CwcReading?> _fetchFromCwcFfs(IndiaCity city) async {
    if (city.cwcStation == null) return null;
    final code = city.cwcStation!;

    final cached = _ffsCache[code];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _kFfsCacheTTL) {
      return cached.reading;
    }

    CwcReading? r = await _tryFfsUrl(
      Uri.parse('$_ffsBase?id=${Uri.encodeComponent(code)}'),
      city,
      'CWC_FFS',
    );

    r ??= await _tryFfsUrl(
      Uri.parse('$_ffsApiBase/${Uri.encodeComponent(code)}/latest'),
      city,
      'CWC_FFS_API',
    );

    if (r != null) {
      _ffsCache[code] = _CacheEntry(reading: r, fetchedAt: DateTime.now());
      if (kDebugMode)
        debugPrint('[CwcDirect] FFS ✓ ${city.name}: level=${r.level}');
    }
    return r;
  }

  Future<CwcReading?> _tryFfsUrl(
      Uri uri, IndiaCity city, String sourceLabel) async {
    try {
      final res = await _client.get(uri).timeout(_kTimeout);
      if (res.statusCode != 200) return null;
      final body = res.body.trim();
      if (body.startsWith('<')) return null;
      final j = jsonDecode(body);
      final map = j is Map<String, dynamic>
          ? j
          : (j is List && j.isNotEmpty
              ? j.first as Map<String, dynamic>?
              : null);
      if (map == null) return null;
      return _parseFfsEntry(map, city, sourceLabel);
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcDirect] $sourceLabel ${city.name}: $e');
      return null;
    }
  }

  CwcReading? _parseFfsEntry(
      Map<String, dynamic> m, IndiaCity city, String source) {
    final cl = _parseLevel(
      m['current_level'] ??
          m['CL'] ??
          m['cl'] ??
          m['water_level'] ??
          m['level'] ??
          m['gauge_reading'] ??
          m['gauge'] ??
          m['obs_level'],
    );
    if (cl == null || cl <= 0) return null;
    final dl =
        _parseLevel(m['danger_level'] ?? m['DL'] ?? m['dl'] ?? m['danger']);
    final wl =
        _parseLevel(m['warning_level'] ?? m['WL'] ?? m['wl'] ?? m['warning']);
    return CwcReading(
      level: cl,
      warning: wl ?? city.warningLevel,
      danger: dl ?? city.dangerLevel,
      source: source,
      stationName: m['station_name']?.toString() ?? m['station']?.toString(),
      fetchedAt: DateTime.now(),
    );
  }

  // ── Source 4: CWC BEAMS Bihar ────────────────────────────────────────────────────────────
  static const _beamsUrl =
      'https://beams.fmiscwrdbihar.gov.in/bulletin/gaugereport.json';
  static List<dynamic>? _beamsCache;
  static DateTime? _beamsCacheTime;

  Future<CwcReading?> _fetchFromBiharBeams(IndiaCity city) async {
    if (city.cwcStation == null) return null;
    try {
      final now = DateTime.now();
      if (_beamsCache == null ||
          _beamsCacheTime == null ||
          now.difference(_beamsCacheTime!) > const Duration(minutes: 10)) {
        final res = await _client.get(Uri.parse(_beamsUrl)).timeout(_kTimeout);
        if (res.statusCode != 200) return null;
        final body = res.body.trim();
        if (body.startsWith('<')) return null;
        final parsed = jsonDecode(body);
        _beamsCache = parsed is List ? parsed : (parsed['data'] as List? ?? []);
        _beamsCacheTime = now;
        if (kDebugMode) {
          debugPrint(
              '[CwcDirect] BEAMS fetched: ${_beamsCache!.length} stations');
        }
      }

      final code = city.cwcStation!.toUpperCase();
      final lc = city.name.toLowerCase();
      Map<String, dynamic>? best;
      for (final row in _beamsCache!.whereType<Map<String, dynamic>>()) {
        final id = (row['station_id'] ?? row['id'] ?? row['code'] ?? '')
            .toString()
            .toUpperCase();
        final sn =
            (row['station'] ?? row['name'] ?? '').toString().toLowerCase();
        if (id == code || sn.contains(lc) || lc.contains(sn)) {
          best = row;
          break;
        }
      }
      if (best == null) return null;

      final cl =
          _parseLevel(best['current_level'] ?? best['wl'] ?? best['level']);
      final dl = _parseLevel(best['danger_level'] ?? best['dl']);
      final wl = _parseLevel(best['warning_level'] ?? best['warning']);
      if (cl == null || cl <= 0) return null;

      return CwcReading(
        level: cl,
        warning: wl ?? city.warningLevel,
        danger: dl ?? city.dangerLevel,
        source: 'CWC_BEAMS',
        stationName: (best['station'] ?? best['name'])?.toString(),
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CwcDirect] BEAMS ${city.name}: $e');
      return null;
    }
  }

  // ── CWC FFEM station name map — BIHAR ONLY ──────────────────────────────────────
  String? _cwcFfemKey(IndiaCity city) {
    // Only Bihar CWC gauge stations are mapped here.
    // All non-Bihar entries have been removed (v3.3).
    const map = <String, String>{
      'patna': 'GANDHIGHAT',
      'bhagalpur': 'BHAGALPUR',
      'munger': 'MUNGER',
      'begusarai': 'HATHIDAH',
      'katihar': 'KURSELA',
      'supaul': 'BIRPUR',
      'darbhanga': 'HAYAGHAT',
      'muzaffarpur': 'ROSERA',
      'sitamarhi': 'DHENG',
      'gopalganj': 'TRIVENIGANJ',
      'siwan': 'DORIGHATS',
      'khagaria': 'KHAGARIA',
      'purnia': 'JAMALPUR',
    };
    return map[city.id];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────────
  double? _parseLevel(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString().trim());
    if (d == null) return null;
    if (d < _kGaugeMin || d > _kGaugeMax) {
      if (kDebugMode) {
        debugPrint(
            '[CwcDirect] REJECT level $d m (outside [$_kGaugeMin, $_kGaugeMax])');
      }
      return null;
    }
    return d;
  }
}
