// lib/providers/ws_live_provider.dart  Step 2.3
// StreamProvider that exposes the WsGaugeService stream as a Riverpod provider.
// All screens should prefer watching wsLiveProvider over liveLevelsProvider
// for real-time updates. Falls back gracefully via the service's HTTP fallback.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../services/ws_gauge_service.dart';

// ── Main data provider ─────────────────────────────────────────────────────

final wsLiveProvider = StreamProvider<List<FloodData>>((ref) {
  final svc = WsGaugeService.instance;
  svc.start();         // idempotent — safe to call multiple times
  ref.onDispose(() {   // do NOT dispose singleton; just cancel this sub
    // WsGaugeService is a singleton; we never fully dispose it here
  });
  return svc.stream;
});

// ── Status provider ────────────────────────────────────────────────────────

final wsStatusProvider = StreamProvider<WsStatus>((ref) {
  return WsGaugeService.instance.statusStream;
});

// ── Last-sync time provider ────────────────────────────────────────────────
// Returns a DateTime? — null if no data has been received yet.

final wsLastSyncProvider = Provider<DateTime?>((ref) {
  // Re-evaluate whenever wsLiveProvider emits (keeps timestamp fresh)
  ref.watch(wsLiveProvider);
  return WsGaugeService.instance.lastDataAt;
});
