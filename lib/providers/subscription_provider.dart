import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_subscription.dart';

class SubscriptionNotifier extends StateNotifier<List<AlertSubscription>> {
  SubscriptionNotifier() : super(const []);

  SubscriptionNotifier.forTesting(List<AlertSubscription> seed) : super(seed);

  Future<void> subscribe(AlertSubscription sub) async {
    final exists = state.any((s) => s.stationId == sub.stationId);
    if (!exists) {
      state = [...state, sub];
    }
  }

  Future<void> unsubscribe(String stationId) async {
    state = state.where((s) => s.stationId != stationId).toList();
  }

  Future<void> update(AlertSubscription updated) async {
    state = [
      for (final s in state)
        if (s.stationId == updated.stationId) updated else s,
    ];
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, List<AlertSubscription>>(
  (ref) => SubscriptionNotifier(),
);

final isWatchedProvider = Provider.family<bool, String>((ref, stationId) {
  final subs = ref.watch(subscriptionProvider);
  return subs.any((s) => s.stationId == stationId);
});
