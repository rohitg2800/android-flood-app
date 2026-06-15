// lib/providers/subscription_provider.dart  v1.0 — Step 3.2
// StateNotifierProvider for AlertSubscription list.
// Persisted to Hive box 'subscriptions'.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/alert_subscription.dart';

const _kBox = 'subscriptions';

class SubscriptionNotifier extends StateNotifier<List<AlertSubscription>> {
  SubscriptionNotifier() : super([]) {
    _load();
  }

  void _load() {
    if (!Hive.isBoxOpen(_kBox)) return;
    final box = Hive.box<AlertSubscription>(_kBox);
    state = box.values.toList();
  }

  /// Add or update subscription for a station.
  Future<void> subscribe(AlertSubscription sub) async {
    final box = await Hive.openBox<AlertSubscription>(_kBox);
    await box.put(sub.stationId, sub);
    state = box.values.toList();
  }

  /// Remove subscription for a station.
  Future<void> unsubscribe(String stationId) async {
    final box = await Hive.openBox<AlertSubscription>(_kBox);
    await box.delete(stationId);
    state = box.values.toList();
  }

  /// Update a specific field on an existing subscription.
  Future<void> updateSubscription(
    String stationId, {
    double? customThresholdLevel,
    bool?   notifyOnBreachOnly,
    double? radiusKm,
  }) async {
    final box = await Hive.openBox<AlertSubscription>(_kBox);
    final existing = box.get(stationId);
    if (existing == null) return;
    final updated = existing.copyWith(
      customThresholdLevel: customThresholdLevel,
      notifyOnBreachOnly:   notifyOnBreachOnly,
      radiusKm:             radiusKm,
    );
    await box.put(stationId, updated);
    state = box.values.toList();
  }

  bool isSubscribed(String stationId) =>
      state.any((s) => s.stationId == stationId);

  AlertSubscription? getSubscription(String stationId) {
    try {
      return state.firstWhere((s) => s.stationId == stationId);
    } catch (_) {
      return null;
    }
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, List<AlertSubscription>>(
  (ref) => SubscriptionNotifier(),
);

/// Convenience selector: is a specific station being watched?
final isWatchedProvider = Provider.family<bool, String>(
  (ref, stationId) =>
      ref.watch(subscriptionProvider.notifier).isSubscribed(stationId),
);
