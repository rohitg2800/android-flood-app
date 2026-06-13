// lib/services/ops_client.dart
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  EQUINOX-BH — Unified HTTP Client                                        ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// All outbound HTTP calls from the Flutter app go through this client.
// Every public method returns a Map — it never throws.
//   - Success:  the decoded JSON map  (or {'status':'success','data':[...]} for lists)
//   - HTTP 4xx: {'status':'error','error':'HTTP NNN ...'} — no retry
//   - HTTP 503: retry up to maxRetries, then return error map
//   - Timeout:  retry up to maxRetries, then return error map
//   - Other:    return error map after maxRetries

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../constants/app_constants.dart';

/// Singleton HTTP client for all EQUINOX-BH backend calls.
class OpsClient {
  OpsClient._();
  static final OpsClient instance = OpsClient._();

  http.Client _client = http.Client();

  // ---------------------------------------------------------------------------
  // Test seam — call this in setUp() to inject a MockClient.
  // Never call in production code.
  // ---------------------------------------------------------------------------
  // ignore: invalid_use_of_visible_for_testing_member
  static void overrideForTesting(http.Client client) {
    instance._client = client;
  }

  // ---------------------------------------------------------------------------
  // Core GET
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration timeout = AppConstants.defaultTimeout,
    int retries = AppConstants.maxRetries,
  }) async {
    return _withRetry(
      () => _client
          .get(_buildUri(path, query), headers: _headers())
          .timeout(timeout),
      retries: retries,
      label: 'GET $path',
    );
  }

  // ---------------------------------------------------------------------------
  // Core POST
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = AppConstants.defaultTimeout,
    int retries = 1,
  }) async {
    return _withRetry(
      () => _client
          .post(_buildUri(path, null),
              headers: _headers(), body: jsonEncode(body))
          .timeout(timeout),
      retries: retries,
      label: 'POST $path',
    );
  }

  // ---------------------------------------------------------------------------
  // Health check
  // ---------------------------------------------------------------------------

  Future<bool> isBackendReachable() async {
    final result =
        await get('/health', timeout: AppConstants.shortTimeout, retries: 1);
    return result['status'] == 'ok' || result.containsKey('status');
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Uri _buildUri(String path, Map<String, String>? params) {
    final base = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final fullPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$fullPath');
    return params != null && params.isNotEmpty
        ? uri.replace(queryParameters: params)
        : uri;
  }

  Map<String, String> _headers() => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
        if (AppConfig.apiToken.isNotEmpty)
          HttpHeaders.authorizationHeader: 'Bearer ${AppConfig.apiToken}',
      };

  /// Executes [call] with retry logic.
  /// - 4xx (except 503): fast-fail, no retry.
  /// - 503 / timeout / network error: retry up to [retries] times.
  /// - Always returns a Map; never throws.
  Future<Map<String, dynamic>> _withRetry(
    Future<http.Response> Function() call, {
    required int retries,
    required String label,
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await call();
        _logResponse(label, response.statusCode);

        // 2xx — success
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
          // Wrap non-map responses (e.g. lists)
          return {'status': 'success', 'data': decoded};
        }

        // 4xx (except 503) — client error, no retry
        if (response.statusCode >= 400 &&
            response.statusCode < 500 &&
            response.statusCode != 503) {
          return {
            'status': 'error',
            'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          };
        }

        // 503 or 5xx — retryable server error
        final err = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        if (attempt >= retries) {
          return {'status': 'error', 'error': err};
        }
        final delay = AppConstants.retryDelay * attempt;
        if (kDebugMode) {
          debugPrint(
              '[OpsClient] $label → ${response.statusCode}, retry $attempt/$retries in ${delay.inSeconds}s');
        }
        await Future<void>.delayed(delay);
      } on TimeoutException catch (e) {
        if (attempt >= retries) {
          return {'status': 'error', 'error': 'timeout: ${e.message}'};
        }
        final delay = AppConstants.retryDelay * attempt;
        if (kDebugMode) {
          debugPrint(
              '[OpsClient] $label timed out, retry $attempt/$retries in ${delay.inSeconds}s');
        }
        await Future<void>.delayed(delay);
      } catch (e) {
        if (attempt >= retries) {
          return {'status': 'error', 'error': e.toString()};
        }
        final delay = AppConstants.retryDelay * attempt;
        if (kDebugMode) {
          debugPrint(
              '[OpsClient] $label failed ($e), retry $attempt/$retries in ${delay.inSeconds}s');
        }
        await Future<void>.delayed(delay);
      }
    }
  }

  void _logResponse(String label, int statusCode) {
    if (AppConfig.isLoggingEnabled) {
      debugPrint('[OpsClient] $label → $statusCode');
    }
  }

  void dispose() => _client.close();
}
