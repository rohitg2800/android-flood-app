// lib/services/local_cache_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flood_data.dart';

class LocalCacheService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const _keyStations  = 'cached_stations';
  static const _keyCachedAt  = 'cached_at';
  static const _keyGaugeList = 'cached_gauge_list';
  static const _keyGaugeHist = 'gauge_history_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Call once before using synchronous getters (isFresh, lastSavedAt).
  Future<void> init() async => await _p;

  /// TEST ONLY — clears the cached SharedPreferences reference so that
  /// SharedPreferences.setMockInitialValues() takes effect in the next init().
  @visibleForTesting
  void resetForTesting() => _prefs = null;

  // ── Station map helpers (used by UI) ────────────────────────────────────────

  Future<void> saveStations(List<Map<String, dynamic>> stations) async {
    final p = await _p;
    await p.setString(_keyStations, jsonEncode(stations));
    await setTimestamp(_keyCachedAt);
  }

  Future<List<Map<String, dynamic>>> loadStations() async {
    final p = await _p;
    final raw = p.getString(_keyStations);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<bool> hasCache() async {
    final p = await _p;
    return p.containsKey(_keyStations);
  }

  Future<void> clearCache() async {
    final p = await _p;
    await p.remove(_keyStations);
    await p.remove(_keyCachedAt);
  }

  // ── FloodData gauge list (called by background_service) ─────────────────────

  Future<void> saveGaugeList(List<FloodData> gauges) async {
    final p = await _p;
    await p.setString(
      _keyGaugeList,
      jsonEncode(gauges.map((g) => g.toJson()).toList()),
    );
    await setTimestamp(_keyCachedAt);
  }

  Future<List<FloodData>> loadGaugeList() async {
    final p = await _p;
    final raw = p.getString(_keyGaugeList);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => FloodData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Gauge history for sparklines (called by background_service) ──────────────

  /// Appends [level] to the rolling 48-point history for [stationId].
  Future<void> appendGaugeHistory(String stationId, double level) async {
    final p   = await _p;
    final key = '$_keyGaugeHist$stationId';
    final raw = p.getString(key);
    final history = raw != null
        ? List<double>.from(
            (jsonDecode(raw) as List).cast<num>().map((n) => n.toDouble()),
          )
        : <double>[];
    history.add(level);
    if (history.length > 48) history.removeRange(0, history.length - 48);
    await p.setString(key, jsonEncode(history));
  }

  Future<List<double>> loadGaugeHistory(String stationId) async {
    final p   = await _p;
    final raw = p.getString('$_keyGaugeHist$stationId');
    if (raw == null) return [];
    return List<double>.from(
      (jsonDecode(raw) as List).cast<num>().map((n) => n.toDouble()),
    );
  }

  // ── Generic timestamp helpers ────────────────────────────────────────────────

  Future<void> setTimestamp(String key) async {
    final p = await _p;
    await p.setString(key, DateTime.now().toIso8601String());
  }

  Future<void> setRaw(String key, String isoValue) async {
    final p = await _p;
    await p.setString(key, isoValue);
  }

  bool isFresh(String key, Duration maxAge) {
    final raw = _prefs?.getString(key);
    if (raw == null) return false;
    final saved = DateTime.tryParse(raw);
    if (saved == null) return false;
    return DateTime.now().difference(saved) <= maxAge;
  }

  DateTime? get lastSavedAt {
    final raw = _prefs?.getString(_keyCachedAt);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<DateTime?> getCachedAt() async {
    final p   = await _p;
    final raw = p.getString(_keyCachedAt);
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}
