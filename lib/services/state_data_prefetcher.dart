// lib/services/state_data_prefetcher.dart
//
// OpsFlood — StateDataPrefetcher (v1.0)
//
// Called when user navigates to a state screen (e.g. Bihar).
// Warms the BiharWrdScraper cache in one shot so every city card
// in that state loads instantly — no individual HTTP calls per city.
//
// Usage (in your state screen initState or provider):
//
//   @override
//   void initState() {
//     super.initState();
//     StateDataPrefetcher.prefetchState(widget.stateName);
//   }
library;

import 'package:flutter/foundation.dart';
import 'bihar_wrd_scraper.dart';

class StateDataPrefetcher {
  StateDataPrefetcher._(); // static-only class

  /// Call this when the user opens a state screen.
  /// Currently handles Bihar; extend for other states as new scrapers are added.
  static Future<void> prefetchState(String stateName) async {
    final s = stateName.trim().toLowerCase();
    if (s.contains('bihar')) {
      await _prefetchBihar();
    }
    // TODO: add Assam, UP, West Bengal scrapers here
  }

  static Future<void> _prefetchBihar() async {
    try {
      if (kDebugMode) debugPrint('[Prefetch] warming Bihar WRD cache...');
      final stations = await BiharWrdScraper.instance.fetchAll();
      if (kDebugMode) {
        debugPrint(
            '[Prefetch] Bihar ready: ${stations.length} stations cached');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Prefetch] Bihar prefetch failed: $e');
    }
  }
}
