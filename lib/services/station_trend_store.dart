// lib/services/station_trend_store.dart
//
// OpsFlood — StationTrendStore
//
// Ring-buffer of RiverLevelSnapshot entries per city.
// Keeps the last _maxReadings snapshots (default 48 = 24 h at 30 s poll).
//
// Usage:
//   StationTrendStore.instance.append(cityKey, level, timestamp);
//   List<RiverLevelSnapshot> trend = StationTrendStore.instance.get(cityKey);
//
// Thread-safety: Dart is single-threaded; no locking needed.
library;

import '../models/river_monitoring.dart';

class StationTrendStore {
  StationTrendStore._();
  static final StationTrendStore instance = StationTrendStore._();

  /// Maximum snapshots kept per city (48 × 30 s ≈ 24 h).
  static const int _maxReadings = 48;

  // city-key (lowercase trimmed) → ring buffer
  final Map<String, List<RiverLevelSnapshot>> _buffers = {};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Append a new reading for [city].  Oldest entry is dropped when buffer
  /// exceeds [_maxReadings].
  void append(String city, double level, DateTime timestamp) {
    if (level <= 0) return; // ignore zero / uninitialised readings
    final key = _norm(city);
    final buf = _buffers.putIfAbsent(key, () => []);
    buf.add(RiverLevelSnapshot(level: level, timestamp: timestamp));
    if (buf.length > _maxReadings) buf.removeAt(0);
  }

  /// Return a read-only copy of the trend list for [city].
  /// Returns an empty list if no readings have been recorded yet.
  List<RiverLevelSnapshot> get(String city) {
    final key = _norm(city);
    final buf = _buffers[key];
    if (buf == null || buf.isEmpty) return const [];
    return List.unmodifiable(buf);
  }

  /// True when at least 2 readings exist for [city] (minimum for a sparkline).
  bool hasData(String city) => get(city).length >= 2;

  /// Clear all buffers (useful for testing).
  void clear() => _buffers.clear();

  // ── Internal ──────────────────────────────────────────────────────────────

  static String _norm(String city) => city.toLowerCase().trim();
}
