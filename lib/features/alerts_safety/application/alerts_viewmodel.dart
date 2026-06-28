import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/providers/live_engine_bridge_provider.dart';
import '../domain/alert_item.dart';

final alertsViewModelProvider = Provider<List<AlertItem>>((ref) {
  final stations = ref.watch(liveEngineStationsProvider);

  return stations
      .where((s) => s.current > 0 && s.current >= s.warning)
      .map((s) {
        AlertSeverity sev;
        if (s.current >= s.danger)        sev = AlertSeverity.critical;
        else if (s.current >= s.warning)  sev = AlertSeverity.warning;
        else                              sev = AlertSeverity.info;

        return AlertItem(
          id:       s.station,
          title:    '\${s.city} — \${sev.name.toUpperCase()}',
          message:  'Level \${s.current.toStringAsFixed(2)}m of \${s.danger.toStringAsFixed(2)}m danger',
          station:  s.city,
          severity: sev,
          time:     DateTime.now(),
        );
      })
      .toList()
    ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
});

final alertsCountProvider = Provider<int>((ref) {
  return ref.watch(alertsViewModelProvider).length;
});

final criticalAlertsProvider = Provider<List<AlertItem>>((ref) {
  return ref.watch(alertsViewModelProvider)
      .where((a) => a.isUrgent)
      .toList();
});