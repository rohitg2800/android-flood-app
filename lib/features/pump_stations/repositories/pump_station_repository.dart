import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/pump_stations/models/pump_station.dart';
import 'package:equinox_flood/core/network/dio_client.dart';

class PumpStationRepository {
  final Dio _dio;

  PumpStationRepository(this._dio);

  Future<List<PumpStation>> fetchAll() async {
    final response = await _dio.get('/api/pump-stations');
    final List data = response.data as List;
    return data
        .map((e) => PumpStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PumpStation> fetchById(String id) async {
    final response = await _dio.get('/api/pump-stations/$id');
    return PumpStation.fromJson(response.data as Map<String, dynamic>);
  }
}

final pumpStationRepositoryProvider = Provider<PumpStationRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return PumpStationRepository(dio);
});
