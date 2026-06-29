// lib/services/local_cache_service.dart  Step 4.3
// Hive-backed local cache.
//
// v4.5 — added resetForTesting() so unit tests can fully reset singleton state
//         between test cases without needing Hive to be initialised.

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/flood_data.dart';

const _kGaugeBox      = 'gauge_cache';
const _kHistoryBox    = 'gauge_history';
const _kKvBox         = 'kv_cache'; // generic key→value store
const _kTimestampKey  = '__saved_at';
const _kStaleMinutes  = 30;
const _kMaxHistoryDays = 7;

class LocalCacheService {
  LocalCacheService._();

  /// Public constructor for sub-classing / mocking in tests across library
  /// boundaries.  Production code always uses [instance].
  @visibleForTesting
  LocalCacheService.forTesting();

  static LocalCacheService _instance = LocalCacheService._();
  static LocalCacheService get instance => _instance;

  // ── Test helpers ─────────────────────────────────────────────────────────

  /// Replace the singleton with a custom instance (e.g. a mock subclass).
  @visibleForTesting
  static void setInstanceForTesting(LocalCacheService mock) {
    _instance = mock;
  }

  /// Wipe all in-memory box references and reset the singleton back to a
  /// fresh, uninitialised state.  Call this in [setUp] / [tearDown] of unit
  /// tests so each test starts from a clean slate without requiring Hive to
  /// be fully initialised via [Hive.initFlutter].
  @visibleForTesting
  void resetForTesting() {
    _gaugeBox   = null;
    _historyBox = null;
    _kvBox      = null;
    // Reset the singleton so the next [instance] access gets a blank service.
    _instance = LocalCacheService._();
  }

  // ── Private state ────────────────────────────────────────────────────────

  Box? _gaugeBox;
  Box? _historyBox;
  Box? _kvBox;

  Future<void> init() async {
    _gaugeBox   ??= await Hive.openBox(_kGaugeBox);
    _historyBox ??= await Hive.openBox(_kHistoryBox);
    _kvBox      ??= await Hive.openBox(_kKvBox);
  }

  // ── Generic KV API (used by CachedFloodApi + OpsfloodDbService) ──────────

  /// Read a raw string value by key. Returns null if missing.
  String? getString(String key) => _kvBox?.get(key) as String?;

  /// Write a raw string value.
  Future<void> setString(String key, String value) async {
    await init();
    await _kvBox!.put(key, value);
  }

  /// Store DateTime.now() as an ISO timestamp under [key].
  Future<void> setNow(String key) async {
    await init();
    await _kvBox!.put(key, DateTime.now().toIso8601String());
  }

  /// Returns true if the timestamp stored at [tsKey] is within [ttl].
  bool isFresh(String tsKey, Duration ttl) {
    final raw = _kvBox?.get(tsKey) as String?;
    if (raw == null) return false;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return false;
    return DateTime.now().difference(dt) < ttl;
  }

  /// Delete a single key from the KV store.
  Future<void> remove(String key) async {
    await init();
    await _kvBox!.delete(key);
  }

  /// Clear ALL entries from the KV store.
  Future<void> clear() async {
    await init();
    await _kvBox!.clear();
  }

  // ── Gauge list ────────────────────────────────────────────────────────────

  Future<void> saveGaugeList(List<FloodData> gauges) async {
    await init();
    try {
      final encoded = jsonEncode(gauges.map((g) => g.toJson()).toList());
      await _gaugeBox!.put('gauges', encoded);
      await _gaugeBox!.put(_kTimestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[Cache] save error: $e');
    }
  }

  Future<({List<FloodData> data, bool isStale})> loadGaugeList() async {
    await init();
    try {
      final raw = _gaugeBox!.get('gauges') as String?;
      if (raw == null) return (data: <FloodData>[], isStale: true);

      final savedAt = _gaugeBox!.get(_kTimestampKey) as String?;
      bool stale = true;
      if (savedAt != null) {
        final dt   = DateTime.tryParse(savedAt);
        final diff = dt != null
            ? DateTime.now().difference(dt).inMinutes
            : 9999;
        stale = diff > _kStaleMinutes;
      }

      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => FloodData.fromJson(e as Map<String, dynamic>))
          .toList();
      return (data: list, isStale: stale);
    } catch (e) {
      debugPrint('[Cache] load error: $e');
      return (data: <FloodData>[], isStale: true);
    }
  }

  DateTime? get lastSavedAt {
    final raw = _gaugeBox?.get(_kTimestampKey) as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  // ── 7-day gauge level history ─────────────────────────────────────────────

  Future<void> appendGaugeHistory(
      String stationId, double currentLevel) async {
    await init();
    try {
      final raw     = _historyBox!.get(stationId) as String?;
      final entries = raw != null
          ? (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      entries.add({
        'ts':    DateTime.now().toIso8601String(),
        'level': currentLevel,
      });

      final cutoff = DateTime.now()
          .subtract(const Duration(days: _kMaxHistoryDays));
      final pruned = entries.where((e) {
        final dt = DateTime.tryParse(e['ts'] as String? ?? '');
        return dt != null && dt.isAfter(cutoff);
      }).toList();

      await _historyBox!.put(stationId, jsonEncode(pruned));
    } catch (e) {
      debugPrint('[Cache] history append error: $e');
    }
  }

  Future<List<(DateTime, double)>> loadGaugeHistory(String stationId) async {
    await init();
    try {
      final raw = _historyBox!.get(stationId) as String?;
      if (raw == null) return [];
      final entries = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      return entries.map((e) {
        final dt    = DateTime.parse(e['ts'] as String);
        final level = (e['level'] as num).toDouble();
        return (dt, level);
      }).toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
    } catch (e) {
      debugPrint('[Cache] history load error: $e');
      return [];
    }
  }
}
