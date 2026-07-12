// GENERATED CODE - DO NOT MODIFY BY HAND
// Hand-written stub — regenerate with: dart run build_runner build

part of 'community_incident.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IncidentTypeAdapter extends TypeAdapter<IncidentType> {
  @override
  final int typeId = 30;

  @override
  IncidentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncidentType.flooding;
      case 1:
        return IncidentType.embankmentBreach;
      case 2:
        return IncidentType.roadBlocked;
      case 3:
        return IncidentType.waterlogging;
      case 4:
        return IncidentType.evacuationNeeded;
      case 5:
        return IncidentType.rescueNeeded;
      case 6:
        return IncidentType.infrastructureDamage;
      case 7:
        return IncidentType.other;
      default:
        return IncidentType.flooding;
    }
  }

  @override
  void write(BinaryWriter writer, IncidentType obj) {
    switch (obj) {
      case IncidentType.flooding:
        writer.writeByte(0);
        break;
      case IncidentType.embankmentBreach:
        writer.writeByte(1);
        break;
      case IncidentType.roadBlocked:
        writer.writeByte(2);
        break;
      case IncidentType.waterlogging:
        writer.writeByte(3);
        break;
      case IncidentType.evacuationNeeded:
        writer.writeByte(4);
        break;
      case IncidentType.rescueNeeded:
        writer.writeByte(5);
        break;
      case IncidentType.infrastructureDamage:
        writer.writeByte(6);
        break;
      case IncidentType.other:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncidentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CommunityIncidentAdapter extends TypeAdapter<CommunityIncident> {
  @override
  final int typeId = 31;

  @override
  CommunityIncident read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CommunityIncident(
      id: fields[0] as String,
      type: fields[1] as IncidentType,
      headline: fields[2] as String,
      description: fields[3] as String,
      lat: fields[4] as double,
      lng: fields[5] as double,
      district: fields[6] as String,
      reportedAt: fields[7] as DateTime,
      submittedBy: fields[8] as String,
      photoUrls: (fields[9] as List).cast<String>(),
      verified: fields[10] as bool,
      upvotes: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CommunityIncident obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.headline)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.lat)
      ..writeByte(5)
      ..write(obj.lng)
      ..writeByte(6)
      ..write(obj.district)
      ..writeByte(7)
      ..write(obj.reportedAt)
      ..writeByte(8)
      ..write(obj.submittedBy)
      ..writeByte(9)
      ..write(obj.photoUrls)
      ..writeByte(10)
      ..write(obj.verified)
      ..writeByte(11)
      ..write(obj.upvotes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityIncidentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
