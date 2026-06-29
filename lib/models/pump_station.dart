// Phase 2 – Pump Station & Motor Log models
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pump_station.freezed.dart';
part 'pump_station.g.dart';

enum MotorAction { start, stop, autoTrigger, faultReset }
enum StationStatus { active, inactive, fault }

@freezed
class PumpStation with _$PumpStation {
  const factory PumpStation({
    required String id,
    required String name,
    String? district,
    @Default('Bihar') String state,
    double? locationLat,
    double? locationLng,
    @Default(StationStatus.inactive) StationStatus status,
    double? capacityLps,
    DateTime? installedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PumpStation;

  factory PumpStation.fromJson(Map<String, dynamic> json) =>
      _$PumpStationFromJson(json);
}

@freezed
class MotorLog with _$MotorLog {
  const factory MotorLog({
    required int id,
    required String pumpStationId,
    String? triggeredBy,
    required MotorAction action,
    String? reason,
    int? waterLevelRefId,
    required DateTime loggedAt,
  }) = _MotorLog;

  factory MotorLog.fromJson(Map<String, dynamic> json) =>
      _$MotorLogFromJson(json);
}
