import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/alert_subscription.dart';

const _boxName = 'alert_subscriptions';

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, List<AlertSubscription>>(
  SubscriptionNotifier.new,
);

final isWatchedProvider = Provider.family<bool, String>((ref, stationId) {
  final subs = ref.watch(subscriptionProvider);
  return subs.any((s) => s.stationId == stationId);
});

class SubscriptionNotifier extends Notifier<List<AlertSubscription>> {
  Box<AlertSubscription>? _box;

  SubscriptionNotifier();

  @visibleForTesting
  SubscriptionNotifier.forTesting();

  @override
  List<AlertSubscription> build() {
    if (kDebugMode) return _loadFromBoxSafely();
    return _loadFromBoxSafely();
  }

  List<AlertSubscription> _loadFromBoxSafely() {
    try {
      _box ??= Hive.isBoxOpen(_boxName)
          ? Hive.box<AlertSubscription>(_boxName)
          : null;
      return _box?.values.toList() ?? <AlertSubscription>[];
    } catch (_) {
      return <AlertSubscription>[];
    }
  }

  void _persistAll() {
    try {
      final box = _box;
      if (box == null || !box.isOpen) return;
      box.clear();
      for (final sub in state) {
        box.put(sub.stationId, sub);
      }
    } catch (_) {}
  }

  void subscribe(AlertSubscription sub) {
    final exists = state.any((s) => s.stationId == sub.stationId);
    if (exists) return;
    state = [...state, sub];
    _persistAll();
  }

  void unsubscribe(String stationId) {
    state = state.where((s) => s.stationId != stationId).toList();
    try {
      _box?.delete(stationId);
    } catch (_) {}
  }

  void update(AlertSubscription updated) {
    state = [
      for (final s in state)
        if (s.stationId == updated.stationId) updated else s,
    ];
    _persistAll();
  }

  void clearAll() {
    state = <AlertSubscription>[];
    try {
      _box?.clear();
    } catch (_) {}
  }
}
