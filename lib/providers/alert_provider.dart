// lib/providers/alert_provider.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_alert.dart' as fa;
import 'alerts_provider.dart';

// alertsProvider is Provider<List<FloodAlert>> (from data_fetch_provider.dart).
// We watch it directly — no ThresholdAlert bridge needed.
final alertProvider = Provider<AlertProvider>((ref) {
  final notifier = AlertProvider();

  // Seed immediately with current value, then keep in sync.
  notifier._onAlerts(ref.read(alertsProvider));

  ref.listen<List<fa.FloodAlert>>(
    alertsProvider,
    (_, next) => notifier._onAlerts(next),
  );

  ref.onDispose(notifier.dispose);

  return notifier;
});

class AlertProvider extends ChangeNotifier {
  List<fa.FloodAlert> _alerts = [];

  List<fa.FloodAlert> get all => _alerts;

  List<fa.FloodAlert> get danger =>
      _alerts.where((a) =>
          a.level == fa.AlertLevel.danger ||
          a.level == fa.AlertLevel.extreme).toList();

  List<fa.FloodAlert> get warnings =>
      _alerts.where((a) => a.level == fa.AlertLevel.warning).toList();

  List<fa.FloodAlert> get watches =>
      _alerts.where((a) => a.level == fa.AlertLevel.watch).toList();

  int  get dangerCount  => danger.length;
  int  get warningCount => warnings.length;
  int  get watchCount   => watches.length;
  int  get totalCount   => _alerts.length;

  /// Stations currently at normal / watch level (not warning or above).
  int  get normalCount  =>
      _alerts.where((a) =>
          a.level == fa.AlertLevel.normal ||
          a.level == fa.AlertLevel.watch).length;

  bool get hasCritical => danger.isNotEmpty;

  void _onAlerts(List<fa.FloodAlert> alerts) {
    _alerts = [...alerts]
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    notifyListeners();
  }
}
