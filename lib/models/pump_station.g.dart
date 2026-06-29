// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pump_station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PumpStationImpl _$$PumpStationImplFromJson(Map<String, dynamic> json) =>
    _$PumpStationImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String?,
      state: json['state'] as String? ?? 'Bihar',
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
      status: json['status'] == null
          ? StationStatus.inactive
          : $enumDecode(_$StationStatusEnumMap, json['status']),
      capacityLps: (json['capacityLps'] as num?)?.toDouble(),
      installedAt: json['installedAt'] == null
          ? null
          : DateTime.parse(json['installedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$PumpStationImplToJson(_$PumpStationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'district': instance.district,
      'state': instance.state,
      'locationLat': instance.locationLat,
      'locationLng': instance.locationLng,
      'status': _$StationStatusEnumMap[instance.status]!,
      'capacityLps': instance.capacityLps,
      'installedAt': instance.installedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$StationStatusEnumMap = {
  StationStatus.active: 'active',
  StationStatus.inactive: 'inactive',
  StationStatus.fault: 'fault',
};

_$MotorLogImpl _$$MotorLogImplFromJson(Map<String, dynamic> json) =>
    _$MotorLogImpl(
      id: (json['id'] as num).toInt(),
      pumpStationId: json['pumpStationId'] as String,
      triggeredBy: json['triggeredBy'] as String?,
      action: $enumDecode(_$MotorActionEnumMap, json['action']),
      reason: json['reason'] as String?,
      waterLevelRefId: (json['waterLevelRefId'] as num?)?.toInt(),
      loggedAt: DateTime.parse(json['loggedAt'] as String),
    );

Map<String, dynamic> _$$MotorLogImplToJson(_$MotorLogImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pumpStationId': instance.pumpStationId,
      'triggeredBy': instance.triggeredBy,
      'action': _$MotorActionEnumMap[instance.action]!,
      'reason': instance.reason,
      'waterLevelRefId': instance.waterLevelRefId,
      'loggedAt': instance.loggedAt.toIso8601String(),
    };

const _$MotorActionEnumMap = {
  MotorAction.start: 'start',
  MotorAction.stop: 'stop',
  MotorAction.autoTrigger: 'autoTrigger',
  MotorAction.faultReset: 'faultReset',
};
