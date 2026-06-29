// lib/services/backend_sync_service.dart
//
// OpsFlood — bidirectional backend sync layer.
//
// This service sits between local data producers
// (DataFetchEngine, RtdasThresholdSyncService) and the Railway backend.
// It is intentionally fire-and-forget: ALL failures are caught and logged;
// the app NEVER blocks on a push call and NEVER crashes because of one.
//
// What gets pushed:
//
//   1. pushGaugeTelemetry(DataFetchSnapshot)
//      Called after every DataFetchEngine cycle (every ~45 s).
//      Sends the full station list with current levels, forecasts, risk labels.
//      Also extracts and separately pushes critical/danger flood events.
//
//   2. pushRtdasThresholds(List<RtdasRow>)
//      Called after every RtdasThresholdSyncService sync (every ~6 h).
//      Sends the scraped WL/DL/HFL table so the backend can serve it to
//      other clients (web dashboard, admin panel, FCM cloud functions).
//
// Deduplication / rate-limiting:
//   - Gauge telemetry: at most once per _minPushInterval (default 30 s).
//     Protects against forceRefresh() spam.
//   - RTDAS thresholds: always pushed (they're rare — every 6 h max).
//
// Backend contract (endpoints the Railway server MUST implement):
//   POST /api/gauge-telemetry   → { ok: true, accepted: N }
//   POST /api/rtdas-thresholds  → { ok: true, upserted: N }
//   POST /api/flood-events      → { ok: true, recorded: N }
//
// ─────────────────────────────────────────────────────────────────────────────
// _backendSyncEnabled (flip to true once Railway routes are implemented)
//
// Both /api/gauge-telemetry and /api/flood-events currently return HTTP 405.
// They are already unawaited so they never block the UI, but they fire every
// ~45 s, waste bandwidth, and pollute logcat.  This flag suppresses all
// outbound pushes until the backend is ready.
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'backend_api_service.dart';
import 'data_fetch_engine.dart';
import 'rtdas_threshold_scraper.dart';
import 'threshold_override_store.dart';

class BackendSyncService {
  static BackendSyncService? _instance;
  static BackendSyncService get instance =>
      _instance ??= BackendSyncService._();
  BackendSyncService._();

  // ── Kill-switch: set to true once Railway implements the POST routes ──────
  static const bool _backendSyncEnabled = false;

  static const _minPushInterval = Duration(seconds: 30);

  final _api = BackendApiService.instance;
  DateTime? _lastGaugePush;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Push a complete gauge snapshot to the backend.
  /// Fire-and-forget — await if you want to know the result, but not required.
  Future<void> pushGaugeTelemetry(DataFetchSnapshot snapshot) async {
    if (!_backendSyncEnabled) return; // 405 guard — remove once routes exist

    // Rate-limit: skip if we pushed less than _minPushInterval ago.
    final now = DateTime.now();
    if (_lastGaugePush != null &&
        now.difference(_lastGaugePush!) < _minPushInterval) {
      debugPrint('[BackendSync] gauge push rate-limited — skipping');
      return;
    }
    _lastGaugePush = now;

    // ─ 1. Full gauge telemetry payload ───────────────────────────────────────
    final sourceCountMap = <String, int>{};
    for (final s in snapshot.stations) {
      sourceCountMap[s.source ?? 'unknown'] = (sourceCountMap[s.source ?? 'unknown'] ?? 0) + 1;
    }

    final gaugePaylod = <String, dynamic>{
      'ts':            snapshot.fetchedAt.millisecondsSinceEpoch,
      'source_counts': sourceCountMap,
      'live_count':    snapshot.liveStations,
      'total_count':   snapshot.totalStations,
      'stations':      snapshot.stations.map((s) => s.toJson()).toList(),
    };

    unawaited(_safePost(
      () => _api.postGaugeTelemetry(gaugePaylod),
      tag: 'gauge-telemetry',
    ));

    // ─ 2. Flood-events: only critical / danger stations ─────────────────────
    final dangerous = snapshot.stations.where(
      (s) => s.riskLabel == 'CRITICAL' || s.riskLabel == 'DANGER',
    ).toList();

    if (dangerous.isNotEmpty) {
      final eventsPayload = <String, dynamic>{
        'ts': now.millisecondsSinceEpoch,
        'events': dangerous.map((s) => {
          'station':      s.stationName,
          'river':        s.river,
          'district':     s.district,
          'state':        s.state,
          'lat':          s.lat,
          'lon':          s.lon,
          'level':        s.currentLevel,
          'warning_level':s.warningLevel,
          'danger_level': s.dangerLevel,
          'hfl':          s.hfl,
          'progress_pct': s.progressPct,
          'risk':         s.riskLabel,
          'source':       s.source,
          'rainfall_24h': s.rainfall24hMm,
          'forecast_24h': s.forecastLevel24h,
          'rate_of_rise': s.rateOfRiseMph,
          'ts':           s.fetchedAt.millisecondsSinceEpoch,
        }).toList(),
      };
      unawaited(_safePost(
        () => _api.postFloodEvents(eventsPayload),
        tag: 'flood-events(${dangerous.length})',
      ));
    }
  }

  /// Push RTDAS threshold table to the backend after a sync.
  /// Converts raw RtdasRow list + ThresholdOverrideStore metadata.
  Future<void> pushRtdasThresholds(List<RtdasRow> rows) async {
    if (!_backendSyncEnabled) return; // 405 guard — remove once routes exist

    if (rows.isEmpty) return;

    final store = ThresholdOverrideStore.instance;
    final thresholds = rows.map((r) {
      final key   = _norm(r.station);
      final entry = store.get(key);
      return <String, dynamic>{
        'station':    r.station,
        'station_key': key,
        'maintained_by': r.maintainedBy ?? 'WRD',
        'wl':         r.warningLevel,
        'dl':         r.dangerLevel,
        'hfl':        r.hfl,
        'source':     entry?.source ?? 'RTDAS/WRD',
        'fetched_at': entry?.fetchedAt.millisecondsSinceEpoch
                      ?? DateTime.now().millisecondsSinceEpoch,
      };
    }).toList();

    final payload = <String, dynamic>{
      'synced_at':       DateTime.now().millisecondsSinceEpoch,
      'station_count':   thresholds.length,
      'thresholds':      thresholds,
    };

    unawaited(_safePost(
      () => _api.postRtdasThresholds(payload),
      tag: 'rtdas-thresholds(${thresholds.length})',
    ));
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _safePost(
      Future<Map<String, dynamic>> Function() call,
      {required String tag}) async {
    try {
      final result = await call();
      debugPrint('[BackendSync] POST $tag → ok=${result['ok']}');
    } catch (e) {
      debugPrint('[BackendSync] POST $tag FAILED (non-fatal): $e');
    }
  }

  static String _norm(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\(.*?\)'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
