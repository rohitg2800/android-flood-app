// lib/providers/alert_provider.dart  v1.1
//
// v1.1 — UX: cooldown guard stops alert list thrashing on rapid data polls.
//
// PROBLEM: alertsProvider is a plain Provider<List<FloodAlert>> that rebuilds
// on every mergedStationsProvider update.  Even with stable issuedAt timestamps
// (fixed in alert_engine v1.3), Riverpod still calls _onAlerts() on every poll
// cycle and notifyListeners() triggers widgets to rebuild — causing visible
// flicker on the AlertsScreen list.
//
// FIX: _onAlerts() now computes a lightweight fingerprint of the incoming list
// (sorted alert IDs + severity names).  It only calls notifyListeners() when
// the fingerprint changes, i.e. when alerts are genuinely added, removed, or
// upgraded in severity.  Pure level-value updates within the same severity
// bucket are silently absorbed.
//
// The fingerprint is O(n) over the number of alerts — negligible.

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'alerts_provider.dart';

final alertProvider = Provider<AlertProvider>((ref) {
  final notifier = AlertProvider();

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
  String _fingerprint = '';

  List<FloodAlert> get all      => _alerts;
  List<FloodAlert> get danger   => _alerts.where((a) =>
      a.severity == AlertSeverity.critical ||
      a.severity == AlertSeverity.emergency).toList();
  List<FloodAlert> get warnings => _alerts.where(
      (a) => a.severity == AlertSeverity.warning).toList();
  List<FloodAlert> get watches  => _alerts.where(
      (a) => a.severity == AlertSeverity.info).toList();

  int  get dangerCount  => danger.length;
  int  get warningCount => warnings.length;
  int  get watchCount   => watches.length;
  int  get totalCount   => _alerts.length;
  int  get normalCount  =>
      _alerts.where((a) => a.severity == AlertSeverity.info).length;
  bool get hasCritical  => danger.isNotEmpty;

  // ── Cooldown guard ────────────────────────────────────────────────────────
  //
  // Fingerprint = sorted "id:severity" tokens joined with '|'.
  // Two lists that differ only in currentLevel values (same IDs + severities)
  // produce the same fingerprint → no rebuild → no UI flicker.
  static String _fp(List<FloodAlert> list) {
    final tokens = list.map((a) => '${a.id}:${a.severity.name}').toList()
      ..sort();
    return tokens.join('|');
  }

  void _onAlerts(List<FloodAlert> incoming) {
    final sorted = [...incoming]
      ..sort((a, b) {
        final sc = b.severity.priority.compareTo(a.severity.priority);
        return sc != 0 ? sc : b.issuedAt.compareTo(a.issuedAt);
      });

    final newFp = _fp(sorted);
    if (newFp == _fingerprint) return; // nothing changed — skip rebuild

    _alerts      = sorted;
    _fingerprint = newFp;
    notifyListeners();
  }
}
