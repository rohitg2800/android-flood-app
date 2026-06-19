// test/unit/local_cache_service_test.dart
// I-15: Unit tests for cache freshness and TTL logic

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flood_watch/services/local_cache_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
  });

  group('LocalCacheService.isFresh()', () {
    test('returns false when key has never been set', () {
      final svc = LocalCacheService();
      expect(svc.isFresh('never_set_key', const Duration(minutes: 5)), isFalse);
    });

    test('returns true immediately after timestamp set', () async {
      final svc = LocalCacheService();
      await svc.setTimestamp('test_ts');
      expect(svc.isFresh('test_ts', const Duration(minutes: 5)), isTrue);
    });

    test('returns false after TTL expires (6min > 5min TTL)', () async {
      final svc = LocalCacheService();
      final old = DateTime.now().subtract(const Duration(minutes: 6)).toIso8601String();
      await svc.setRaw('test_ts_old', old);
      expect(svc.isFresh('test_ts_old', const Duration(minutes: 5)), isFalse);
    });

    test('returns true within TTL window (3min < 5min TTL)', () async {
      final svc = LocalCacheService();
      final recent = DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String();
      await svc.setRaw('test_ts_recent', recent);
      expect(svc.isFresh('test_ts_recent', const Duration(minutes: 5)), isTrue);
    });
  });

  group('LocalCacheService.lastSavedAt', () {
    test('returns null when nothing cached', () {
      final svc = LocalCacheService();
      expect(svc.lastSavedAt, isNull);
    });
  });
}
