// lib/services/cached_flood_api.dart  v4
// Fixed: fetchAll() → fetchLiveLevels() (FloodApi has no fetchAll)
// Added: criticalAlerts() returning List<FloodData> filtered by warningLevel
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'flood_api.dart';
import '../models/flood_data.dart';
import '../models/flood_station.dart';

class CachedFloodApi {
  CachedFloodApi._();
  static final CachedFloodApi instance = CachedFloodApi._();

  static const _kCacheKey     = 'flood_data_cache_v4';
  static const _kCacheTtlMins = 10;

  List<FloodData> _cache = [];
  DateTime?       _lastFetched;

  // ─ Public API ────────────────────────────────────────────────────────────────

  Future<List<FloodData>> getAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh()) return _cache;
    try {
      final stations = await FloodApi.instance.fetchLiveLevels();
      final fresh    = _stationsToFloodData(stations);
      _cache       = fresh;
      _lastFetched = DateTime.now();
      await _persist();
      return fresh;
    } catch (_) {
      if (_cache.isNotEmpty) return _cache;
      return await _loadFromDisk();
    }
  }

  Future<List<FloodData>> criticalAlerts({bool forceRefresh = false}) async {
    final all = await getAll(forceRefresh: forceRefresh);
    return all
        .where((d) => d.currentLevel >= d.warningLevel)
        .toList()
      ..sort((a, b) => b.currentLevel.compareTo(a.currentLevel));
  }

  Future<void> invalidate() async {
    _cache       = [];
    _lastFetched = null;
    final prefs  = await SharedPreferences.getInstance();
    await prefs.remove(_kCacheKey);
  }

  bool      get isCacheAvailable => _cache.isNotEmpty;
  DateTime? get lastFetched      => _lastFetched;

  // ─ Internals ─────────────────────────────────────────────────────────────────

  bool _isFresh() =>
      _lastFetched != null &&
      _cache.isNotEmpty &&
      DateTime.now().difference(_lastFetched!) <
          const Duration(minutes: _kCacheTtlMins);

  static List<FloodData> _stationsToFloodData(List<FloodStation> stations) =>
      stations.map((s) => FloodData(
        stationId:    s.city,
        stationName:  s.city,
        river:        s.river,
        district:     s.city,
        state:        s.state,
        currentLevel: s.currentLevel,
        dangerLevel:  s.dangerLevel,
        warningLevel: s.warningLevel,
        latitude:     s.lat,
        longitude:    s.lon,
        hfl:          s.hfl,
        source:       'GloFAS',
        lastUpdated:  DateTime.now(),
      )).toList();

  Future<void> _persist() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cache.map((d) => d.toJson()).toList());
      await prefs.setString(_kCacheKey, encoded);
    } catch (_) {}
  }

  Future<List<FloodData>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kCacheKey);
      if (raw == null) return [];
      final list  = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FloodData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
