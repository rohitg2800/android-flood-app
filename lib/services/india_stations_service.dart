// lib/services/india_stations_service.dart
//
// OpsFlood — IndiaStationsService
// Fetches stations from opsflood.onrender.com/api/wrd-bihar/stations
// and returns ONLY Bihar stations (state filter applied).
// Merges with GloFAS discharge for every lat/lon.
//
// v1.1 (15 Jun 2026) — Bihar pipeline fix:
//   • Guard against HTML error pages returned instead of JSON (Railway cold
//     start / redirect). jsonDecode now only called when body starts with
//     '{' or '['. Failure is logged explicitly instead of throwing
//     FormatException silently swallowed by the outer catch.
//   • Added backupUrl fallback: if primary returns non-JSON, retry once
//     against AppConfig.backupUrl (if set).
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/flood_data.dart';

// Canonical Bihar state spellings returned by the backend.
const _kBiharAliases = {
  'bihar',
  'br',
  'state of bihar',
};

bool _isBihar(String state) =>
    _kBiharAliases.contains(state.toLowerCase().trim());

// Returns true when body is a JSON object or array (not HTML/empty).
bool _isJsonBody(String body) {
  final t = body.trimLeft();
  return t.startsWith('{') || t.startsWith('[');
}

class IndiaStationsService {
  static final IndiaStationsService _instance = IndiaStationsService._();
  factory IndiaStationsService() => _instance;
  IndiaStationsService._();

  final http.Client _client = http.Client();

  // GloFAS discharge cache — keyed by "lat2:lon2"
  final Map<String, _CE> _glofasCache = {};

  // ── Public API ────────────────────────────────────────────────────────

  /// Returns Bihar-only stations, merged with GloFAS discharge.
  Future<List<FloodData>> fetchAll() async {
    // Try primary URL, then backupUrl if set.
    final urls = [
      '${AppConfig.baseUrl}/api/wrd-bihar/stations',
      if (AppConfig.backupUrl.isNotEmpty)
        '${AppConfig.backupUrl}/api/wrd-bihar/stations',
    ];

    for (final urlStr in urls) {
      final result = await _fetchFrom(urlStr);
      if (result != null) return result;
    }
    return [];
  }

  Future<List<FloodData>?> _fetchFrom(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        debugPrint('[IndiaStations] HTTP ${res.statusCode} from $urlStr');
        return null;
      }

      // ── Bihar pipeline fix v1.1 ──────────────────────────────────────
      // Railway / render cold-start can return an HTML splash page instead
      // of JSON. Detect early and skip rather than throw FormatException.
      if (!_isJsonBody(res.body)) {
        debugPrint(
          '[IndiaStations] non-JSON response from $urlStr '
          '(likely HTML error/redirect page) — skipping',
        );
        return null; // triggers fallback to backupUrl or [].
      }
      // ── end fix ───────────────────────────────────────────────────────

      final body = jsonDecode(res.body);
      List<dynamic> raw = [];
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        for (final k in ['data', 'stations', 'results', 'items']) {
          if (body[k] is List) {
            raw = body[k] as List;
            break;
          }
        }
      }
      if (raw.isEmpty) return [];

      // Pre-filter to Bihar rows before expensive GloFAS fan-out.
      final biharRaw = raw.where((s) {
        if (s is! Map) return false;
        final state = (s['state'] ?? s['state_name'] ?? '').toString();
        return _isBihar(state);
      }).toList();

      debugPrint(
        '[IndiaStations] ${raw.length} total → ${biharRaw.length} Bihar stations',
      );

      if (biharRaw.isEmpty) return [];

      // Fan-out GloFAS fetch for unique lat/lon pairs (cached).
      final coords = <String, Map<String, double>>{};
      for (final s in biharRaw) {
        final lat = _d(s['latitude'] ?? s['lat']);
        final lon = _d(s['longitude'] ?? s['lon']);
        if (lat == null || lon == null) continue;
        final k = '${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';
        coords[k] = {'lat': lat, 'lon': lon};
      }
      await Future.wait(
        coords.entries.map((e) =>
            _ensureGloFas(e.key, e.value['lat']!, e.value['lon']!)),
        eagerError: false,
      );

      final results = <FloodData>[];
      for (final s in biharRaw) {
        final fd = _toFloodData(s as Map);
        if (fd != null) results.add(fd);
      }

      debugPrint('[IndiaStations] returning ${results.length} Bihar FloodData');
      return results;
    } catch (e) {
      debugPrint('[IndiaStations] error from $urlStr: $e');
      return null;
    }
  }

  // ── GloFAS helper ──────────────────────────────────────────────────────

  Future<void> _ensureGloFas(String key, double lat, double lon) async {
    if (_glofasCache[key]?.valid == true) return;
    try {
      final uri = Uri.parse(
        'https://flood-api.open-meteo.com/v1/flood'
        '?latitude=$lat&longitude=$lon'
        '&daily=river_discharge&past_days=4&forecast_days=1',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      if (!_isJsonBody(res.body)) return;
      final j    = jsonDecode(res.body) as Map<String, dynamic>;
      final vals = _doubles((j['daily'] as Map?)?['river_discharge']);
      if (vals.isEmpty) return;
      _glofasCache[key] = _CE({'discharge': vals.last});
    } catch (_) {}
  }

  double? _glofasFlow(dynamic lat, dynamic lon) {
    final la = _d(lat), lo = _d(lon);
    if (la == null || lo == null) return null;
    final k = '${la.toStringAsFixed(2)}:${lo.toStringAsFixed(2)}';
    return _d(_glofasCache[k]?.data['discharge']);
  }

  // ── FloodData builder ────────────────────────────────────────────────────

  FloodData? _toFloodData(Map raw) {
    final city  = raw['city']?.toString() ?? raw['station_name']?.toString() ?? raw['station']?.toString() ?? '';
    final state = raw['state']?.toString() ?? raw['state_name']?.toString() ?? '';
    if (city.isEmpty || state.isEmpty || !_isBihar(state)) return null;

    final current = _d(raw['current_level'] ?? raw['river_level']) ?? 0.0;
    if (current == 0.0) return null; // hide UNKNOWN stations
    final danger  = _d(raw['danger_level'])  ?? 0.0;
    final warning = _d(raw['warning_level']) ?? 0.0;
    final flow    = _d(raw['flow_rate'] ?? raw['river_discharge'])
                 ?? _glofasFlow(raw['latitude'] ?? raw['lat'],
                                raw['longitude'] ?? raw['lon']);
    final rain    = _d(raw['rainfall_24h']) ?? 0.0;

    return FloodData(
      stationId:     raw['station_id']?.toString() ?? '',
      stationName:   city,
      river:         raw['river_name']?.toString() ?? raw['river']?.toString() ?? '',
      city:          city,
      district:      raw['district']?.toString() ?? '',
      state:         state,
      riverName:     raw['river_name']?.toString() ?? raw['river']?.toString(),
      currentLevel:  current,
      warningLevel:  warning,
      dangerLevel:   danger,
      imdRainfallMm: rain,
      flowRate:      flow,
      lastUpdated:   DateTime.now(),
    );
  }

  double? _d(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString().trim()) ?? (v is num ? v.toDouble() : null);
  }

  List<double> _doubles(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e == null ? 0.0 : (e as num).toDouble()).toList();
  }
}

class _CE {
  final Map<String, dynamic> data;
  final DateTime at;
  _CE(this.data) : at = DateTime.now();
  bool get valid => DateTime.now().difference(at) < const Duration(minutes: 20);
}
