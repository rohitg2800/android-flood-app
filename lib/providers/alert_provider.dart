// lib/providers/alert_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/alert_engine.dart';
import 'data_fetch_provider.dart';

final alertProviderInstance = ChangeNotifierProvider<AlertProvider>(
  (ref) {
    final provider = AlertProvider();
    ref.listen<List<FloodAlert>>(alertsProvider, (_, alerts) {
      provider._onAlerts(alerts);
    });
    return provider;
  },
);

// Alias so legacy screens can still do ref.watch(alertProvider)
final alertProvider = alertProviderInstance;

class AlertProvider extends ChangeNotifier {
  List<FloodAlert> _alerts = [];

  List<FloodAlert> get all      => _alerts;
  List<FloodAlert> get danger   => _alerts.where((a) =>
      a.severity == AlertSeverity.critical ||
      a.severity == AlertSeverity.emergency).toList();
  List<FloodAlert> get warnings => _alerts.where(
      (a) => a.severity == AlertSeverity.warning).toList();
  List<FloodAlert> get watches  => _alerts.where(
      (a) => a.severity == AlertSeverity.info).toList();

  int get dangerCount =>
      _alerts.where((a) =>
          a.severity == AlertSeverity.critical ||
          a.severity == AlertSeverity.emergency).length;
  int get infoCount =>
      _alerts.where((a) => a.severity == AlertSeverity.info).length;

  bool _didNotify = false;
  bool get didNotify => _didNotify;

  static String _fp(List<FloodAlert> list) {
    final tokens = list.map((a) => '${a.id}:${a.severity.name}').toList()
      ..sort();
    return tokens.join(',');
  }

  void _onAlerts(List<FloodAlert> incoming) {
    if (_fp(incoming) == _fp(_alerts)) return;
    _alerts = List.unmodifiable(incoming);
    _didNotify = false;
    notifyListeners();
  }
}
