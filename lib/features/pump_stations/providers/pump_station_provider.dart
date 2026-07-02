import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/pump_stations/models/pump_station.dart';
import 'package:equinox_flood/features/pump_stations/repositories/pump_station_repository.dart';

final pumpStationsProvider =
    FutureProvider<List<PumpStation>>((ref) async {
  final repo = ref.watch(pumpStationRepositoryProvider);
  return repo.fetchAll();
});

final pumpStationDetailProvider =
    FutureProvider.family<PumpStation, String>((ref, id) async {
  final repo = ref.watch(pumpStationRepositoryProvider);
  return repo.fetchById(id);
});
