import 'package:dio/dio.dart';
import '../models/pump_station.dart';

class PumpStationRepository {
  final Dio _dio;
  PumpStationRepository(this._dio);

  Future<List<PumpStation>> getPumpStations() async {
    final response = await _dio.get('/api/pump-stations');
    return (response.data as List)
        .map((e) => PumpStation.fromJson(e))
        .toList();
  }

  Future<PumpStation> getPumpStationById(String id) async {
    final response = await _dio.get('/api/pump-stations/$id');
    return PumpStation.fromJson(response.data);
  }
}
