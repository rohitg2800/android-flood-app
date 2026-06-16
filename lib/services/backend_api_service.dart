// lib/services/backend_api_service.dart  v3.1
//
// OpsFlood — Single backend HTTP client
//
// v3.0 added PUSH endpoints:
//   POST /api/gauge-telemetry   — full station snapshot
//   POST /api/rtdas-thresholds  — scraped RTDAS thresholds
//   POST /api/flood-events      — critical / danger station events
//
// v3.1 changes:
//   • Removed bare 'library;' directive (caused analysis warning)
//   • fetchLiveLevelsWithSeverity() — GET /api/live-levels?with_severity=true
//     called by LiveFetchEngine v4.2 to merge ML fields per city
//   • fetchRiverSeverity() — GET /api/river-severity
//     bulk ML severity endpoint; used by map/list screens directly

import 'dart:convert';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Backend URL ────────────────────────────────────────────────────────────────
// Base URL via AppConfig.baseUrl

// ── Timeouts ──────────────────────────────────────────────────────────────────
const Duration _kConnectTimeout = Duration(seconds: 30);
const Duration _kPushTimeout    = Duration(seconds: 20);

// ── BackendApiService ────────────────────────────────────────────────────────
class BackendApiService {
  BackendApiService._();
  static final BackendApiService instance = BackendApiService._();

  String get baseUrl => AppConfig.baseUrl;

  // ─────────────────────────────────────────────────────────────────────────
  // PULL endpoints
  // ─────────────────────────────────────────────────────────────────────────

  // GET /api/live-levels?state=...
  Future<List<Map<String, dynamic>>> fetchLiveLevels(String state) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/live-levels'
        '?state=${Uri.encodeComponent(state)}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'live-levels');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    if (body is Map) {
      if (body['data']     is List) return (body['data']     as List).whereType<Map<String,dynamic>>().toList();
      if (body['stations'] is List) return (body['stations'] as List).whereType<Map<String,dynamic>>().toList();
    }
    throw FormatException('live-levels: unexpected response shape');
  }

  // GET /api/live-levels?with_severity=true
  //
  // Returns ALL cities (no state filter) with ML severity fields attached.
  // Called once per poll cycle by LiveFetchEngine v4.2 to enrich the cache.
  Future<List<Map<String, dynamic>>> fetchLiveLevelsWithSeverity({
    int limit = 300,
  }) async {
    final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/live-levels?with_severity=true&limit=$limit');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'live-levels-severity');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    if (body is Map) {
      if (body['data']     is List) return (body['data']     as List).whereType<Map<String,dynamic>>().toList();
      if (body['stations'] is List) return (body['stations'] as List).whereType<Map<String,dynamic>>().toList();
    }
    throw FormatException('live-levels-severity: unexpected response shape');
  }

  // GET /api/river-severity
  //
  // Bulk ML severity predictions for all live stations.
  // Returned list is already sorted highest-risk-first by the backend.
  //
  // Optional filters:
  //   state        — e.g. "Bihar"
  //   district     — e.g. "Muzaffarpur"
  //   river        — e.g. "Gandak"
  //   minRiskScore — only cities with risk_score >= this value
  //   limit        — max records (default 200)
  //
  // Each record includes:
  //   city, state, river_name, district, station, lat, lon,
  //   current_level, danger_level, warning_level, capacity_percent, trend,
  //   predicted_severity, risk_score, confidence_percent,
  //   will_breach_danger, peak_level_72h,
  //   algorithm, model_version, data_source, timestamp
  Future<Map<String, dynamic>> fetchRiverSeverity({
    String? state,
    String? district,
    String? river,
    int?    minRiskScore,
    int     limit = 200,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (state        != null) params['state']          = state;
    if (district     != null) params['district']       = district;
    if (river        != null) params['river']          = river;
    if (minRiskScore != null) params['min_risk_score'] = '$minRiskScore';

    final uri = Uri.parse('${AppConfig.baseUrl}/api/river-severity')
        .replace(queryParameters: params);
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'river-severity');
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    throw FormatException('river-severity: expected JSON object');
  }

  // GET /api/glofas?lats=...&lons=...&cities=...
  Future<List<Map<String, dynamic>>> fetchGloFAS({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/glofas'
        '?lats=${lats.join(',')}&lons=${lons.join(',')}&cities=${cityKeys.join(',').toLowerCase()}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'glofas');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    throw FormatException('glofas: unexpected response shape');
  }

  // GET /api/rainfall?lats=...&lons=...&cities=...
  Future<List<Map<String, dynamic>>> fetchRainfall({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/rainfall'
        '?lats=${lats.join(',')}&lons=${lons.join(',')}&cities=${cityKeys.join(',').toLowerCase()}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'rainfall');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    throw FormatException('rainfall: unexpected response shape');
  }

  // GET /api/news?state=...
  Future<List<Map<String, dynamic>>> fetchNews({required String state}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/news'
        '?state=${Uri.encodeComponent(state)}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'news');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    if (body is Map && body['items'] is List) {
      return (body['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    throw FormatException('news: unexpected response shape');
  }

  // GET /api/cwc-stations?codes=...
  Future<List<Map<String, dynamic>>> fetchCwcStations({
    required List<String> codes,
  }) async {
    if (codes.isEmpty) return [];
    final uri = Uri.parse('${AppConfig.baseUrl}/api/cwc-stations'
        '?codes=${codes.join(',')}');
    _log('GET $uri');
    final res = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'cwc-stations');
    final body = jsonDecode(res.body);
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    throw FormatException('cwc-stations: unexpected response shape');
  }

  // GET /health
  Future<Map<String, dynamic>> checkHealth() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/health');
    final res  = await http.get(uri).timeout(_kConnectTimeout);
    _assertOk(res, 'health');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUSH endpoints  (v3.0+)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> postGaugeTelemetry(Map<String, dynamic> payload) async =>
      _post('gauge-telemetry', payload);

  Future<Map<String, dynamic>> postRtdasThresholds(Map<String, dynamic> payload) async =>
      _post('rtdas-thresholds', payload);

  Future<Map<String, dynamic>> postFloodEvents(Map<String, dynamic> payload) async =>
      _post('flood-events', payload);

  // ── internal POST helper ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> payload) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/$path');
    _log('POST $uri (${jsonEncode(payload).length} bytes)');
    final res = await http
        .post(uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-App-Source': 'OpsFlood-Android/3',
            },
            body: jsonEncode(payload))
        .timeout(_kPushTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {'ok': true};
      }
    }
    _log('POST /$path → HTTP ${res.statusCode} (non-fatal)');
    return {'ok': false, 'status': res.statusCode};
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  void _assertOk(http.Response res, String tag) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('[$tag] HTTP ${res.statusCode}: '
          '${res.body.substring(0, res.body.length.clamp(0, 200))}');
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[BackendApi] $msg');
  }
}
