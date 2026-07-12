// lib/mixins/auto_refresh_mixin.dart  v2.0
//
// AutoRefreshMixin — pull-to-refresh helper + 'Updated X ago' label.
//
// DESIGN NOTE — why no `on ConsumerState` constraint:
//   Dart's mixin `on T` requires the mixin-user's superclass to be *exactly*
//   `T`.  Because every screen uses `ConsumerState<ItsOwnWidget>` (a
//   different generic instantiation), writing `on ConsumerState` (without
//   a type arg) or `on ConsumerState<ConsumerStatefulWidget>` causes the
//   "can't implement both State<X> and State<ConsumerStatefulWidget>" error.
//
//   The solution is a plain mixin that declares the members it needs from
//   ConsumerState (ref, mounted, setState) as abstract getters/methods.
//   Dart resolves them at mix-in time from the concrete ConsumerState<T>.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bihar_live_provider.dart';

mixin AutoRefreshMixin {
  // ── Abstract members resolved by ConsumerState<T> at mix-in time ────────

  /// Provided by ConsumerState.
  WidgetRef get ref;

  /// Provided by State.
  bool get mounted;

  /// Provided by State.
  // ignore: invalid_use_of_protected_member
  void setState(VoidCallback fn);

  // ── Internal state ───────────────────────────────────────────────────────

  DateTime? _lastFetched;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Human-readable label, e.g. 'Updated 2 min ago'.  Empty if never fetched.
  String get lastFetchedLabel {
    final t = _lastFetched;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours} h ago';
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
    try {
      await ref.read(biharLiveProvider.notifier).refresh();
    } catch (_) {}
    if (mounted) {
      setState(() => _lastFetched = DateTime.now());
    }
  }
}
