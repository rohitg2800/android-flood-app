// lib/services/cached_flood_api.dart
// OpsFlood — Cache-Aware FloodApi Wrapper
// Stale-while-revalidate strategy using LocalCacheService.
//
// fix: LocalCacheService uses getString/setString/remove/clear — not
// read/write/delete/clearAll. All calls updated to match actual API.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'flood_api.dart';
import 'local_cache_service.dart';

class CachedFloodApi {
  CachedFloodApi._();
  static final CachedFloodApi instance = CachedFloodApi._();

  final _api   = FloodApi.instance;
  final _cache = LocalCacheService.instance;

  static const Duration _freshTtl = Duration(minutes: 5);

  static String _tsKey(String key) => '${key}__ts';

  // ── Generic cache-aware GET wrapper ───────────────────────────────────────
  Future<Map<String, dynamic>> _cached(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetcher, {
    bool bypassCache = false,
  }) async {
    if (!bypassCache) {
      final raw = _cache.getString(cacheKey);          // was: _cache.read()
      if (raw != null) {
        final isStale = !_cache.isFresh(_tsKey(cacheKey), _freshTtl);
        if (!isStale) {
          _log('cache HIT  $cacheKey');
          return _decode(raw);
        } else {
          _log('cache STALE $cacheKey — revalidating in background');
          _revalidate(cacheKey, fetcher);
          return _decode(raw);
        }
      }
    }
    _log('cache MISS  $cacheKey');
    return _fetchAndStore(cacheKey, fetcher);
  }

  Future<Map<String, dynamic>> _fetchAndStore(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetcher,
  ) async {
    final result = await fetcher();
    if (result['status'] != 'error') {
      await _cache.setString(cacheKey, jsonEncode(result)); // was: _cache.write()
      await _cache.setNow(_tsKey(cacheKey));
    }
    return result;
  }

  void _revalidate(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetcher,
  ) {
    _fetchAndStore(cacheKey, fetcher).catchError((e) {
      _log('revalidation error for $cacheKey: $e');
      return <String, dynamic>{'status': 'error', 'error': '$e'};
    });
  }

  // ── Public API ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> allTelemetry({int limit = 1000}) =>
      _cached('live_telemetry_all_$limit', () => _api.allTelemetry(limit: limit));

  Future<Map<String, dynamic>> telemetryByState(String state, {String? station, int limit = 50}) =>
      _cached('live_telemetry_${state}_${station ?? ''}_$limit',
          () => _api.telemetryByState(state, station: station, limit: limit));

  Future<Map<String, dynamic>> allLevels({int limit = 200}) =>
      _cached('live_levels_all_$limit', () => _api.allLevels(limit: limit));

  Future<Map<String, dynamic>> levelsByState(String state, {int limit = 200}) =>
      _cached('live_levels_${state}_$limit', () => _api.levelsByState(state, limit: limit));

  Future<Map<String, dynamic>> criticalAlerts() =>
      _cached('critical_alerts', () => _api.criticalAlerts());

  Future<Map<String, dynamic>> cwcForecast({required String city, required String state}) =>
      _cached('cwc_ffs_${city}_$state', () => _api.cwcForecast(city: city, state: state));

  Future<Map<String, dynamic>> cwcStations() =>
      _cached('cwc_stations', () => _api.cwcStations());

  Future<Map<String, dynamic>> reservoirLevels(String state) =>
      _cached('cwc_reservoir_$state', () => _api.reservoirLevels(state));

  Future<Map<String, dynamic>> weatherCurrent(String location) =>
      _cached('weather_current_$location', () => _api.weatherCurrent(location));

  Future<Map<String, dynamic>> weatherForecast(String location) =>
      _cached('weather_forecast_$location', () => _api.weatherForecast(location));

  Future<Map<String, dynamic>> pipelineFeatures({required String state, String? station}) =>
      _cached('pipeline_features_${state}_${station ?? ''}',
          () => _api.pipelineFeatures(state: state, station: station));

  Future<Map<String, dynamic>> stateSeverity() =>
      _cached('state_severity', () => _api.stateSeverity());

  Future<Map<String, dynamic>> predict(Map<String, dynamic> payload) =>
      _api.predict(payload);

  Future<Map<String, dynamic>> triggerIngestion() =>
      _api.triggerIngestion();

  Future<void> invalidate(String cacheKey) async {
    await _cache.remove(cacheKey);          // was: _cache.delete()
    await _cache.remove(_tsKey(cacheKey));  // was: _cache.delete()
  }

  Future<void> clearAll() => _cache.clear(); // was: _cache.clearAll()

  // ── Helpers ────────────────────────────────────────────────────────────────
  Map<String, dynamic> _decode(String json) {
    try {
      final parsed = jsonDecode(json);
      return parsed is Map<String, dynamic>
          ? parsed : {'status': 'success', 'data': parsed};
    } catch (_) {
      return {'status': 'error', 'error': 'Cache decode failed'};
    }
  }

  void _log(String msg) {
    if (AppConfig.isDebugLogging || !AppConfig.isProduction) {
      debugPrint('[CachedFloodApi] $msg');
    }
  }
}
