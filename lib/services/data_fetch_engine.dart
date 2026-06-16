// lib/services/data_fetch_engine.dart  v2
// Added:
//   • SourceStatus enum  (used by dashboard_footer, system_stats widgets)
//   • stream getter that broadcasts FetchResult events
//   • latestResult getter
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flood_data.dart';
import 'flood_api.dart';

// ─ SourceStatus ─────────────────────────────────────────────────────────
enum SourceStatus { idle, fetching, success, error, stale }

extension SourceStatusExt on SourceStatus {
  bool get isLive    => this == SourceStatus.success;
  bool get isFailing => this == SourceStatus.error;
  bool get isStale   => this == SourceStatus.stale;
  String get label   => switch (this) {
    SourceStatus.idle     => 'Idle',
    SourceStatus.fetching => 'Fetching',
    SourceStatus.success  => 'Live',
    SourceStatus.error    => 'Error',
    SourceStatus.stale    => 'Stale',
  };
}

// ─ FetchResult ──────────────────────────────────────────────────────────
class FetchResult {
  final List<FloodData> data;
  final SourceStatus    status;
  final DateTime        fetchedAt;
  final String?         error;

  const FetchResult({
    required this.data,
    required this.status,
    required this.fetchedAt,
    this.error,
  });

  bool get isSuccess => status == SourceStatus.success;
  int  get alertCount => data.where((d) => d.currentLevel >= d.warningLevel).length;
}

// ─ DataFetchEngine ─────────────────────────────────────────────────────────
class DataFetchEngine {
  DataFetchEngine._();
  static final DataFetchEngine instance = DataFetchEngine._();

  static const _kInterval = Duration(minutes: 5);

  final _controller = StreamController<FetchResult>.broadcast();
  Timer?       _timer;
  FetchResult? _latest;
  SourceStatus _status = SourceStatus.idle;

  // ─ Public API ─────────────────────────────────────────────────────────

  /// Broadcast stream of [FetchResult] events.
  Stream<FetchResult> get stream => _controller.stream;

  /// Latest fetch result; null before first fetch.
  FetchResult? get latestResult => _latest;

  /// Current data-source status.
  SourceStatus get status => _status;

  /// Start periodic fetching every 5 minutes.
  void start() {
    _timer?.cancel();
    _fetch();
    _timer = Timer.periodic(_kInterval, (_) => _fetch());
  }

  /// Stop periodic fetching.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _status = SourceStatus.idle;
  }

  /// Force an immediate refresh.
  Future<void> refresh() => _fetch();

  /// Dispose the engine (call on app teardown).
  void dispose() {
    stop();
    _controller.close();
  }

  // ─ Internals ─────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    _status = SourceStatus.fetching;
    try {
      final data = await FloodApi.instance.fetchAll();
      final result = FetchResult(
        data:      data,
        status:    SourceStatus.success,
        fetchedAt: DateTime.now(),
      );
      _latest = result;
      _status = SourceStatus.success;
      if (!_controller.isClosed) _controller.add(result);
      if (kDebugMode) debugPrint('[DataFetchEngine] fetched ${data.length} stations');
    } catch (e) {
      final stale  = _latest?.data ?? [];
      final result = FetchResult(
        data:      stale,
        status:    stale.isEmpty ? SourceStatus.error : SourceStatus.stale,
        fetchedAt: DateTime.now(),
        error:     e.toString(),
      );
      _latest = result;
      _status = result.status;
      if (!_controller.isClosed) _controller.add(result);
      if (kDebugMode) debugPrint('[DataFetchEngine] fetch error: $e');
    }
  }
}
