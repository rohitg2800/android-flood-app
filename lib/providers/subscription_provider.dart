import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionNotifier extends StateNotifier<List<String>> {
  SubscriptionNotifier() : super(const []);

  void addSubscription(String value) {
    state = [...state, value];
  }

  void removeSubscription(String value) {
    state = state.where((item) => item != value).toList();
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, List<String>>(
  (ref) => SubscriptionNotifier(),
);
