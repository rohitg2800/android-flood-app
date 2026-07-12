// lib/services/rtdas_threshold_sync_service.dart  v2.0
//
// v2.0: after every successful sync, push thresholds to the Railway backend
// via BackendSyncService.pushRtdasThresholds().
// All other logic unchanged from v1.0.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'backend_sync_service.dart'; // ← NEW v2.0
import 'rtdas_threshold_scraper.dart';
import 'threshold_override_store.dart';

class RtdasThresholdSyncService {
  static const _syncInterval = Duration(hours: 6);
  static const _staleHoursGuard = 18.0;
  static const _syncSentinelKey = '__last_full_sync__';

  static RtdasThresholdSyncService? _instance;
  static RtdasThresholdSyncService get instance =>
      _instance ??= RtdasThresholdSyncService._();
  RtdasThresholdSyncService._();

  final _scraper = RtdasThresholdScraper();
  final _store = ThresholdOverrideStore.instance;

  Timer? _timer;
  bool _syncing = false;
  bool _started = false;

  final updatedCount = ValueNotifier<int>(0);

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _store.load();
    await _syncIfNeeded();
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) => _syncIfNeeded());
    debugPrint('[RtdasSync] started — interval=${_syncInterval.inHours}h');
  }

  void stop() {
    _timer?.cancel();
    _started = false;
    debugPrint('[RtdasSync] stopped.');
  }

  Future<void> forceSync() => _doSync();

  Future<void> _syncIfNeeded() async {
    final stale = _store.isStale(_syncSentinelKey, maxHours: _staleHoursGuard);
    if (!stale) {
      debugPrint('[RtdasSync] data is fresh — skipping sync');
      return;
    }
    await _doSync();
  }

  Future<void> _doSync() async {
    if (_syncing) {
      debugPrint('[RtdasSync] already syncing — skipping concurrent call');
      return;
    }
    _syncing = true;
    debugPrint('[RtdasSync] starting full RTDAS threshold sync …');

    try {
      final rows = await _scraper.fetch();
      int changed = 0;
      int skipped = 0;

      for (final row in rows) {
        final key = _norm(row.station);
        final existing = _store.get(key);

        final dlSame = existing?.dl == row.dangerLevel;
        final wlSame = existing?.wl == row.warningLevel;
        final hflSame = existing?.hfl == row.hfl;

        if (dlSame && wlSame && hflSame) {
          skipped++;
          continue;
        }

        _store.put(
            key,
            ThresholdEntry(
              wl: row.warningLevel,
              dl: row.dangerLevel,
              hfl: row.hfl,
              source: 'RTDAS/${row.maintainedBy ?? "WRD"}',
              fetchedAt: DateTime.now(),
            ));
        changed++;

        if (kDebugMode) {
          debugPrint('[RtdasSync]  ↳ UPDATED ${_norm(row.station)}  '
              'WL=${row.warningLevel}  DL=${row.dangerLevel}  HFL=${row.hfl}');
        }
      }

      _store.put(_syncSentinelKey,
          ThresholdEntry(source: 'sentinel', fetchedAt: DateTime.now()));
      await _store.save();
      updatedCount.value += changed;

      debugPrint('[RtdasSync] DONE — $changed updated / $skipped unchanged '
          '/ ${rows.length} total rows');

      // ── v2.0: push to backend ────────────────────────────────────────────────
      // Fire-and-forget — non-blocking, non-crashing.
      unawaited(BackendSyncService.instance.pushRtdasThresholds(rows));
    } catch (e, st) {
      debugPrint('[RtdasSync] ERROR during sync: $e\n$st');
    } finally {
      _syncing = false;
    }
  }

  static String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\(.*?\)'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
