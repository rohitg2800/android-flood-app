// lib/services/backend_health_service.dart
// Phase 5 — Backend Keep-Alive for Render free tier
//
// Render free tier sleeps after 15 minutes of inactivity, causing
// a 50-second cold start that looks like a crash to users.
//
// Fix: ping /health every 14 minutes from the app when foregrounded.
// This is a soft keep-alive — errors are silently ignored.
// On Render paid tier, this is a no-op (server never sleeps).
library;

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'env_config.dart';

class BackendHealthService {
  BackendHealthService._();
  static final BackendHealthService instance = BackendHealthService._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    sendTimeout:    const Duration(seconds: 8),
  ));

  Timer?  _keepAliveTimer;
  bool    _isRunning = false;
  DateTime? _lastPingTime;
  bool    _lastPingSuccess = false;

  // ─────────────────────────────────────────────────────────────
  /// Start the keep-alive timer. Call once from main() after Firebase init.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    // Ping immediately on start to warm up the backend
    _ping();
    // Then every 14 minutes (Render timeout is 15 min)
    _keepAliveTimer = Timer.periodic(
      const Duration(minutes: 14),
      (_) => _ping(),
    );
    if (kDebugMode) {
      debugPrint('[BackendHealth] Keep-alive started '
          '(ping every 14 min → ${EnvConfig.backendBaseUrl}/health)');
    }
  }

  // ─────────────────────────────────────────────────────────────
  void stop() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _isRunning      = false;
  }

  // ─────────────────────────────────────────────────────────────
  /// Manual health check — returns true if backend is reachable.
  Future<bool> checkNow() async => _ping();

  // ─────────────────────────────────────────────────────────────
  DateTime? get lastPingTime    => _lastPingTime;
  bool      get lastPingSuccess => _lastPingSuccess;

  // ─────────────────────────────────────────────────────────────
  Future<bool> _ping() async {
    try {
      final res = await _dio.get(
        '${EnvConfig.backendBaseUrl}/health',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      _lastPingSuccess = res.statusCode != null && res.statusCode! < 400;
      _lastPingTime    = DateTime.now();
      if (kDebugMode) {
        debugPrint('[BackendHealth] Ping → ${res.statusCode} '
            '(${_lastPingSuccess ? "OK" : "DEGRADED"})');
      }
      return _lastPingSuccess;
    } catch (_) {
      // Never throw — a failed ping must not surface as a user-facing error.
      _lastPingSuccess = false;
      _lastPingTime    = DateTime.now();
      if (kDebugMode) debugPrint('[BackendHealth] Ping failed (offline?)');
      return false;
    }
  }
}
