// Phase 2 – Motor Control Service
import 'package:dio/dio.dart';
import '../models/pump_station.dart';
import 'api_client.dart';

class MotorService {
  final Dio _dio;

  MotorService(this._dio);

  Future<List<PumpStation>> getPumpStations({
    String? district,
    String? status,
  }) async {
    final resp = await _dio.get(
      '/pump-stations',
      queryParameters: {
        if (district != null) 'district': district,
        if (status != null) 'status_filter': status,
      },
    );
    return (resp.data as List)
        .map((e) => PumpStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PumpStation> getPumpStation(String stationId) async {
    final resp = await _dio.get('/pump-stations/$stationId');
    return PumpStation.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<MotorLog> triggerMotorAction({
    required String stationId,
    required MotorAction action,
    String? reason,
    int? waterLevelRefId,
  }) async {
    final resp = await _dio.post(
      '/pump-stations/$stationId/motor-action',
      data: {
        'action': action.name.replaceAll(
            RegExp(r'(?<=[a-z])(?=[A-Z])'), '-').toLowerCase(),
        if (reason != null) 'reason': reason,
        if (waterLevelRefId != null) 'water_level_ref_id': waterLevelRefId,
      },
    );
    return MotorLog.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<MotorLog>> getMotorLogs(String stationId,
      {int limit = 50}) async {
    final resp = await _dio.get(
      '/pump-stations/$stationId/motor-logs',
      queryParameters: {'limit': limit},
    );
    return (resp.data as List)
        .map((e) => MotorLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
