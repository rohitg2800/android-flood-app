// GENERATED CODE — DO NOT MODIFY BY HAND
// Pre-generated Hive TypeAdapter for AlertSubscription (Step 3.1)
// Replaces build_runner output (removed due to analyzer conflict).

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
      stationId:            fields[0] as String,
      cityName:             fields[1] as String,
      customThresholdLevel: fields[2] as double?,
      notifyOnBreachOnly:   fields[3] as bool,
      radiusKm:             fields[4] as double,
      createdAt:            fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AlertSubscription obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)..write(obj.stationId)
      ..writeByte(1)..write(obj.cityName)
      ..writeByte(2)..write(obj.customThresholdLevel)
      ..writeByte(3)..write(obj.notifyOnBreachOnly)
      ..writeByte(4)..write(obj.radiusKm)
      ..writeByte(5)..write(obj.createdAt);
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
