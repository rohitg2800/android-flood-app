// lib/services/stations_unified_bridge.dart
//
// StationsUnifiedBridge — single source of truth for both MapScreen and
// MonitoredStationsScreen.
//
// v1.3: Null-safety — fd.city/state/district/riverName are String? so all
//       usages now use ?? '' fallback.

import '../constants/india_geodata.dart';
import '../models/flood_data.dart';
import 'live_fetch_engine.dart';

class StationMarker {
  final String city;
  final String state;
  final String district;
  final String? river;
  final double lat;
  final double lon;
  final String riskLevel;
  final double capacityPercent;
  final double? currentLevel;
  final double warningLevel;
  final double dangerLevel;
  final double? rainfall24h;
  final double? flowRate;
  final bool hasLiveData;
  final DateTime? lastUpdated;

  const StationMarker({
    required this.city,
    required this.state,
    required this.district,
    this.river,
    required this.lat,
    required this.lon,
    required this.riskLevel,
    required this.capacityPercent,
    this.currentLevel,
    required this.warningLevel,
    required this.dangerLevel,
    this.rainfall24h,
    this.flowRate,
    required this.hasLiveData,
    this.lastUpdated,
  });
}

final _kEpoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
DateTime? _liveTs(DateTime? dt) => (dt == null || dt == _kEpoch) ? null : dt;

class StationsUnifiedBridge {
  StationsUnifiedBridge._();
  static final StationsUnifiedBridge instance = StationsUnifiedBridge._();

  LiveFetchEngine? _engine;
  void attach(LiveFetchEngine engine) => _engine = engine;

  List<FloodData> get allStations {
    final liveMap = <String, FloodData>{};
    if (_engine != null) {
      for (final fd in _engine!.liveFloodData) {
        liveMap[(fd.city ?? '').toLowerCase().trim()] = fd;
      }
    }

    return IndiaGeodata.monitoredCities.map((mc) {
      final key = (mc['city'] as String).toLowerCase().trim();
      if (liveMap.containsKey(key)) return liveMap[key]!;

      final dl = (mc['danger_level'] as num).toDouble();
      final wl = (mc['warning_level'] as num).toDouble();
      final cityName = mc['city'] as String;
      final riverName = mc['river'] as String? ?? '';
      final districtStr = (mc['district'] as String?) ?? '';

      return FloodData(
        stationId: cityName,
        stationName: cityName,
        river: riverName,
        district: districtStr,
        currentLevel: 0.0,
        warningLevel: wl,
        dangerLevel: dl,
        city: cityName,
        state: mc['state'] as String? ?? '',
        riverName: riverName,
        lastUpdated: _kEpoch,
      );
    }).toList();
  }

  List<FloodData> get monitoredStations => allStations;

  List<StationMarker> get markersForMap {
    return allStations.map((fd) {
      final cityKey = (fd.city ?? '').toLowerCase();
      final mc = IndiaGeodata.monitoredCities.firstWhere(
        (c) => (c['city'] as String).toLowerCase() == cityKey,
        orElse: () => {
          'city': fd.city ?? '',
          'state': fd.state ?? '',
          'district': fd.district ?? '',
          'river': fd.riverName ?? '',
          'lat': 25.0,
          'lon': 85.0,
          'danger_level': fd.dangerLevel,
          'warning_level': fd.warningLevel,
        },
      );
      return StationMarker(
        city: fd.city ?? '',
        state: fd.state ?? '',
        district: fd.district ?? '',
        river: fd.riverName,
        lat: (mc['lat'] as num).toDouble(),
        lon: (mc['lon'] as num).toDouble(),
        riskLevel: fd.riskLevel,
        capacityPercent: fd.capacityPercent,
        currentLevel: fd.currentLevel,
        warningLevel: fd.warningLevel,
        dangerLevel: fd.dangerLevel,
        rainfall24h: fd.effectiveRainfallMm > 0 ? fd.effectiveRainfallMm : null,
        flowRate: fd.flowRate,
        hasLiveData: fd.status == 'LIVE',
        lastUpdated: _liveTs(fd.lastUpdated),
      );
    }).toList();
  }

  int get totalCount => allStations.length;
  int get criticalCount =>
      allStations.where((s) => s.riskLevel == 'CRITICAL').length;
  int get severeCount =>
      allStations.where((s) => s.riskLevel == 'SEVERE').length;
  int get warningCount =>
      allStations.where((s) => s.riskLevel == 'MODERATE').length;
  int get safeCount => allStations
      .where((s) => s.riskLevel == 'LOW' || s.riskLevel == 'UNKNOWN')
      .length;
  int get noDataCount => allStations.where((s) => s.status == 'NO_DATA').length;
}
