// lib/models/map_station_data.dart
// MapStationData — lightweight view-model used by BiharRiverMapScreen
// and mapLiveIndexProvider to represent a station's live state on the map.

class MapStationData {
  final String station;
  final String river;
  final String city;
  final String district;
  final String riskLabel; // CRITICAL / SEVERE / HIGH / MODERATE / LOW / NORMAL
  final double? currentLevel;
  final double? dangerLevel;
  final double? warningLevel;
  final double? rainfall24h;
  final String? trend; // 'rising' / 'falling' / 'stable'
  final bool isLive; // false = static / no-data pin

  const MapStationData({
    required this.station,
    required this.river,
    required this.city,
    this.district = '',
    required this.riskLabel,
    this.currentLevel,
    this.dangerLevel,
    this.warningLevel,
    this.rainfall24h,
    this.trend,
    this.isLive = true,
  });

  /// Build a MapStationData from a BiharStationData (bihar_live_provider).
  factory MapStationData.fromBiharStation(dynamic s) => MapStationData(
        station: s.city as String,
        river: s.river as String,
        city: s.city as String,
        district: (s.district as String?) ?? '',
        riskLabel: s.riskLabel as String,
        currentLevel: s.currentLevel as double?,
        dangerLevel: s.dangerLevel as double?,
        warningLevel: s.warningLevel as double?,
        rainfall24h: s.rainfall24h as double?,
        trend: _normTrend(s.trend as String?),
        isLive: (s.source as String?) == 'LIVE',
      );

  static String? _normTrend(String? raw) {
    if (raw == null) return null;
    if (raw.contains('↑') || raw.toLowerCase().contains('ris')) return 'rising';
    if (raw.contains('↓') || raw.toLowerCase().contains('fal'))
      return 'falling';
    return 'stable';
  }
}
