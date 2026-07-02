import 'package:freezed_annotation/freezed_annotation.dart';

part 'pump_station.freezed.dart';
part 'pump_station.g.dart';

@freezed
class PumpStation with _$PumpStation {
  const factory PumpStation({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required String status,
    required double capacity,
    required double currentLoad,
    String? address,
    String? zone,
    DateTime? lastUpdated,
  }) = _PumpStation;

  factory PumpStation.fromJson(Map<String, dynamic> json) =>
      _$PumpStationFromJson(json);
}
