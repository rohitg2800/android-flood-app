// lib/providers/alert_provider.dart
// OpsFlood — AlertProvider (Riverpod ChangeNotifier)
//
// Facade over the existing alertsProvider (alerts_provider.dart) that
// exposes FloodAlert objects so screens importing this path compile.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_alert.dart' as fa;
import '../models/threshold_alert.dart' as ta;
import 'alerts_provider.dart';

// ─── Riverpod provider ────────────────────────────────────────────────────────

final alertProvider = ChangeNotifierProvider<AlertProvider>((ref) {
  final notifier = AlertProvider();

  // Keep in sync with the canonical alertsProvider stream.
  ref.listen<AsyncValue<List<ta.ThresholdAlert>>>(
    alertsProvider,
    (_, next) => next.whenData(notifier._onAlerts),
    fireImmediately: true,
  );

  return notifier;
});

// ─── AlertProvider ────────────────────────────────────────────────────────────

class AlertProvider extends ChangeNotifier {
  List<fa.FloodAlert> _alerts = [];

  // ── Getters ──────────────────────────────────────────────────────────────

  /// All non-normal alerts, sorted most-severe first.
  List<fa.FloodAlert> get all => _alerts;

  List<fa.FloodAlert> get danger =>
      _alerts
          .where((a) =>
              a.level == fa.AlertLevel.danger ||
              a.level == fa.AlertLevel.extreme)
          .toList();

  List<fa.FloodAlert> get warnings =>
      _alerts.where((a) => a.level == fa.AlertLevel.warning).toList();

  List<fa.FloodAlert> get watches =>
      _alerts.where((a) => a.level == fa.AlertLevel.watch).toList();

  int  get dangerCount  => danger.length;
  int  get warningCount => warnings.length;
  int  get watchCount   => watches.length;
  int  get totalCount   => _alerts.length;
  bool get hasCritical  => danger.isNotEmpty;

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onAlerts(List<ta.ThresholdAlert> raw) {
    _alerts = raw
        .where((a) => a.level != ta.AlertLevel.normal)
        .map(_toFloodAlert)
        .toList()
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    notifyListeners();
  }

  static fa.FloodAlert _toFloodAlert(ta.ThresholdAlert src) {
    return fa.FloodAlert(
      id:           src.id,
      cityId:       src.cityId,
      cityName:     src.cityName,
      river:        src.river,
      state:        src.state,
      currentValue: src.currentValue,
      dangerLevel:  src.dangerLevel,
      warningLevel: src.warningLevel,
      fillPercent:  src.fillPercent,
      level:        _mapLevel(src.level),
      issuedAt:     src.timestamp,
    );
  }

  static fa.AlertLevel _mapLevel(ta.AlertLevel l) => switch (l) {
    ta.AlertLevel.watch   => fa.AlertLevel.watch,
    ta.AlertLevel.warning => fa.AlertLevel.warning,
    ta.AlertLevel.danger  => fa.AlertLevel.danger,
    ta.AlertLevel.extreme => fa.AlertLevel.extreme,
    _                     => fa.AlertLevel.normal,
  };
}
