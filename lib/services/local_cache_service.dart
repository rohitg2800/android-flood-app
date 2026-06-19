import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const _keyStations = 'cached_stations';
  static const _keyCachedAt = 'cached_at';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Call this once before using synchronous methods (isFresh, lastSavedAt).
  /// In tests, SharedPreferences mock is synchronous so this resolves instantly.
  Future<void> init() async => await _p;

  // ── Station helpers ──────────────────────────────────────────────────────────

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
    final p = await _p;
    final raw = p.getString(_keyCachedAt);
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}
