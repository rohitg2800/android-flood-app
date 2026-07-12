// lib/services/offline_cache_service.dart
// Resolves issue #26: Offline Data Access with Local Caching
// connectivity_plus v7.x returns List<ConnectivityResult> — fixed here

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // Stream controller for connectivity state — used by OfflineBanner
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  static const Duration _defaultTtl = Duration(hours: 6);

  Future<void> initialize() async {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _isOnline = results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
      _connectivityController.add(_isOnline);
      if (kDebugMode) {
        debugPrint('[OfflineCacheService] online=$_isOnline results=$results');
      }
    });

    final results = await Connectivity().checkConnectivity();
    _isOnline = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);

    if (kDebugMode)
      debugPrint('[OfflineCacheService] initialized, online=$_isOnline');
  }

  Future<void> cacheData(
    String key,
    Map<String, dynamic> data, {
    Duration ttl = _defaultTtl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = {
        'data': data,
        'cached_at': DateTime.now().toIso8601String(),
        'ttl_ms': ttl.inMilliseconds,
      };
      await prefs.setString('offline_cache_$key', jsonEncode(envelope));
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineCacheService] cacheData error: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_cache_$key');
      if (raw == null) return null;

      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(envelope['cached_at'] as String);
      final ttlMs = envelope['ttl_ms'] as int;
      final age = DateTime.now().difference(cachedAt);

      if (age.inMilliseconds > ttlMs) {
        await prefs.remove('offline_cache_$key');
        return null;
      }

      return envelope['data'] as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode)
        debugPrint('[OfflineCacheService] getCachedData error: $e');
      return null;
    }
  }

  /// Returns a List from cached data (used by station_status_provider)
  Future<List<Map<String, dynamic>>?> getCachedList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_list_$key');
      if (raw == null) return null;
      final list = jsonDecode(raw);
      if (list is! List) return null;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      if (kDebugMode)
        debugPrint('[OfflineCacheService] getCachedList error: $e');
      return null;
    }
  }

  /// Cache a list (companion to getCachedList)
  Future<void> cacheList(String key, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_list_$key', jsonEncode(data));
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineCacheService] cacheList error: $e');
    }
  }

  Future<void> clearExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('offline_cache_'));
      final now = DateTime.now();
      for (final key in keys) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final envelope = jsonDecode(raw) as Map<String, dynamic>;
          final cachedAt = DateTime.parse(envelope['cached_at'] as String);
          final ttlMs = envelope['ttl_ms'] as int;
          if (now.difference(cachedAt).inMilliseconds > ttlMs) {
            await prefs.remove(key);
          }
        } catch (_) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('[OfflineCacheService] clearExpired error: $e');
    }
  }
}
