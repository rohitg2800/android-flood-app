// lib/providers/subscription_provider.dart  Step 3.2
// StateNotifier that manages user's station subscriptions, persisted to Hive.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_subscription.dart';

const _kBoxName = 'alert_subscriptions';

// ── Provider ────────────────────────────────────────────────────────────────

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, List<AlertSubscription>>(
  (ref) => SubscriptionNotifier(),
);

/// Returns true if the given stationId is currently watched.
final isWatchedProvider = Provider.family<bool, String>((ref, stationId) {
  return ref.watch(subscriptionProvider).any((s) => s.stationId == stationId);
});

// ── Notifier ────────────────────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<List<AlertSubscription>> {
  SubscriptionNotifier() : super([]) {
    _load();
  }

  @visibleForTesting
  SubscriptionNotifier.forTesting(super.seed);

  Box<AlertSubscription>? _box;

  Future<void> _load() async {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(AlertSubscriptionAdapter());
    }
    _box = await Hive.openBox<AlertSubscription>(_kBoxName);
    state = _box!.values.toList();
  }

  // ── Public API ──────────────────────────────────────────────────────

  Future<void> subscribe(AlertSubscription sub) async {
    // Prevent duplicates
    if (state.any((s) => s.stationId == sub.stationId)) return;
    await _box?.add(sub);
    state = [...state, sub];
  }

  Future<void> unsubscribe(String stationId) async {
    final box = _box;
    if (box == null) return;
    final keys = box.keys.where((k) => box.get(k)?.stationId == stationId);
    for (final k in keys) await box.delete(k);
    state = state.where((s) => s.stationId != stationId).toList();
  }

  Future<void> update(AlertSubscription updated) async {
    final box = _box;
    if (box == null) return;
    final key = box.keys.firstWhere(
        (k) => box.get(k)?.stationId == updated.stationId,
        orElse: () => null);
    if (key != null) await box.put(key, updated);
    state = [
      for (final s in state)
        if (s.stationId == updated.stationId) updated else s,
    ];
  }

  bool isWatched(String stationId) =>
      state.any((s) => s.stationId == stationId);

  AlertSubscription? getFor(String stationId) =>
      state.where((s) => s.stationId == stationId).firstOrNull;
}
