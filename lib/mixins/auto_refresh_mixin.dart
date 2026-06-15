// lib/mixins/auto_refresh_mixin.dart  (v1.0 — 15 Jun 2026)
//
// AutoRefreshMixin — drop-in helper for ConsumerState subclasses.
//
// Usage:
//   class _MyScreenState extends ConsumerState<MyScreen>
//       with AutoRefreshMixin {
//     @override
//     Widget build(BuildContext context) {
//       // lastFetchedLabel  → human-readable 'Updated 2 min ago'
//       // onManualRefresh() → triggers BiharLiveNotifier.refresh()
//       // refreshIndicator(child) → wraps child in RefreshIndicator
//     }
//   }
//
// The mixin does NOT call setState itself; it relies on the fact that
// any ref.watch() in build() will schedule a rebuild automatically when
// biharLiveProvider emits a new value.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bihar_live_provider.dart';

mixin AutoRefreshMixin on ConsumerState {
  // ── Manual refresh ──────────────────────────────────────────────────────
  Future<void> onManualRefresh() =>
      ref.read(biharLiveProvider.notifier).refresh();

  // ── Last-fetched label ───────────────────────────────────────────────────
  /// Returns a compact, human-readable 'Updated X ago' string drawn from
  /// the live provider's lastFetched timestamp.  Returns '' while loading.
  String get lastFetchedLabel {
    final state = ref.watch(biharLiveProvider);
    final dt = state.valueOrNull?.lastFetched;
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Updated ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  // ── RefreshIndicator wrapper ─────────────────────────────────────────────
  Widget refreshIndicator({required Widget child}) => RefreshIndicator(
        onRefresh: onManualRefresh,
        child: child,
      );
}
