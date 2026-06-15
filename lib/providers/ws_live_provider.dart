// lib/providers/ws_live_provider.dart  v1.0 — Step 2.3
// StreamProvider<List<FloodData>> powered by WsGaugeService.
// Also exposes connection status + last-sync time for the SyncStatusBanner.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../services/ws_gauge_service.dart';

/// Live gauge data — backed by WS, falls back to HTTP polling automatically.
final wsLiveProvider = StreamProvider<List<FloodData>>((ref) {
  final svc = ref.watch(wsGaugeServiceProvider);
  return svc.stream;
});

/// Current connection mode — used by SyncStatusBanner.
final wsStatusProvider = StreamProvider<WsStatus>((ref) {
  final svc = ref.watch(wsGaugeServiceProvider);
  return svc.status;
});

/// Last successful data-receive timestamp — used by SyncStatusBanner.
final lastSyncProvider = StreamProvider<DateTime>((ref) {
  final svc = ref.watch(wsGaugeServiceProvider);
  return svc.lastSync;
});
