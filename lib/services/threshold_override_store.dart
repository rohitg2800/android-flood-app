// lib/services/threshold_override_store.dart
//
// Runtime threshold cache layered ON TOP of the compiled-in kBiharGauges.
//
// Values scraped from RTDAS (and optionally BeFIQR) are stored here in
// SharedPreferences so they survive app restarts without re-scraping.
//
// Key format (in SharedPrefs):
//   'rtdas_threshold_overrides_v1'  → JSON map<String, Map>
//
// Per-station map:
//   { 'wl': double?, 'dl': double?, 'hfl': double?,
//     'source': String, 'fetchedAt': int (epoch ms) }
//
// The sentinel key '__last_full_sync__' tracks the last complete table pull.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThresholdEntry {
  final double? wl;
  final double? dl;
  final double? hfl;
  final String source;
  final DateTime fetchedAt;

  const ThresholdEntry({
    this.wl,
    this.dl,
    this.hfl,
    required this.source,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'wl': wl,
        'dl': dl,
        'hfl': hfl,
        'source': source,
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
      };

  factory ThresholdEntry.fromJson(Map<String, dynamic> j) => ThresholdEntry(
        wl: (j['wl'] as num?)?.toDouble(),
        dl: (j['dl'] as num?)?.toDouble(),
        hfl: (j['hfl'] as num?)?.toDouble(),
        source: j['source'] as String? ?? 'RTDAS',
        fetchedAt:
            DateTime.fromMillisecondsSinceEpoch((j['fetchedAt'] as int?) ?? 0),
      );
}

class ThresholdOverrideStore {
  static const _prefsKey = 'rtdas_threshold_overrides_v1';

  static ThresholdOverrideStore? _instance;
  static ThresholdOverrideStore get instance =>
      _instance ??= ThresholdOverrideStore._();
  ThresholdOverrideStore._();

  final Map<String, ThresholdEntry> _cache = {};
  bool _loaded = false;

  /// Must be called once at app start (before any lookup).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final kv in decoded.entries) {
          _cache[kv.key] = ThresholdEntry.fromJson(
              (kv.value as Map).cast<String, dynamic>());
        }
      }
      _loaded = true;
      debugPrint('[ThresholdStore] loaded ${_cache.length} entries from prefs');
    } catch (e) {
      debugPrint('[ThresholdStore] load error: $e — starting empty');
      _loaded = true;
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {for (final kv in _cache.entries) kv.key: kv.value.toJson()};
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[ThresholdStore] save error: $e');
    }
  }

  void put(String stationKey, ThresholdEntry entry) {
    _cache[stationKey] = entry;
  }

  ThresholdEntry? get(String stationKey) => _cache[stationKey];

  /// Returns age in hours, or null if never fetched.
  double? ageHours(String key) {
    final e = _cache[key];
    if (e == null) return null;
    return DateTime.now().difference(e.fetchedAt).inMinutes / 60.0;
  }

  bool isStale(String key, {double maxHours = 18}) {
    final age = ageHours(key);
    return age == null || age > maxHours;
  }

  int get count => _cache.length;
}
