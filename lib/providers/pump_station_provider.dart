import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pump_station.dart';
import '../repositories/pump_station_repository.dart';
import 'dio_provider.dart';

final pumpStationRepositoryProvider = Provider<PumpStationRepository>(
  (ref) => PumpStationRepository(ref.watch(dioProvider)),
);

final pumpStationsProvider = FutureProvider<List<PumpStation>>(
  (ref) => ref.watch(pumpStationRepositoryProvider).getPumpStations(),
);
