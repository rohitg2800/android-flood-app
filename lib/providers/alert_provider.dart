// lib/providers/alert_provider.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// FloodAlert here comes from alert_engine.dart (re-exported by alerts_provider.dart).
// Do NOT import models/flood_alert.dart — it defines a second FloodAlert class
// that is incompatible with the type returned by alertsProvider.
import 'alerts_provider.dart';

// alertsProvider is Provider<List<FloodAlert>> (from data_fetch_provider.dart).
// We watch it directly — no ThresholdAlert bridge needed.
final alertProvider = Provider<AlertProvider>((ref) {
  final notifier = AlertProvider();

  // Seed immediately with current value, then keep in sync.
  notifier._onAlerts(ref.read(alertsProvider));

  ref.listen<List<FloodAlert>>(
    alertsProvider,
    (_, next) => notifier._onAlerts(next),
  );

  ref.onDispose(notifier.dispose);

  return notifier;
});

class AlertProvider extends ChangeNotifier {
  List<FloodAlert> _alerts = [];

  List<FloodAlert> get all => _alerts;

  /// Danger = critical or emergency severity.
  List<FloodAlert> get danger =>
      _alerts.where((a) =>
          a.severity == AlertSeverity.critical ||
          a.severity == AlertSeverity.emergency).toList();

  /// Warnings = warning severity.
  List<FloodAlert> get warnings =>
      _alerts.where((a) => a.severity == AlertSeverity.warning).toList();

  /// Watches = info severity.
  List<FloodAlert> get watches =>
      _alerts.where((a) => a.severity == AlertSeverity.info).toList();

  int get dangerCount  => danger.length;
  int get warningCount => warnings.length;
  int get watchCount   => watches.length;
  int get totalCount   => _alerts.length;

  /// Stations currently at normal / info level (not warning or above).
  int get normalCount =>
      _alerts.where((a) => a.severity == AlertSeverity.info).length;

  bool get hasCritical => danger.isNotEmpty;

  void _onAlerts(List<FloodAlert> alerts) {
    _alerts = [...alerts]
      ..sort((a, b) => b.severity.priority.compareTo(a.severity.priority));
    notifyListeners();
  }
}
