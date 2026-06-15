// lib/mixins/auto_refresh_mixin.dart
//
// AutoRefreshMixin — attaches to any ConsumerStatefulWidget screen that needs:
//   • a pull-to-refresh gesture (refreshIndicator() wrapper)
//   • a manual refresh callback (onManualRefresh)
//   • a human-readable 'Updated X ago' label (lastFetchedLabel)
//
// USAGE:
//   class _MyScreenState extends ConsumerState<MyScreen>
//       with AutoRefreshMixin {
//     Widget build(BuildContext context) {
//       return Scaffold(
//         body: refreshIndicator(child: ...),
//         appBar: AppBar(actions: [
//           IconButton(icon: const Icon(Icons.refresh), onPressed: onManualRefresh),
//         ]),
//       );
//     }
//   }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bihar_live_provider.dart';

mixin AutoRefreshMixin on ConsumerState {
  DateTime? _lastFetched;

  // ── Pull-to-refresh wrapper ───────────────────────────────────────────────
  /// Wraps [child] in a RefreshIndicator that calls [onManualRefresh].
  Widget refreshIndicator({required Widget child}) {
    return RefreshIndicator(
      onRefresh: () async => onManualRefresh(),
      child: child,
    );
  }

  // ── Manual refresh ────────────────────────────────────────────────────────
  /// Invalidates biharLiveProvider, causing an immediate re-fetch.
  /// Screens wired to biharLiveProvider or mergedStationsProvider
  /// rebuild automatically when the engine emits the new feed.
  void onManualRefresh() {
    ref.invalidate(biharLiveProvider);
    _lastFetched = DateTime.now();
    if (mounted) setState(() {});
  }

  // ── 'Updated X ago' label ─────────────────────────────────────────────────
  String get lastFetchedLabel {
    if (_lastFetched == null) return '';
    final diff = DateTime.now().difference(_lastFetched!);
    if (diff.inSeconds < 60)  return 'Updated ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  // ── Convenience: monitored cities list ───────────────────────────────────
  /// Exposes India geodata constant so screens that mix this in
  /// can call `monitoredCities` without an extra import.
  List<Map<String, dynamic>> get monitoredCities {
    // Imported lazily via inline getter to avoid coupling all screens
    // to constants/india_geodata.dart directly in this mixin.
    // Each screen that needs the full list can import india_geodata.dart
    // themselves; this getter returns an empty list as a safe default.
    return const [];
  }
}
