// test/ops_client_test.dart
//
// Unit tests for OpsClient — the single HTTP transport layer.
// Uses package:http/testing.dart MockClient so no real network is needed.
//
// Run: flutter test test/ops_client_test.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:equinox_flood/services/ops_client.dart';

// ── Helper to build a MockClient that always returns the same response ────────
MockClient _fixed(int status, [Map<String, dynamic>? body]) {
  return MockClient((_) async => http.Response(
        body != null ? jsonEncode(body) : '',
        status,
      ));
}

// MockClient that counts calls and cycles through a list of responses
class _CycleClient extends http.BaseClient {
  final List<http.Response> responses;
  int calls = 0;

  _CycleClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res =
        responses[calls < responses.length ? calls : responses.length - 1];
    calls++;
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  // Reset singleton before every test
  setUp(() {
    OpsClient.overrideForTesting(
        http.Client()); // real client, will be replaced per-test
  });

  // ── 1. Happy path ──────────────────────────────────────────────────────────
  group('Happy path', () {
    test('GET 200 returns parsed body', () async {
      OpsClient.overrideForTesting(_fixed(200, {'status': 'ok', 'value': 42}));
      final res = await OpsClient.instance.get('/health');
      expect(res['status'], equals('ok'));
      expect(res['value'], equals(42));
    });

    test('POST 200 returns parsed body', () async {
      OpsClient.overrideForTesting(
          _fixed(200, {'status': 'ok', 'prediction': 'flood'}));
      final res = await OpsClient.instance.post('/predict', {'rain': 150});
      expect(res['prediction'], equals('flood'));
    });

    test('GET 200 with list body is normalised', () async {
      OpsClient.overrideForTesting(
          MockClient((_) async => http.Response(jsonEncode([1, 2, 3]), 200)));
      final res = await OpsClient.instance.get('/api/live-levels');
      expect(res['status'], equals('success'));
      expect(res['data'], equals([1, 2, 3]));
    });
  });

  // ── 2. Fast-fail on 404 ────────────────────────────────────────────────────
  group('404 fast-fail', () {
    test('returns error map immediately without retrying', () async {
      int calls = 0;
      OpsClient.overrideForTesting(MockClient((_) async {
        calls++;
        return http.Response('Not Found', 404);
      }));
      final res = await OpsClient.instance.get('/no-such-endpoint');
      expect(res['status'], equals('error'));
      expect(res['error'].toString(), contains('404'));
      expect(calls, equals(1), reason: '404 must not be retried');
    });
  });

  // ── 3. 503 retry with capped back-off ─────────────────────────────────────
  group('503 retry', () {
    test('retries on 503 and succeeds on second attempt', () async {
      final cycle = _CycleClient([
        http.Response('Service Unavailable', 503),
        http.Response(jsonEncode({'status': 'ok'}), 200),
      ]);
      OpsClient.overrideForTesting(cycle);
      // Use a short timeout so the test runs fast
      final res = await OpsClient.instance
          .get('/health', timeout: const Duration(seconds: 5));
      expect(res['status'], equals('ok'));
      expect(cycle.calls, equals(2));
    });

    test('returns error after maxRetries 503s', () async {
      OpsClient.overrideForTesting(_fixed(503));
      final res = await OpsClient.instance
          .get('/health', timeout: const Duration(seconds: 5));
      expect(res['status'], equals('error'));
      expect(res['error'].toString(), contains('503'));
    });
  });

  // ── 4. Other 4xx fast-fail ─────────────────────────────────────────────────
  group('4xx fast-fail', () {
    for (final code in [400, 401, 403, 422]) {
      test('$code returns error immediately', () async {
        int calls = 0;
        OpsClient.overrideForTesting(MockClient((_) async {
          calls++;
          return http.Response('Client Error', code);
        }));
        final res = await OpsClient.instance.get('/api/predict');
        expect(res['status'], equals('error'));
        expect(calls, equals(1), reason: '$code must not be retried');
      });
    }
  });

  // ── 5. Timeout handling ────────────────────────────────────────────────────
  group('Timeout', () {
    test('TimeoutException results in error map', () async {
      OpsClient.overrideForTesting(MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        return http.Response('ok', 200);
      }));
      final res = await OpsClient.instance
          .get('/health', timeout: const Duration(milliseconds: 50));
      expect(res['status'], equals('error'));
      expect(res['error'].toString().toLowerCase(), contains('timeout'));
    });

    test('retries on timeout and succeeds on second attempt', () async {
      int calls = 0;
      OpsClient.overrideForTesting(MockClient((_) async {
        calls++;
        if (calls == 1) {
          await Future<void>.delayed(const Duration(seconds: 10));
        }
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }));
      final res = await OpsClient.instance
          .get('/health', timeout: const Duration(milliseconds: 80));
      // first call times out, second succeeds
      expect(res['status'], equals('ok'));
      expect(calls, equals(2));
    });
  });

  // ── 6. Query string encoding ───────────────────────────────────────────────
  group('Query string', () {
    test('query params are appended and URI-encoded', () async {
      Uri? captured;
      OpsClient.overrideForTesting(MockClient((req) async {
        captured = req.url;
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }));
      await OpsClient.instance.get('/api/live-telemetry',
          query: {'state': 'Tamil Nadu', 'limit': '10'});
      expect(captured, isNotNull);
      expect(captured!.queryParameters['state'], equals('Tamil Nadu'));
      expect(captured!.queryParameters['limit'], equals('10'));
    });
  });

  // ── 7. dispose() ──────────────────────────────────────────────────────────
  group('dispose', () {
    test('dispose() closes the underlying client without throwing', () {
      OpsClient.overrideForTesting(_fixed(200, {'status': 'ok'}));
      expect(() => OpsClient.instance.dispose(), returnsNormally);
    });
  });
}
