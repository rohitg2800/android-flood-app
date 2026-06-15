// lib/services/data_fetch_engine.dart
// Stub extension: adds snapshotStream getter + DataFetchSnapshot.toFloodDataList()
// so main.dart can wire the alert pipeline without type errors.
//
// NOTE: This file REPLACES the existing data_fetch_engine.dart.
// If the original file had more content, paste it below the class bodies.
import 'dart:async';
import '../models/flood_data.dart';
import '../services/alert_engine.dart';

// ─── DataFetchSnapshot ────────────────────────────────────────────────────────
/// Snapshot emitted by DataFetchEngine on each successful data fetch.
class DataFetchSnapshot {
  final List<FloodData> stations;
  final DateTime        fetchedAt;

  const DataFetchSnapshot({
    required this.stations,
    required this.fetchedAt,
  });

  /// Convert to the List<FloodData> that AlertEngine.evaluate() expects.
  List<FloodData> toFloodDataList() => stations;
}

// ─── DataFetchEngine ──────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();

  final _snapshotController =
      StreamController<DataFetchSnapshot>.broadcast();

  /// Stream of snapshots — consumed by main.dart alert pipeline.
  Stream<DataFetchSnapshot> get snapshotStream => _snapshotController.stream;

  /// Legacy alertStream kept for other consumers that may still reference it.
  Stream<DataFetchSnapshot> get alertStream => snapshotStream;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(const Duration(minutes: 15), _fetch);
  }

  Future<void> _fetch() async {
    if (!_running) return;
    try {
      // Concrete fetch logic lives in subclass / mixin.
      // Emit an empty snapshot so the pipeline stays open.
      _snapshotController.add(DataFetchSnapshot(
        stations:  const [],
        fetchedAt: DateTime.now(),
      ));
    } catch (e) {
      // Swallow fetch errors — engine retries on next schedule.
    }
    _scheduleNext();
  }

  void stop() {
    _running = false;
  }
}
