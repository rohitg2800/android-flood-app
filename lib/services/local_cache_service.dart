// lib/services/local_cache_service.dart  Step 4.3
// Hive-backed local cache:
//   • saveGaugeList / loadGaugeList  — persists the latest FloodData list
//   • appendGaugeHistory / loadGaugeHistory — 7-day rolling level history
//   • isStale flag: true if cache is older than 30 minutes

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/flood_data.dart';

const _kGaugeBox    = 'gauge_cache';
const _kHistoryBox  = 'gauge_history';
const _kTimestampKey = '__saved_at';
const _kStaleMinutes = 30;
const _kMaxHistoryDays = 7;

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  Box? _gaugeBox;
  Box? _historyBox;

  Future<void> init() async {
    _gaugeBox   ??= await Hive.openBox(_kGaugeBox);
    _historyBox ??= await Hive.openBox(_kHistoryBox);
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

  /// Returns `({data: List<FloodData>, isStale: bool})`.
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

  // ── 7-day gauge level history ────────────────────────────────────────────────
  // Stores a list of `{ts: iso8601, level: double}` JSON objects per station.

  Future<void> appendGaugeHistory(
      String stationId, double currentLevel) async {
    await init();
    try {
      final raw   = _historyBox!.get(stationId) as String?;
      final entries = raw != null
          ? (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      entries.add({
        'ts':    DateTime.now().toIso8601String(),
        'level': currentLevel,
      });

      // Keep only last 7 days
      final cutoff = DateTime.now().subtract(const Duration(days: _kMaxHistoryDays));
      final pruned = entries.where((e) {
        final dt = DateTime.tryParse(e['ts'] as String? ?? '');
        return dt != null && dt.isAfter(cutoff);
      }).toList();

      await _historyBox!.put(stationId, jsonEncode(pruned));
    } catch (e) {
      debugPrint('[Cache] history append error: $e');
    }
  }

  /// Returns a list of `(DateTime, double)` tuples sorted by time ascending.
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
