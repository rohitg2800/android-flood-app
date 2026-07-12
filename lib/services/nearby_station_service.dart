// lib/services/nearby_station_service.dart
// OpsFlood — Module 5: Community & Offline
//
// NearbyStationService
// Finds the N closest CWC/WRD gauge stations to the user's GPS location
// using the Haversine formula.  Works entirely from the in-memory station
// registry — no network call needed — making it suitable as a pure-offline
// entry point.

import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/river_station.dart';

// ── NearbyStation result ────────────────────────────────────────────────

class NearbyStation {
  final RiverStation station;

  /// Straight-line distance in kilometres.
  final double distanceKm;

  const NearbyStation({required this.station, required this.distanceKm});

  /// Human-readable label, e.g. "3.2 km" or "124 km".
  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    if (distanceKm < 10) return '${distanceKm.toStringAsFixed(1)} km';
    return '${distanceKm.round()} km';
  }

  /// Whether the station is within a "close" threshold (10 km).
  bool get isNearby => distanceKm <= 10.0;
}

// ── Service ─────────────────────────────────────────────────────────────

class NearbyStationService {
  NearbyStationService._();
  static final NearbyStationService instance = NearbyStationService._();

  /// Returns stations within [radiusKm] (default 50 km), sorted by
  /// ascending distance, capped at [topN] results.
  ///
  /// If [lat]/[lon] are not provided the method requests the device
  /// location via Geolocator (may return null if permissions denied).
  Future<List<NearbyStation>> findNearest({
    double? lat,
    double? lon,
    int topN = 10,
    double radiusKm = 50.0,
    required List<RiverStation> allStations,
  }) async {
    double userLat = lat ?? 0;
    double userLon = lon ?? 0;

    if (lat == null || lon == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        userLat = pos.latitude;
        userLon = pos.longitude;
      } catch (_) {
        return [];
      }
    }

    final results = <NearbyStation>[];

    for (final station in allStations) {
      if (station.lat == null || station.lon == null) continue;
      final d = _haversineKm(userLat, userLon, station.lat!, station.lon!);
      if (d <= radiusKm) {
        results.add(NearbyStation(station: station, distanceKm: d));
      }
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results.take(topN).toList();
  }

  /// Synchronous version — requires pre-resolved [lat]/[lon].
  List<NearbyStation> findNearestSync({
    required double lat,
    required double lon,
    required List<RiverStation> allStations,
    int topN = 10,
    double radiusKm = 50.0,
  }) {
    final results = <NearbyStation>[];
    for (final station in allStations) {
      if (station.lat == null || station.lon == null) continue;
      final d = _haversineKm(lat, lon, station.lat!, station.lon!);
      if (d <= radiusKm) {
        results.add(NearbyStation(station: station, distanceKm: d));
      }
    }
    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results.take(topN).toList();
  }

  // ── Haversine ────────────────────────────────────────────────────────

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
