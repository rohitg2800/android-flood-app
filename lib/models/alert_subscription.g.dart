// GENERATED CODE — DO NOT MODIFY BY HAND
// alert_subscription.g.dart  (pre-generated, Step 3.1)
// ignore_for_file: type=lint

part of 'alert_subscription.dart';

class AlertSubscriptionAdapter extends TypeAdapter<AlertSubscription> {
  @override
  final int typeId = 10;

  @override
  AlertSubscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertSubscription(
      stationId: fields[0] as String,
      cityName: fields[1] as String,
      riverName: fields[2] as String,
      customThresholdMetres: fields[3] as double?,
      notifyRadiusKm: fields[4] as double,
      breachOnlyMode: fields[5] as bool,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AlertSubscription obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.stationId)
      ..writeByte(1)
      ..write(obj.cityName)
      ..writeByte(2)
      ..write(obj.riverName)
      ..writeByte(3)
      ..write(obj.customThresholdMetres)
      ..writeByte(4)
      ..write(obj.notifyRadiusKm)
      ..writeByte(5)
      ..write(obj.breachOnlyMode)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertSubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
