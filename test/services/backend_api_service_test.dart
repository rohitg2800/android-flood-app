// test/services/backend_api_service_test.dart
//
// Unit tests for BackendApiService v4.0
// Uses MockClient (http package) injected via OpsClient.overrideForTesting().
// Tests the full BackendApiService → OpsClient → http.Client stack.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:equinox_flood/services/backend_api_service.dart';
import 'package:equinox_flood/services/ops_client.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

http.Client _mockClient(Map<String, dynamic> body, {int status = 200}) {
  return MockClient((_) async => http.Response(jsonEncode(body), status));
}

http.Client _mockClientFor(Map<String, String> pathToJson) {
  return MockClient((req) async {
    final path = req.url.path;
    for (final entry in pathToJson.entries) {
      if (path.contains(entry.key)) {
        return http.Response(entry.value, 200);
      }
    }
    return http.Response('{"error":"not found"}', 404);
  });
}

void main() {
  tearDown(() {
    // Reset to real http.Client after each test
    OpsClient.overrideForTesting(http.Client());
  });

  // ── fetchLiveLevels ────────────────────────────────────────────────────────

  group('fetchLiveLevels', () {
    test('parses data-wrapped response', () async {
      OpsClient.overrideForTesting(_mockClient({
        'data': [
          {'city': 'Patna', 'level': 8.2},
          {'city': 'Gaya',  'level': 5.1},
        ]
      }));

      final result = await BackendApiService.instance.fetchLiveLevels('Bihar');
      expect(result, hasLength(2));
      expect(result.first['city'], 'Patna');
    });

    test('parses stations-wrapped response', () async {
      OpsClient.overrideForTesting(_mockClient({
        'stations': [
          {'city': 'Varanasi', 'level': 7.0},
        ]
      }));

      final result = await BackendApiService.instance.fetchLiveLevels('UP');
      expect(result.first['city'], 'Varanasi');
    });

    test('throws FormatException on unexpected shape', () async {
      OpsClient.overrideForTesting(_mockClient({'unexpected': 'shape'}));

      expect(
        () => BackendApiService.instance.fetchLiveLevels('X'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on 503 after retries exhausted', () async {
      OpsClient.overrideForTesting(
        MockClient((_) async => http.Response('Service Unavailable', 503)),
      );

      expect(
        () => BackendApiService.instance.fetchLiveLevels('Bihar'),
        throwsA(isA<Exception>()),
      );
    });

    test('fast-fails on 404 without retry', () async {
      OpsClient.overrideForTesting(
        MockClient((_) async => http.Response('Not Found', 404)),
      );

      expect(
        () => BackendApiService.instance.fetchLiveLevels('Bihar'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── fetchLiveLevelsWithSeverity ────────────────────────────────────────────

  group('fetchLiveLevelsWithSeverity', () {
    test('returns severity-enriched list', () async {
      OpsClient.overrideForTesting(_mockClient({
        'data': [
          {'city': 'Patna', 'predicted_severity': 'HIGH', 'risk_score': 82},
        ]
      }));

      final result =
          await BackendApiService.instance.fetchLiveLevelsWithSeverity();
      expect(result.first['predicted_severity'], 'HIGH');
      expect(result.first['risk_score'], 82);
    });

    test('returns empty list when data is empty', () async {
      OpsClient.overrideForTesting(_mockClient({'data': []}));

      final result = await BackendApiService.instance
          .fetchLiveLevelsWithSeverity(limit: 50);
      expect(result, isEmpty);
    });
  });

  // ── fetchRiverSeverity ─────────────────────────────────────────────────────

  group('fetchRiverSeverity', () {
    test('returns map on success', () async {
      OpsClient.overrideForTesting(
          _mockClient({'stations': [], 'total': 0}));

      final result = await BackendApiService.instance.fetchRiverSeverity();
      expect(result['total'], 0);
    });

    test('accepts optional state filter', () async {
      OpsClient.overrideForTesting(
          _mockClient({'stations': [], 'total': 0, 'state': 'Bihar'}));

      final result = await BackendApiService.instance
          .fetchRiverSeverity(state: 'Bihar', limit: 100);
      expect(result, isA<Map<String, dynamic>>());
    });
  });

  // ── fetchGloFAS ────────────────────────────────────────────────────────────

  group('fetchGloFAS', () {
    test('returns list of GloFAS records', () async {
      OpsClient.overrideForTesting(_mockClient({
        'data': [
          {'city': 'Patna', 'discharge': 1200.0},
        ]
      }));

      final result = await BackendApiService.instance.fetchGloFAS(
        lats: [25.6, 26.1],
        lons: [85.1, 85.4],
        cityKeys: ['Patna', 'Gaya'],
      );
      expect(result.first['discharge'], 1200.0);
    });
  });

  // ── fetchNews ──────────────────────────────────────────────────────────────

  group('fetchNews', () {
    test('parses items-wrapped response', () async {
      OpsClient.overrideForTesting(_mockClient({
        'items': [
          {'title': 'Flood alert in Patna'},
          {'title': 'River levels rising'},
        ]
      }));

      final result =
          await BackendApiService.instance.fetchNews(state: 'Bihar');
      expect(result, hasLength(2));
      expect(result.first['title'], 'Flood alert in Patna');
    });

    test('parses data-wrapped response', () async {
      OpsClient.overrideForTesting(_mockClient({
        'data': [
          {'title': 'Ganga floods Varanasi'},
        ]
      }));

      final result = await BackendApiService.instance.fetchNews(state: 'UP');
      expect(result.first['title'], 'Ganga floods Varanasi');
    });

    test('throws FormatException on unexpected shape', () async {
      OpsClient.overrideForTesting(_mockClient({'error': 'not found'}));

      expect(
        () => BackendApiService.instance.fetchNews(state: 'X'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // ── fetchCwcStations ───────────────────────────────────────────────────────

  group('fetchCwcStations', () {
    test('returns empty list immediately for empty codes — no HTTP call', () async {
      // No mock needed — should short-circuit before hitting network
      final result =
          await BackendApiService.instance.fetchCwcStations(codes: []);
      expect(result, isEmpty);
    });

    test('returns station list for valid codes', () async {
      OpsClient.overrideForTesting(_mockClient({
        'data': [
          {'code': 'GS001', 'level': 6.0},
          {'code': 'GS002', 'level': 7.5},
        ]
      }));

      final result = await BackendApiService.instance
          .fetchCwcStations(codes: ['GS001', 'GS002']);
      expect(result, hasLength(2));
      expect(result.first['code'], 'GS001');
    });
  });

  // ── checkHealth ────────────────────────────────────────────────────────────

  group('checkHealth', () {
    test('returns health map on 200', () async {
      OpsClient.overrideForTesting(
          _mockClient({'status': 'ok', 'uptime': 3600}));

      final result = await BackendApiService.instance.checkHealth();
      expect(result['status'], 'ok');
      expect(result['uptime'], 3600);
    });
  });

  // ── POST endpoints ─────────────────────────────────────────────────────────

  group('POST endpoints', () {
    test('postGaugeTelemetry returns ok on 200', () async {
      OpsClient.overrideForTesting(_mockClient({'ok': true}));

      final result = await BackendApiService.instance
          .postGaugeTelemetry({'station': 'GS001', 'level': 8.2});
      expect(result['ok'], true);
    });

    test('postRtdasThresholds returns ok on 200', () async {
      OpsClient.overrideForTesting(_mockClient({'ok': true, 'count': 5}));

      final result = await BackendApiService.instance
          .postRtdasThresholds({'thresholds': []});
      expect(result['count'], 5);
    });

    test('postFloodEvents returns ok on 200', () async {
      OpsClient.overrideForTesting(_mockClient({'ok': true, 'events': 3}));

      final result = await BackendApiService.instance
          .postFloodEvents({'events': []});
      expect(result['events'], 3);
    });
  });
}
