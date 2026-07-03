// lib/services/location_service.dart
// OpsFlood — Location Service (Phase 5A)
//
// GPS-based nearby station detection using Haversine distance formula.
// Dependency: geolocator: ^12.0.0
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// ── Haversine ─────────────────────────────────────────────────────────────────

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180;

// ── Permission helpers ────────────────────────────────────────────────────────

Future<Position?> requestAndGetPosition(BuildContext context) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    final should = await _rationaleDialog(context);
    if (!should) return null;
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    await _settingsDialog(context);
    return null;
  }
  if (permission == LocationPermission.denied) return null;
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    return null;
  }
}

Future<bool> _rationaleDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('📍 Enable Location'),
          content: const Text(
              'OpsFlood uses your location to surface nearby flood monitoring stations. '
              'Your location is never stored or shared.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Allow')),
          ],
        ),
      ) ??
      false;
}

Future<void> _settingsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Location Blocked'),
      content: const Text(
          'Location permission is permanently denied. Open Settings to enable it.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Geolocator.openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}

// ── Data model ────────────────────────────────────────────────────────────────

class StationWithDistance {
  final String id, name, river, district, riskLabel;
  final double lat, lon, distanceKm;

  const StationWithDistance({
    required this.id,
    required this.name,
    required this.river,
    required this.district,
    required this.lat,
    required this.lon,
    required this.distanceKm,
    required this.riskLabel,
  });
}

// ── Riverpod notifier ─────────────────────────────────────────────────────────

class NearbyStationsNotifier extends AsyncNotifier<List<StationWithDistance>> {
  @override
  Future<List<StationWithDistance>> build() async => [];

  Future<void> refresh(
      BuildContext context, List<Map<String, dynamic>> allStations) async {
    state = const AsyncValue.loading();
    final position = await requestAndGetPosition(context);
    if (position == null) {
      state = const AsyncValue.data([]);
      return;
    }

    final withDist = allStations
        .map((s) => StationWithDistance(
              id: s['id'] as String,
              name: s['name'] as String,
              river: s['river'] as String? ?? '',
              district: s['district'] as String? ?? '',
              lat: (s['lat'] as num).toDouble(),
              lon: (s['lon'] as num).toDouble(),
              distanceKm: haversineKm(position.latitude, position.longitude,
                  (s['lat'] as num).toDouble(), (s['lon'] as num).toDouble()),
              riskLabel: s['riskLabel'] as String? ?? 'NORMAL',
            ))
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    state = AsyncValue.data(withDist.take(5).toList());
  }
}

final nearbyStationsProvider =
    AsyncNotifierProvider<NearbyStationsNotifier, List<StationWithDistance>>(
        NearbyStationsNotifier.new);

// ── NearbyStationsSection widget ─────────────────────────────────────────────
// Add <NearbyStationsSection /> just above the 'BIHAR LIVE' SectionHeader
// in dashboard_screen.dart to surface nearby stations at the top.

class NearbyStationsSection extends ConsumerWidget {
  const NearbyStationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyStationsProvider);
    return nearbyAsync.when(
      loading: () => const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child:
              LinearProgressIndicator(color: Color(0xFF00E5FF), minHeight: 2)),
      error: (_, __) => const SizedBox.shrink(),
      data: (stations) {
        if (stations.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(children: [
              const Icon(Icons.near_me_rounded,
                  color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 8),
              const Text('STATIONS NEAR YOU',
                  style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
            ]),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: stations.length,
              itemBuilder: (_, i) {
                final s = stations[i];
                return Semantics(
                  label:
                      '${s.name}, ${s.distanceKm.toStringAsFixed(1)} km away, status ${s.riskLabel}',
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFF00E5FF).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(s.river,
                              style: const TextStyle(
                                  color: Color(0xFF00E5FF), fontSize: 10)),
                          const Spacer(),
                          Row(children: [
                            const Icon(Icons.place_rounded,
                                size: 10, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 3),
                            Text('~${s.distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00E5FF))),
                          ]),
                        ]),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}
