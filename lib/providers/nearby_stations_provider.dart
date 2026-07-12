// lib/providers/nearby_stations_provider.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/nearby_station_service.dart';
import '../services/emergency_contact_service.dart';
import 'real_time_river_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

class NearbyCardState {
  final NearbyStation nearby;
  final List<EmergencyContact> contacts;

  const NearbyCardState({required this.nearby, required this.contacts});
}

class NearbyStationsState {
  final List<NearbyCardState> cards;
  final bool isLoading;
  final String? error;

  const NearbyStationsState({
    this.cards = const [],
    this.isLoading = false,
    this.error,
  });
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class NearbyStationsNotifier extends Notifier<NearbyStationsState> {
  final _contacts = EmergencyContactService();

  @override
  NearbyStationsState build() => const NearbyStationsState(isLoading: false);

  Future<void> refresh() async {
    state = const NearbyStationsState(isLoading: true);
    try {
      final allStations = ref.read(mergedStationsProvider);
      if (allStations.isEmpty) {
        state = const NearbyStationsState();
        return;
      }

      // Pick top-5 highest-risk stations as the "preferred cities".
      final top5 = allStations.take(5).toList();
      final svcResult =
          top5.map((s) => NearbyStation(station: s, distanceKm: 0)).toList();

      final cards = <NearbyCardState>[];
      for (final ns in svcResult) {
        final ctacts =
            await _contacts.getContactsForStation(ns.station.station);
        cards.add(NearbyCardState(nearby: ns, contacts: ctacts));
      }

      state = NearbyStationsState(cards: cards);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[NearbyStations] $e\n$st');
      state = NearbyStationsState(error: e.toString());
    }
  }
}

final nearbyStationsProvider =
    NotifierProvider<NearbyStationsNotifier, NearbyStationsState>(
  NearbyStationsNotifier.new,
);
