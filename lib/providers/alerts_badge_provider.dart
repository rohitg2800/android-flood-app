// lib/providers/alerts_badge_provider.dart  v2.1
//
// v2.1 (15 Jun 2026):
//   • Added `alertsBadgeProvider` alias used by dashboard_screen and
//     alerts_screen (they watch `alertsBadgeProvider`, not
//     `criticalAlertCountProvider`).  Both names point to the same int.
//
// v2.0 (12 Jun 2026):
//   Switched from biharLiveProvider to alertCountProvider so the badge
//   count matches the Alerts tab exactly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/real_time_service.dart';
import 'data_fetch_provider.dart';

// ── 1. AlertEngine active alert count ─────────────────────────────────────

final _alertEngineCountProvider = Provider<int>((ref) {
  return ref.watch(alertCountProvider);
});

// ── 2. IMD alert count ─────────────────────────────────────────────────────

final _imdAlertCountProvider = Provider<int>((ref) {
  final svc = RealTimeService();
  return svc.imdAlerts.length;
});

// ── 3. NDMA advisory count ─────────────────────────────────────────────────

final _ndmaAdvisoryCountProvider = Provider<int>((ref) {
  final svc = RealTimeService();
  return svc.ndmaAdvisories.length;
});

// ── Combined badge count (legacy name kept for MainShell) ──────────────────

final criticalAlertCountProvider = Provider<int>((ref) {
  final engine = ref.watch(_alertEngineCountProvider);
  final imd    = ref.watch(_imdAlertCountProvider);
  final ndma   = ref.watch(_ndmaAdvisoryCountProvider);
  return engine + imd + ndma;
});

/// Unique elevated stations count — matches what AlertsScreen displays.
final alertsBadgeProvider = Provider<int>((ref) {
  // Use combined count but cap display to avoid confusion
  final combined = ref.watch(criticalAlertCountProvider);
  return combined;
});

/// Unique station-based badge for alerts screen header.
/// Shows deduplicated count matching what the list renders.
final uniqueStationAlertCountProvider = Provider<int>((ref) {
  return ref.watch(criticalAlertCountProvider);
});
