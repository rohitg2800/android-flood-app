import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/providers/live_engine_bridge_provider.dart';
import 'package:equinox_flood/models/river_station.dart';
import '../domain/map_station.dart';

MapStationSeverity _toSeverity(RiverStation s) {
  if (s.current <= 0) return MapStationSeverity.noData;
  if (s.current >= s.danger) return MapStationSeverity.critical;
  if (s.current >= s.warning * 1.1) return MapStationSeverity.severe;
  if (s.current >= s.warning) return MapStationSeverity.warning;
  return MapStationSeverity.normal;
}

final mapStationsProvider = Provider<List<MapStation>>((ref) {
  final stations = ref.watch(liveEngineStationsProvider);
  return stations
      .where((s) => (s.lat ?? 0) != 0 && (s.lon ?? 0) != 0)
      .map((s) => MapStation(
            id: s.station,
            name: s.city,
            river: s.river,
            lat: s.lat ?? 0,
            lon: s.lon ?? 0,
            current: s.current,
            warning: s.warning,
            danger: s.danger,
            severity: _toSeverity(s),
          ))
      .toList();
});

final mapCriticalCountProvider = Provider<int>((ref) {
  return ref
      .watch(mapStationsProvider)
      .where((s) => s.severity == MapStationSeverity.critical)
      .length;
});
