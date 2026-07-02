// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pump_station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PumpStationImpl _$$PumpStationImplFromJson(Map<String, dynamic> json) =>
    _$PumpStationImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String,
      capacity: (json['capacity'] as num).toDouble(),
      currentLoad: (json['currentLoad'] as num).toDouble(),
      address: json['address'] as String?,
      zone: json['zone'] as String?,
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$$PumpStationImplToJson(_$PumpStationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'status': instance.status,
      'capacity': instance.capacity,
      'currentLoad': instance.currentLoad,
      'address': instance.address,
      'zone': instance.zone,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };
