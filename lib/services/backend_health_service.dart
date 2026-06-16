// lib/services/backend_health_service.dart
// Rewritten to use http (already in pubspec) instead of dio.
// EnvConfig replaced with inline const so no missing import.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _kBackendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://opsflood-api.onrender.com',
);

const _kHealthPath   = '/health';
const _kPingPath     = '/ping';
const _kStatusPath   = '/api/status';
const _kTimeoutSec   = 10;

class BackendHealthStatus {
  final bool   isOnline;
  final int    statusCode;
  final String message;
  final int    latencyMs;
  final Map<String, dynamic> details;

  const BackendHealthStatus({
    required this.isOnline,
    required this.statusCode,
    required this.message,
    required this.latencyMs,
    this.details = const {},
  });

  @override
  String toString() =>
      'BackendHealthStatus(online=$isOnline, code=$statusCode, '
      'latency=${latencyMs}ms, msg=$message)';
}

class BackendHealthService {
  BackendHealthService._();
  static final BackendHealthService instance = BackendHealthService._();

  // ── Single health check ──────────────────────────────────────────────────

  Future<BackendHealthStatus> check() async {
    final sw = Stopwatch()..start();
    for (final path in [_kHealthPath, _kPingPath, _kStatusPath]) {
      try {
        final res = await http
            .get(Uri.parse('$_kBackendBase$path'))
            .timeout(const Duration(seconds: _kTimeoutSec));
        sw.stop();
        if (res.statusCode < 500) {
          Map<String, dynamic> details = {};
          try {
            details = jsonDecode(res.body) as Map<String, dynamic>;
          } catch (_) {}
          return BackendHealthStatus(
            isOnline:   res.statusCode < 400,
            statusCode: res.statusCode,
            message:    res.statusCode < 400 ? 'OK' : 'Degraded',
            latencyMs:  sw.elapsedMilliseconds,
            details:    details,
          );
        }
      } catch (e) {
        debugPrint('[Health] $path error: $e');
      }
    }
    sw.stop();
    return BackendHealthStatus(
      isOnline:   false,
      statusCode: 0,
      message:    'Unreachable',
      latencyMs:  sw.elapsedMilliseconds,
    );
  }

  // ── Periodic polling helper ──────────────────────────────────────────────

  Stream<BackendHealthStatus> poll({
    Duration interval = const Duration(minutes: 5),
  }) async* {
    while (true) {
      yield await check();
      await Future<void>.delayed(interval);
    }
  }
}
