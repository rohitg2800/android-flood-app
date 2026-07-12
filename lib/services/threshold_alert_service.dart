// lib/services/threshold_alert_service.dart
// OpsFlood — ThresholdAlertService
// Polls live data and exposes a Stream<List<ThresholdAlert>> for AlertsProvider.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/threshold_alert.dart';
import 'live_fetch_engine.dart';
import 'alert_evaluator.dart';

class ThresholdAlertService {
  ThresholdAlertService._();
  static final ThresholdAlertService instance = ThresholdAlertService._();

  final LiveFetchEngine _engine = LiveFetchEngine();
  Timer? _timer;
  bool _running = false;

  static const _checkInterval = Duration(minutes: 10);

  // ── Stream ───────────────────────────────────────────────────────────
  final _controller = StreamController<List<ThresholdAlert>>.broadcast();
  Stream<List<ThresholdAlert>> get stream => _controller.stream;

  List<ThresholdAlert> _current = [];
  List<ThresholdAlert> get currentAlerts => List.unmodifiable(_current);

  // ── Unread badge ──────────────────────────────────────────────────────
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // ── Lifecycle ─────────────────────────────────────────────────────────
  Future<void> start() async {
    if (_running) return;
    _running = true;
    if (kDebugMode) debugPrint('[ThresholdAlertService] started');
    await _check();
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    if (kDebugMode) debugPrint('[ThresholdAlertService] stopped');
  }

  // ── Public API ────────────────────────────────────────────────────────
  Future<void> refresh() async => _check();

  Future<void> markAllSeen() async {
    _unreadCount = 0;
    _current = _current.map((a) => a.copyWith(isSeen: true)).toList();
    _controller.add(_current);
  }

  // ── Internal ──────────────────────────────────────────────────────────
  Future<void> _check() async {
    try {
      await _engine.refreshData();
      final raw = _engine.criticalAlerts;
      final alerts = raw
          .map((m) => AlertEvaluator.fromDischarge(
                cityId: (m['city_id'] ?? m['city'] ?? '').toString(),
                cityName: (m['city'] ?? '').toString(),
                state: (m['state'] ?? '').toString(),
                river: (m['river'] ?? '').toString(),
                dischargeM3s: (m['value'] as num? ?? 0).toDouble(),
                warningDischarge: (m['warning'] as num? ?? 0).toDouble(),
                dangerDischarge: (m['danger'] as num? ?? 0).toDouble(),
                hflDischarge: (m['hfl'] as num? ?? 0).toDouble(),
              ))
          .whereType<ThresholdAlert>()
          .toList();

      final prevIds = {for (final a in _current) a.cityId};
      final newCount = alerts.where((a) => !prevIds.contains(a.cityId)).length;
      _unreadCount += newCount;
      _current = alerts;
      _controller.add(_current);

      if (kDebugMode && alerts.isNotEmpty) {
        debugPrint('[ThresholdAlertService] ${alerts.length} alert(s) emitted');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ThresholdAlertService] _check error: $e');
    }
  }
}
