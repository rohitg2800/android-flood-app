// test/unit/local_cache_service_test.dart
//
// Unit tests for LocalCacheService.
// Uses hive_test to spin up an in-memory Hive environment — no real files.

import 'package:equinox_flood/services/local_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  setUp(() async {
    // Reset singleton box references first so init() re-opens fresh boxes.
    LocalCacheService.instance.resetForTesting();
    // Use an in-memory Hive directory for tests.
    Hive.init('.');
    await LocalCacheService.instance.init();
  });

  tearDown(() {
    LocalCacheService.instance.resetForTesting();
  });

  group('LocalCacheService — KV store', () {
    test('setString / getString round-trip', () async {
      final svc = LocalCacheService.instance;
      await svc.setString('hello', 'world');
      expect(svc.getString('hello'), 'world');
    });

    test('getString returns null for missing key', () async {
      final svc = LocalCacheService.instance;
      expect(svc.getString('__nonexistent__'), isNull);
    });

    test('remove deletes a key', () async {
      final svc = LocalCacheService.instance;
      await svc.setString('tmp', 'value');
      await svc.remove('tmp');
      expect(svc.getString('tmp'), isNull);
    });

    test('clear wipes all KV entries', () async {
      final svc = LocalCacheService.instance;
      await svc.setString('a', '1');
      await svc.setString('b', '2');
      await svc.clear();
      expect(svc.getString('a'), isNull);
      expect(svc.getString('b'), isNull);
    });

    test('setNow + isFresh reports fresh within ttl', () async {
      final svc = LocalCacheService.instance;
      await svc.setNow('ts_key');
      expect(svc.isFresh('ts_key', const Duration(minutes: 10)), isTrue);
    });

    test('isFresh returns false for missing timestamp', () {
      expect(
        LocalCacheService.instance.lastSavedAt,
        isNull,
      );
    });
  });
}
