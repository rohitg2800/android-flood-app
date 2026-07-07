class WaterLevelModel {
  final String id;
  final String stationName;
  final double locationLat;
  final double locationLng;
  final double levelMeters;
  final DateTime recordedAt;

  WaterLevelModel({
    required this.id,
    required this.stationName,
    required this.locationLat,
    required this.locationLng,
    required this.levelMeters,
    required this.recordedAt,
  });

  factory WaterLevelModel.fromJson(Map<String, dynamic> json) => WaterLevelModel(
    id: json['id'],
    stationName: json['station_name'],
    locationLat: json['location_lat'],
    locationLng: json['location_lng'],
    levelMeters: json['level_meters'],
    recordedAt: DateTime.parse(json['recorded_at']),
  );
}
