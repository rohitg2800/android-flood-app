// lib/providers/stubs.dart
// Stub providers that are referenced across the codebase but not yet
// implemented in their own files. Import this file wherever needed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_station.dart';

/// Stub for real_time_river_provider.dart callers.
/// Replace with a real implementation when the DataFetch layer is wired up.
final dataFetchStationsProvider = Provider<List<RiverStation>>(
    (ref) => const []);

/// Stub for map_live_index_provider.dart callers.
/// Replace with a real SourceStatus enum/class when ready.
final sourceStatusProvider = Provider<Map<String, bool>>(
    (ref) => const {});
