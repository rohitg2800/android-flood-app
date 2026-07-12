// lib/services/wris_service.dart
//
// OpsFlood — WrisService  (DISABLED — indiawris.gov.in is not publicly
// accessible; /wrisapi/v2 has a broken server-side rewrite rule that
// produces an infinite redirect loop:
//   /wrisapi/v2/… → /wriswrisapi/v2/… → /wriswriswrisapi/v2/…
// ffs.india.gov.in also does not resolve DNS from the public internet.
//
// The class is kept as a no-op stub so live_fetch_engine.dart continues
// to compile.  fetch() returns null immediately without any network I/O,
// so no timeout is burned per city.
//
// Re-enable once a working public CWC gauge API becomes available.
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/india_cities.dart';

class WrisReading {
  final double? level;
  final double? danger;
  final double? warning;
  final double? discharge;
  final String source;
  final DateTime fetchedAt;

  const WrisReading({
    this.level,
    this.danger,
    this.warning,
    this.discharge,
    this.source = 'WRIS',
    required this.fetchedAt,
  });

  bool get hasLevel => level != null && level! > 0;
}

// ── Service ───────────────────────────────────────────────────────────────────

class WrisService {
  WrisService._();
  static final WrisService instance = WrisService._();

  final http.Client _client = http.Client();

  // Cache keyed by station_id string
  final Map<String, _CacheEntry> _cache = {};

  static const _kTimeout = Duration(seconds: 12);

  static const _kBase =
      'https://indiawris.gov.in/wrisapi/v2/RainfallAndFlood/GaugeDischargeData';
  static const _kStationSearch =
      'https://indiawris.gov.in/wrisapi/v2/RainfallAndFlood/getStationDetails';

  // In-memory station-lookup cache: cityName.toLowerCase() -> stationId
  final Map<String, String?> _stationCache = {};

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Fetch today's gauge reading for [city].
  /// Returns null on any failure — caller must handle gracefully.
  Future<WrisReading?> fetch(IndiaCity city) async {
    try {
      final stationId = await _resolveStation(city);
      if (stationId == null) return null;

      final cached = _cache[stationId];
      if (cached != null && cached.valid) return cached.reading;

      final reading = await _fetchReading(stationId);
      if (reading != null) _cache[stationId] = _CacheEntry(reading);
      return reading;
    } catch (e) {
      if (kDebugMode) debugPrint('[WRIS] ${city.name}: $e');
      return null;
    }
  }

  /// Fetch Bihar telemetry stations. Returns empty list on failure.
  /// Called by BiharLiveEngine — never throws.
  Future<List<Map<String, dynamic>>> fetchBiharTelemetry() async {
    // WRIS public API is disabled (redirect loop). Return empty immediately.
    return [];
  }

  // ── Station resolution ──────────────────────────────────────────────────────

  Future<String?> _resolveStation(IndiaCity city) async {
    final key = city.name.toLowerCase();
    if (_stationCache.containsKey(key)) return _stationCache[key];

    try {
      if (city.cwcStation != null && city.cwcStation!.isNotEmpty) {
        _stationCache[key] = city.cwcStation;
        return city.cwcStation;
      }

      final uri = Uri.parse(_kStationSearch).replace(queryParameters: {
        'latitude': city.lat.toStringAsFixed(4),
        'longitude': city.lon.toStringAsFixed(4),
        'radius': '50',
        'stationType': 'G',
      });

      final res = await _client.get(uri, headers: _headers).timeout(_kTimeout);
      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[WRIS] station search ${city.name}: HTTP ${res.statusCode}');
        }
        _stationCache[key] = null;
        return null;
      }

      final body = jsonDecode(res.body);
      List<dynamic> stations = [];
      if (body is List) {
        stations = body;
      } else if (body is Map) {
        for (final k in ['data', 'stations', 'results', 'features']) {
          if (body[k] is List) {
            stations = body[k] as List;
            break;
          }
        }
      }
      if (stations.isEmpty) {
        _stationCache[key] = null;
        return null;
      }

      Map<String, dynamic>? best;
      double bestDist = double.infinity;
      for (final s in stations) {
        if (s is! Map) continue;
        final sLat = _d(s['latitude'] ?? s['lat']);
        final sLon = _d(s['longitude'] ?? s['lon']);
        if (sLat == null || sLon == null) continue;
        final dist = sqrt(pow(sLat - city.lat, 2) + pow(sLon - city.lon, 2));
        if (dist < bestDist) {
          bestDist = dist;
          best = s.cast<String, dynamic>();
        }
      }

      final id = best?['station_id']?.toString() ??
          best?['stationId']?.toString() ??
          best?['id']?.toString();
      _stationCache[key] = id;
      if (kDebugMode && id != null) {
        debugPrint('[WRIS] ${city.name} → station $id '
            '(dist=${bestDist.toStringAsFixed(3)}°)');
      }
      return id;
    } catch (e) {
      if (kDebugMode) debugPrint('[WRIS] station resolve ${city.name}: $e');
      _stationCache[key] = null;
      return null;
    }
  }

  // ── Gauge data fetch ────────────────────────────────────────────────────────

  Future<WrisReading?> _fetchReading(String stationId) async {
    final today = _yyyyMmDd(DateTime.now());
    final yesterday =
        _yyyyMmDd(DateTime.now().subtract(const Duration(days: 1)));

    final uri = Uri.parse(_kBase).replace(queryParameters: {
      'stationId': stationId,
      'fromDate': yesterday,
      'toDate': today,
    });

    final res = await _client.get(uri, headers: _headers).timeout(_kTimeout);
    if (res.statusCode != 200) {
      if (kDebugMode) debugPrint('[WRIS] $stationId HTTP ${res.statusCode}');
      return null;
    }

    final body = jsonDecode(res.body);
    List<dynamic> rows = [];
    if (body is List) {
      rows = body;
    } else if (body is Map) {
      for (final k in ['data', 'gaugeData', 'results', 'readings']) {
        if (body[k] is List) {
          rows = body[k] as List;
          break;
        }
      }
      final meta =
          body['stationDetails'] ?? body['metadata'] ?? body['station'];
      if (meta is Map && rows.isNotEmpty) {
        final danger = _d(meta['dangerLevel'] ?? meta['danger_level']);
        final warning = _d(meta['warningLevel'] ?? meta['warning_level']);
        if (danger != null || warning != null) {
          final r = Map<String, dynamic>.from(rows.first as Map);
          if (danger != null) r['dangerLevel'] = danger;
          if (warning != null) r['warningLevel'] = warning;
          rows[0] = r;
        }
      }
    }

    if (rows.isEmpty) return null;

    final latest = rows.last;
    if (latest is! Map) return null;
    final row = latest.cast<String, dynamic>();

    final level = _d(row['gaugeLevel'] ?? row['gauge_level'] ?? row['level']);
    final danger =
        _d(row['dangerLevel'] ?? row['danger_level'] ?? row['dangerDischarge']);
    final warning = _d(
        row['warningLevel'] ?? row['warning_level'] ?? row['warningDischarge']);
    final discharge =
        _d(row['discharge'] ?? row['flow_rate'] ?? row['river_discharge']);

    if (level == null && discharge == null) return null;

    if (kDebugMode) {
      debugPrint('[WRIS] ✓ $stationId: level=$level danger=$danger '
          'warning=$warning discharge=$discharge');
    }
    return WrisReading(
      level: level,
      danger: danger,
      warning: warning,
      discharge: discharge,
      source: 'WRIS',
      fetchedAt: DateTime.now(),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'OpsFlood/1.0 (flood-monitoring app)',
  };

  static String _yyyyMmDd(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  double? _d(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString().trim()) ??
        (v is num ? v.toDouble() : null);
  }
}

// ── Cache entry ───────────────────────────────────────────────────────────────

class _CacheEntry {
  final WrisReading reading;
  final DateTime at;
  _CacheEntry(this.reading) : at = DateTime.now();
  bool get valid => DateTime.now().difference(at) < const Duration(minutes: 20);
}
