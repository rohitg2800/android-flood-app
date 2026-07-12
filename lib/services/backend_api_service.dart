// lib/services/backend_api_service.dart  v4.0
//
// OpsFlood — Single backend HTTP client
//
// v4.0 changes:
//   • All GET calls now route through OpsClient (retry + backoff on 503,
//     fast-fail on 404, timeout managed centrally via AppConfig)
//   • POST calls route through OpsClient.post()
//   • Removed local _kConnectTimeout / _kPushTimeout — OpsClient owns timeouts
//   • Removed raw http.get / http.post imports — OpsClient is the transport

import 'dart:convert';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'ops_client.dart';

// ── BackendApiService ────────────────────────────────────────────────────────
class BackendApiService {
  BackendApiService._();
  static final BackendApiService instance = BackendApiService._();

  OpsClient get _ops => OpsClient.instance;
  String get baseUrl => AppConfig.baseUrl;

  // ─────────────────────────────────────────────────────────────────────────
  // PULL endpoints
  // ─────────────────────────────────────────────────────────────────────────

  // GET /api/live-levels?state=...
  Future<List<Map<String, dynamic>>> fetchLiveLevels(String state) async {
    _log('GET /api/live-levels?state=$state');
    final body = await _ops.get(
      '/api/live-levels',
      query: {'state': state},
    );
    return _parseList(body, 'live-levels');
  }

  // GET /api/live-levels?with_severity=true
  Future<List<Map<String, dynamic>>> fetchLiveLevelsWithSeverity({
    int limit = 300,
  }) async {
    _log('GET /api/live-levels?with_severity=true&limit=$limit');
    final body = await _ops.get(
      '/api/live-levels',
      query: {'with_severity': 'true', 'limit': '$limit'},
    );
    return _parseList(body, 'live-levels-severity');
  }

  // GET /api/river-severity
  Future<Map<String, dynamic>> fetchRiverSeverity({
    String? state,
    String? district,
    String? river,
    int? minRiskScore,
    int limit = 200,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (state != null) params['state'] = state;
    if (district != null) params['district'] = district;
    if (river != null) params['river'] = river;
    if (minRiskScore != null) params['min_risk_score'] = '$minRiskScore';
    _log('GET /api/river-severity $params');
    final body = await _ops.get('/api/river-severity', query: params);
    return body; // OpsClient.get() always returns Map<String,dynamic>
  }

  // GET /api/glofas?lats=...&lons=...&cities=...
  // GET /api/news?state=...
  Future<List<Map<String, dynamic>>> fetchGloFAS({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    _log('GET /api/glofas (${cityKeys.length} cities, batched)');
    return _batchedFetch('/api/glofas', lats, lons, cityKeys, 'glofas');
  }

  // GET /api/rainfall?lats=...&lons=...&cities=...
  Future<List<Map<String, dynamic>>> fetchRainfall({
    required List<double> lats,
    required List<double> lons,
    required List<String> cityKeys,
  }) async {
    _log('GET /api/rainfall (${cityKeys.length} cities, batched)');
    return _batchedFetch('/api/rainfall', lats, lons, cityKeys, 'rainfall');
  }

  // Shared chunked fetcher — splits into groups of 15 to stay under timeout
  Future<List<Map<String, dynamic>>> _batchedFetch(
    String path,
    List<double> lats,
    List<double> lons,
    List<String> cityKeys,
    String listKey, {
    int chunkSize = 15,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < cityKeys.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, cityKeys.length);
      final cLats = lats.sublist(i, end);
      final cLons = lons.sublist(i, end);
      final cKeys = cityKeys.sublist(i, end);
      try {
        final body = await _ops.get(path, query: {
          'lats': cLats.join(','),
          'lons': cLons.join(','),
          'cities': cKeys.join(',').toLowerCase(),
        });
        results.addAll(_parseList(body, listKey));
      } catch (e) {
        _log('$path batch $i–$end failed: $e');
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> fetchNews({required String state}) async {
    _log('GET /api/news?state=$state');
    final body = await _ops.get('/api/news', query: {'state': state});
    // OpsClient.get() always returns Map<String,dynamic>
    if (body['items'] is List) {
      return (body['items'] as List).whereType<Map<String, dynamic>>().toList();
    }
    if (body['data'] is List) {
      return (body['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    throw FormatException('news: unexpected response shape');
  }

  // GET /api/cwc-stations?codes=...
  Future<List<Map<String, dynamic>>> fetchCwcStations({
    required List<String> codes,
  }) async {
    if (codes.isEmpty) return [];
    _log('GET /api/cwc-stations?codes=${codes.join(',')}');
    final body = await _ops.get(
      '/api/cwc-stations',
      query: {'codes': codes.join(',')},
    );
    return _parseList(body, 'cwc-stations');
  }

  // GET /health
  Future<Map<String, dynamic>> checkHealth() async {
    _log('GET /health');
    return await _ops.get('/health');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUSH endpoints  (v3.0+)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> postGaugeTelemetry(
          Map<String, dynamic> payload) async =>
      _ops.post('/api/gauge-telemetry', payload);

  Future<Map<String, dynamic>> postRtdasThresholds(
          Map<String, dynamic> payload) async =>
      _ops.post('/api/rtdas-thresholds', payload);

  Future<Map<String, dynamic>> postFloodEvents(
          Map<String, dynamic> payload) async =>
      _ops.post('/api/flood-events', payload);

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Handles both bare-List and wrapped {data:[...]} / {stations:[...]} shapes.
  List<Map<String, dynamic>> _parseList(dynamic body, String tag) {
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    if (body is Map) {
      if (body['data'] is List)
        return (body['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      if (body['stations'] is List)
        return (body['stations'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
    }
    throw FormatException('$tag: unexpected response shape');
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[BackendApi] $msg');
  }
}
