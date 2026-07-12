// Phase 2 – Motor Control Service
import 'package:dio/dio.dart';
import '../models/pump_station.dart';
import 'api_client.dart';
import 'motor_models.dart';

enum MotorAction { startPump, stopPump, emergencyStop, setSchedule }

class MotorLog {
  final String id;
  final String stationId;
  final MotorAction action;
  final DateTime timestamp;
  final String? reason;
  final bool success;

  const MotorLog({
    required this.id,
    required this.stationId,
    required this.action,
    required this.timestamp,
    this.reason,
    required this.success,
  });

  factory MotorLog.fromJson(Map<String, dynamic> j) => MotorLog(
    id:        j['id'] as String,
    stationId: j['station_id'] as String,
    action:    MotorAction.values.byName(
                 (j['action'] as String).replaceAll('-', '_')),
    timestamp: DateTime.parse(j['timestamp'] as String),
    reason:    j['reason'] as String?,
    success:   j['success'] as bool? ?? true,
  );
}

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
        'action': action.name
            .replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), '-')
            .toLowerCase(),
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
