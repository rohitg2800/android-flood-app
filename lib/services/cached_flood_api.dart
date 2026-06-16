// lib/services/cached_flood_api.dart  v3
// Added: criticalAlerts() — returns cached alerts at or above warning level
// All other behaviour unchanged.
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'flood_api.dart';
import '../models/flood_data.dart';
import 'alert_engine.dart';

class CachedFloodApi {
  CachedFloodApi._();
  static final CachedFloodApi instance = CachedFloodApi._();

  static const _kCacheKey     = 'flood_data_cache_v3';
  static const _kCacheTtlMins = 10;

  List<FloodData> _cache = [];
  DateTime?       _lastFetched;

  // ─ Public API ─────────────────────────────────────────────────────────

  /// Fetch all stations, using in-memory cache if fresh.
  Future<List<FloodData>> getAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh()) return _cache;
    try {
      final fresh = await FloodApi.instance.fetchAll();
      _cache       = fresh;
      _lastFetched = DateTime.now();
      await _persist();
      return fresh;
    } catch (_) {
      if (_cache.isNotEmpty) return _cache;
      return await _loadFromDisk();
    }
  }

  /// Returns only stations that are at-or-above WARNING level (used by
  /// alerting pipelines, dashboards, and export services).
  Future<List<FloodData>> criticalAlerts({bool forceRefresh = false}) async {
    final all = await getAll(forceRefresh: forceRefresh);
    return all.where((d) {
      final level = d.currentLevel;
      return level >= d.warningLevel;
    }).toList()
      ..sort((a, b) =>
          b.currentLevel.compareTo(a.currentLevel));
  }

  /// Evict in-memory and on-disk cache.
  Future<void> invalidate() async {
    _cache       = [];
    _lastFetched = null;
    final prefs  = await SharedPreferences.getInstance();
    await prefs.remove(_kCacheKey);
  }

  bool get isCacheAvailable => _cache.isNotEmpty;
  DateTime? get lastFetched  => _lastFetched;

  // ─ Internals ─────────────────────────────────────────────────────────

  bool _isFresh() {
    if (_lastFetched == null || _cache.isEmpty) return false;
    return DateTime.now().difference(_lastFetched!) <
        const Duration(minutes: _kCacheTtlMins);
  }

  Future<void> _persist() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
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
      return list.map((e) => FloodData.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
