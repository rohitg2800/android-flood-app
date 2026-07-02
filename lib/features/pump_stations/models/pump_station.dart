import 'package:freezed_annotation/freezed_annotation.dart';

part 'pump_station.freezed.dart';
part 'pump_station.g.dart';

enum PumpStationStatus { operational, faulty, offline, maintenance }

@freezed
class PumpStation with _$PumpStation {
  const factory PumpStation({
    required String id,
    required String name,
    required String location,
    required double latitude,
    required double longitude,
    required PumpStationStatus status,
    required double capacityLitersPerSecond,
    required double currentFlowRate,
    String? districtName,
    String? lastInspectedAt,
    String? notes,
  }) = _PumpStation;

  factory PumpStation.fromJson(Map<String, dynamic> json) =>
      _$PumpStationFromJson(json);
}
