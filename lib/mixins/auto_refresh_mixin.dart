// lib/mixins/auto_refresh_mixin.dart
//
// AutoRefreshMixin — attaches to any ConsumerStatefulWidget screen that needs:
//   • a pull-to-refresh gesture (refreshIndicator() wrapper)
//   • a manual refresh callback (onManualRefresh)
//   • a human-readable 'Updated X ago' label (lastFetchedLabel)
//
// MIXIN CONSTRAINT:
//   `on ConsumerState<ConsumerStatefulWidget>` is the correct bound.
//   Dart requires the `on` type to be the *erased* base supertype;
//   using `on ConsumerState` alone causes the compiler to reject
//   `extends ConsumerState<DashboardScreen> with AutoRefreshMixin` because
//   ConsumerState<DashboardScreen> != ConsumerState<ConsumerStatefulWidget>.
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

mixin AutoRefreshMixin on ConsumerState<ConsumerStatefulWidget> {
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
  /// Safe default; screens that need the full list import india_geodata.dart.
  List<Map<String, dynamic>> get monitoredCities => const [];
}
