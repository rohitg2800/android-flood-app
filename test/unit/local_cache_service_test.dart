import 'package:shared_preferences/shared_preferences.dart';
// test/unit/local_cache_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flood_watch/services/local_cache_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalCacheService.isFresh()', () {
    test('returns false when key has never been set', () async {
      final svc = LocalCacheService();
      await svc.init();
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
    test('returns null when nothing cached', () async {
      final svc = LocalCacheService();
      await svc.init();
      expect(svc.lastSavedAt, isNull);
    });
  });
}
