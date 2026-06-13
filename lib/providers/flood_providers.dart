// lib/providers/flood_providers.dart
// v10.4 — cityLookupMapProvider: O(1) city lookup; Bihar-only refresh gate
//
// v10.3: pre-warm LiveFetchEngine on first realTimeProvider access
// v10.2: _normCityKey() collapses qualifier variants so Birpur x3 → Birpur x1
// v10.1: deduplicate liveLevelsProvider by city key.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../models/river_station.dart';
import '../services/real_time_service.dart';
import 'real_time_river_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────────
// selectedCityProvider
// ─────────────────────────────────────────────────────────────────────────────────

class SelectedCityNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String city) => state = city;
  void clear()         => state = null;
}

final selectedCityProvider =
    NotifierProvider<SelectedCityNotifier, String?>(SelectedCityNotifier.new);
