// lib/services/flood_api.dart
//
// OpsFlood — FloodApi
//
// All OpsFlood backend endpoints that returned 404 are STUBBED.
// Active endpoints that still work:
//   - /predict/v2              → backendPredict() in prediction_service.dart
//   - /health                  → only called from predict path (not polling)
//
// Everything else returns {'status': 'ok', 'data': []} so callers
// that haven't been updated yet never throw or 404.
//
// Real data comes from:
//   WrdBiharService   → irrigation.befiqr.in / beams.fmiscwrdbihar.gov.in
//   GloFAS            → flood-api.open-meteo.com
//   Open-Meteo        → api.open-meteo.com
//   CwcDirectService  → cwc.gov.in (station HTML scrape)
//   SACHET/NDMA       → sachet.ndma.gov.in (live_fetch_engine)
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/flood_station.dart';
import 'ops_client.dart';

const _kEmpty = <String, dynamic>{'status': 'ok', 'data': <dynamic>[]};

// File: lib/services/flood_api.dart
// Updated: June 2026
// Changes: Implemented live levels, station history, and critical alerts fetchers (2-phase ready for provider patching).

class FloodApi {
  FloodApi._();
  static final FloodApi instance = FloodApi._();

  final _c = OpsClient.instance;


  // ── Health (only used by predict path, not polling) ───────────────────────
  // FIX: pass path-only string, NOT AppConfig.epHealth (full URL).
  // OpsClient._buildUri() prepends baseUrl — passing a full URL doubled it → 404.
  Future<Map<String, dynamic>> healthCheck({bool coldStart = false}) =>
      _c.get(
        '/health',
        timeout: coldStart ? AppConfig.coldStartTimeout : AppConfig.healthTimeout,
      );

  // ── Prediction (ML inference) ─────────────────────────────────────────────
  // FIX: pass path-only '/predict/v2', NOT AppConfig.epPredict (full URL).
  Future<Map<String, dynamic>> predict(Map<String, dynamic> payload) =>
      _c.post('/predict/v2', payload);

  // ── STUBBED — backend endpoints that no longer exist ─────────────────────
  // Return empty but valid payloads so callers don't crash or retry.

  Future<Map<String, dynamic>> allTelemetry({int limit = 1000}) async => _kEmpty;

  Future<Map<String, dynamic>> telemetryByState(
    String state, {String? station, int limit = 50}) async => _kEmpty;

  Future<Map<String, dynamic>> allLevels({int limit = 200}) async => _kEmpty;

  Future<Map<String, dynamic>> levelsByState(
    String state, {int limit = 200}) async => _kEmpty;


  Future<Map<String, dynamic>> cwcForecast({
    required String city, required String state}) async => _kEmpty;

  Future<Map<String, dynamic>> cwcStations() async => _kEmpty;

  Future<Map<String, dynamic>> reservoirLevels(String state) async => _kEmpty;

  Future<Map<String, dynamic>> pipelineFeatures({
    required String state, String? station}) async => _kEmpty;

  Future<Map<String, dynamic>> pipelineManifest() async => _kEmpty;

  Future<Map<String, dynamic>> stateSeverity() async => _kEmpty;

  Future<Map<String, dynamic>> stateSeverityEntry(String state) async => _kEmpty;

  Future<Map<String, dynamic>> triggerIngestion() async => _kEmpty;

  Future<Map<String, dynamic>> modelMetrics() async => _kEmpty;

  Future<Map<String, dynamic>> ndmaAdvisories(String state) async => _kEmpty;

  Future<Map<String, dynamic>> ndmaContacts(String state) async => _kEmpty;

  // ── Weather — direct Open-Meteo (no backend proxy) ───────────────────────
  // Used by screens that call FloodApi.weatherCurrent/weatherForecast directly.
  // Calls Open-Meteo free tier — no auth needed.
  Future<Map<String, dynamic>> weatherCurrent(String location) async {
    try {
      // Resolve city name to lat/lon via Open-Meteo geocoding
      final geoUri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(location)}&count=1&language=en&format=json',
      );
      final geoRes = await http.get(geoUri).timeout(const Duration(seconds: 8));
      if (geoRes.statusCode != 200) return _kEmpty;
      final geoBody  = jsonDecode(geoRes.body) as Map<String, dynamic>;
      final results  = geoBody['results'] as List?;
      if (results == null || results.isEmpty) return _kEmpty;
      final r   = results.first as Map<String, dynamic>;
      final lat = r['latitude']  as num;
      final lon = r['longitude'] as num;

      final wxUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code'
        '&timezone=Asia%2FKolkata',
      );
      final wxRes = await http.get(wxUri).timeout(const Duration(seconds: 8));
      if (wxRes.statusCode != 200) return _kEmpty;
      return jsonDecode(wxRes.body) as Map<String, dynamic>;
    } catch (_) {
      return _kEmpty;
    }
  }

  Future<Map<String, dynamic>> weatherForecast(String location) async {
    try {
      final geoUri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(location)}&count=1&language=en&format=json',
      );
      final geoRes = await http.get(geoUri).timeout(const Duration(seconds: 8));
      if (geoRes.statusCode != 200) return _kEmpty;
      final geoBody = jsonDecode(geoRes.body) as Map<String, dynamic>;
      final results = geoBody['results'] as List?;
      if (results == null || results.isEmpty) return _kEmpty;
      final r   = results.first as Map<String, dynamic>;
      final lat = r['latitude']  as num;
      final lon = r['longitude'] as num;

      final fxUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code'
        '&forecast_days=7&timezone=Asia%2FKolkata',
      );
      final fxRes = await http.get(fxUri).timeout(const Duration(seconds: 8));
      if (fxRes.statusCode != 200) return _kEmpty;
      return jsonDecode(fxRes.body) as Map<String, dynamic>;
    } catch (_) {
      return _kEmpty;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LIVE LEVELS — GloFAS 261-city feed (Task 1 — June 2026)
  // ═══════════════════════════════════════════════════════════════

  // Phase 1: fast fetch, no ML severity — call first, render map immediately
  Future<List<FloodStation>> fetchLiveLevels() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/live-levels?limit=300&with_severity=false',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().map(FloodStation.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  // Phase 2: background severity patch — silently called after map renders
  Future<List<FloodStation>> fetchLiveLevelsSeverity() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/live-levels?limit=300&with_severity=true',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().map(FloodStation.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  // Station 7-day history
  Future<List<Map<String, dynamic>>> fetchStationHistory(
    String city, {
    int days = 7,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/station-history'
        '?city=${Uri.encodeComponent(city)}&days=$days',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  // Critical alerts — typed, replaces stub criticalAlerts()
  Future<List<FloodStation>> fetchCriticalAlerts() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/critical-alerts');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().map(FloodStation.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LIVE LEVELS — GloFAS 261-city feed (Task 1 — June 2026)
  // ═══════════════════════════════════════════════════════════════

  Future<List<FloodStation>> fetchLiveLevels() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/live-levels?limit=300&with_severity=false',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().map(FloodStation.fromJson).toList();
    } catch (_) { return []; }
  }

  Future<List<FloodStation>> fetchLiveLevelsSeverity() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/live-levels?limit=300&with_severity=true',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().map(FloodStation.fromJson).toList();
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> fetchStationHistory(
    String city, {int days = 7}) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/station-history'
        '?city=${Uri.encodeComponent(city)}&days=$days',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) { return []; }
  }

  Future<List<FloodStation>> fetchCriticalAlerts() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/critical-alerts');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final list = (body is List) ? body : (body['data'] as List? ?? []);
      return list.whereType<Map<String, dynamic>>().map(FloodStation.fromJson).toList();
    } catch (_) { return []; }
  }
}
