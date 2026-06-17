// lib/services/offline_cache_manager.dart
// OpsFlood — Module 12: Offline Cache Manager
//
// Uses Hive for local persistence.
// Add to pubspec.yaml:
//   hive_flutter: ^1.1.0
//   connectivity_plus: ^6.0.3
//
// Public API:
//   OfflineCacheManager.instance.saveStations(list)
//   OfflineCacheManager.instance.loadStations() → List?
//   OfflineCacheManager.instance.saveAlerts(list)
//   OfflineCacheManager.instance.loadAlerts() → List?
//   OfflineCacheManager.instance.isStale(key) → bool
//   OfflineCacheManager.instance.queueAction(action)
//   OfflineCacheManager.instance.flushQueue() → flushes pending actions when online

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kBoxMeta      = 'opscache_meta';
const _kBoxData      = 'opscache_data';
const _kBoxQueue     = 'opscache_queue';
const _kStationsKey  = 'stations';
const _kAlertsKey    = 'alerts';
const _kTtlMs        = 10 * 60 * 1000; // 10 minutes

// ---------------------------------------------------------------------------
// OfflineCacheManager
// ---------------------------------------------------------------------------

class OfflineCacheManager {
  OfflineCacheManager._();
  static final instance = OfflineCacheManager._();

  late Box<String> _meta;
  late Box<String> _data;
  late Box<String> _queue;
  bool             _initialised = false;
  bool get initialised => _initialised;
  StreamSubscription? _connectivitySub;

  // ────────────────────────────────────────────────────────────────────────────
  // Init — call once from main() after Hive.initFlutter()
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialised) return;
    await Hive.initFlutter();
    _meta  = await Hive.openBox<String>(_kBoxMeta);
    _data  = await Hive.openBox<String>(_kBoxData);
    _queue = await Hive.openBox<String>(_kBoxQueue);
    _initialised = true;

    // Auto-flush queue when connectivity restored
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        flushQueue();
      }
    });
    debugPrint('[OfflineCache] Initialised. '
        'Queue length: ${_queue.length}');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Stations
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> saveStations(List<Map<String, dynamic>> stations) async {
    _assertInit();
    await _data.put(_kStationsKey, jsonEncode(stations));
    await _meta.put(
        '${_kStationsKey}_ts', DateTime.now().millisecondsSinceEpoch.toString());
    debugPrint('[OfflineCache] Saved ${stations.length} stations');
  }

  List<Map<String, dynamic>>? loadStations() {
    _assertInit();
    final raw = _data.get(_kStationsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Alerts
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> saveAlerts(List<Map<String, dynamic>> alerts) async {
    _assertInit();
    await _data.put(_kAlertsKey, jsonEncode(alerts));
    await _meta.put(
        '${_kAlertsKey}_ts', DateTime.now().millisecondsSinceEpoch.toString());
    debugPrint('[OfflineCache] Saved ${alerts.length} alerts');
  }

  List<Map<String, dynamic>>? loadAlerts() {
    _assertInit();
    final raw = _data.get(_kAlertsKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Generic key-value cache with TTL
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> put(String key, String value) async {
    _assertInit();
    await _data.put(key, value);
    await _meta.put(
        '${key}_ts', DateTime.now().millisecondsSinceEpoch.toString());
  }

  String? get(String key) {
    _assertInit();
    return _data.get(key);
  }

  bool isStale(String key, {int ttlMs = _kTtlMs}) {
    _assertInit();
    final tsStr = _meta.get('${key}_ts');
    if (tsStr == null) return true;
    final ts  = int.tryParse(tsStr) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    return age > ttlMs;
  }

  Future<void> invalidate(String key) async {
    _assertInit();
    await _data.delete(key);
    await _meta.delete('${key}_ts');
  }

  Future<void> clear() async {
    _assertInit();
    await _data.clear();
    await _meta.clear();
    debugPrint('[OfflineCache] Cleared all data');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Offline action queue (e.g. incident reports submitted offline)
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> queueAction(Map<String, dynamic> action) async {
    _assertInit();
    final key = 'action_${DateTime.now().microsecondsSinceEpoch}';
    await _queue.put(key, jsonEncode(action));
    debugPrint('[OfflineCache] Queued action: ${action['type']} '
        '(queue size: ${_queue.length})');
  }

  int get queueLength => _queue.length;

  /// Flushes all queued actions.
  /// Pass a [handler] to process each action;
  /// if omitted, actions are just logged and cleared (replace with real handler).
  Future<void> flushQueue({
    Future<bool> Function(Map<String, dynamic>)? handler,
  }) async {
    _assertInit();
    if (_queue.isEmpty) return;

    // Check connectivity first
    final result = await Connectivity().checkConnectivity();
    if (result.every((r) => r == ConnectivityResult.none)) {
      debugPrint('[OfflineCache] Still offline — skipping flush');
      return;
    }

    debugPrint('[OfflineCache] Flushing ${_queue.length} queued actions…');
    final keys = _queue.keys.toList();
    for (final key in keys) {
      final raw    = _queue.get(key as String);
      if (raw == null) continue;
      final action = jsonDecode(raw) as Map<String, dynamic>;
      bool success = true;
      if (handler != null) {
        success = await handler(action);
      } else {
        debugPrint('[OfflineCache] Action flushed (stub): $action');
      }
      if (success) await _queue.delete(key);
    }
    debugPrint('[OfflineCache] Flush complete. '
        'Remaining: ${_queue.length}');
  }

  // ---------------------------------------------------------------------------
  // Connectivity helper
  // ---------------------------------------------------------------------------

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await Hive.close();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _assertInit() {
    assert(_initialised,
        'OfflineCacheManager.init() must be called before use. '
        'Add it to main() after Hive.initFlutter().');
  }

  // ── FloodPrediction cache (Step 8c) ────────────────────────────────────────
  static const _kPredictionsKey = 'bulk_predictions';
  static const _kPredTtlMs      = 15 * 60 * 1000; // 15 min

  /// Persist bulk Bihar predictions as JSON list.
  Future<void> savePredictions(List<Map<String, dynamic>> preds) async {
    if (!_initialised) await init();
    final encoded = jsonEncode(preds);
    await _data.put(_kPredictionsKey, encoded);
    await _meta.put(
      '${_kPredictionsKey}_ts',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    debugPrint('[OfflineCache] saved ${preds.length} predictions');
  }

  /// Load cached predictions. Returns null if absent or stale.
  List<Map<String, dynamic>>? loadPredictions({bool ignoreStale = false}) {
    if (!_initialised) return null;
    if (!ignoreStale && isPredictionStale()) return null;
    final raw = _data.get(_kPredictionsKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[OfflineCache] loadPredictions parse error: $e');
      return null;
    }
  }

  /// True when prediction cache is missing or older than 15 min.
  bool isPredictionStale() {
    final tsStr = _meta.get('${_kPredictionsKey}_ts');
    if (tsStr == null) return true;
    final ts  = int.tryParse(tsStr) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    return age > _kPredTtlMs;
  }

  /// Age of prediction cache as a human string, e.g. "3 min ago".
  String predictionCacheAge() {
    final tsStr = _meta.get('${_kPredictionsKey}_ts');
    if (tsStr == null) return 'no cache';
    final ts      = int.tryParse(tsStr) ?? 0;
    final ageMs   = DateTime.now().millisecondsSinceEpoch - ts;
    final ageMins = (ageMs / 60000).round();
    if (ageMins < 1)  return 'just now';
    if (ageMins < 60) return '$ageMins min ago';
    return '${(ageMins / 60).round()} hr ago';
  }

}
