// lib/mixins/auto_refresh_mixin.dart
//
// AutoRefreshMixin — pulled-to-refresh helper + 'Updated X ago' label.
//
// Mix into any ConsumerStatefulWidget State to get:
//   • onManualRefresh()  — call from AppBar refresh IconButton
//   • refreshIndicator() — wraps a child in a RefreshIndicator
//   • lastFetchedLabel   — human-readable 'Updated 3 min ago' string
//
// The mixin calls ref.invalidate(biharLiveProvider) on manual refresh
// so that every screen that uses this mixin triggers the same engine refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bihar_live_provider.dart';

mixin AutoRefreshMixin on ConsumerState {
  DateTime? _lastFetched;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Human-readable label, e.g. 'Updated 2 min ago'.  Empty if never fetched.
  String get lastFetchedLabel {
    final t = _lastFetched;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60)  return 'Updated just now';
    if (diff.inMinutes < 60)  return 'Updated ${diff.inMinutes} min ago';
    if (diff.inHours   < 24)  return 'Updated ${diff.inHours} h ago';
    return 'Updated ${diff.inDays} d ago';
  }

  /// Wraps [child] in a [RefreshIndicator] that fires [onManualRefresh].
  Widget refreshIndicator({required Widget child}) {
    return RefreshIndicator(
      onRefresh: () => onManualRefresh(),
      child: child,
    );
  }

  /// Force-refresh the live provider and update [lastFetchedLabel].
  Future<void> onManualRefresh() async {
    await ref.read(biharLiveProvider.notifier).refresh();
    if (mounted) {
      setState(() => _lastFetched = DateTime.now());
    }
  }

  // ── Lifecycle — update _lastFetched whenever the provider emits new data ──

  @override
  void initState() {
    super.initState();
    // Listen for the first successful data emission to seed _lastFetched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(biharLiveProvider);
      current.whenData((state) {
        if (state.lastFetched != null && mounted) {
          setState(() => _lastFetched = state.lastFetched);
        }
      });
    });
  }
}
