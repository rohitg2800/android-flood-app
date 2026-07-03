// lib/providers/cwc_provider.dart
// Riverpod providers that expose live CWC Bihar station data
// fetched from irrigation.befiqr.in (via BefiqrCwcService).
// All screens can watch these providers to get real-time river levels.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../services/befiqr_cwc_service.dart';

// ── raw station list (auto-refreshes every 10 min) ────────────────────────────

final cwcStationsProvider =
    FutureProvider.autoDispose<List<CwcStation>>((ref) async {
  final svc = BefiqrCwcService();
  return svc.fetchStations();
});

// ── top-5 risk stations (used by Dashboard + Prediction widgets) ──────────────

final cwcTopRiskProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData(
    (list) => BefiqrCwcService.topRisk(list, n: 5),
  );
});

// ── stations grouped by river name ───────────────────────────────────────────

final cwcByRiverProvider =
    Provider.autoDispose<AsyncValue<Map<String, List<CwcStation>>>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData((list) {
    final map = <String, List<CwcStation>>{};
    for (final s in list) {
      map.putIfAbsent(s.river, () => []).add(s);
    }
    return map;
  });
});

// ── danger-level stations only (above or within 1.5 m of danger) ──────────────

final cwcAlertStationsProvider =
    Provider.autoDispose<AsyncValue<List<CwcStation>>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData(
    (list) => list.where((s) => s.isDanger || s.isWarning).toList()
      ..sort((a, b) => a.gap.compareTo(b.gap)),
  );
});

// ── overall Bihar flood risk index (0-100) ────────────────────────────────────
// Average risk score of all stations, weighted by (1/gap).

final biharFloodRiskIndexProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  final stations = ref.watch(cwcStationsProvider);
  return stations.whenData((list) {
    if (list.isEmpty) return 0.0;
    final scores = list.map(BefiqrCwcService.riskScore).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
  });
});

// ── Bihar district GeoJSON (used by BiharRiverMapScreen district layer) ────────
// Fetched once and kept alive for the session.

final biharGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // keepAlive so it is not disposed when no listener exists temporarily.
  ref.keepAlive();

  const url =
      'https://raw.githubusercontent.com/geohacker/bihar/master/district/bihar_district.topojson';
  // Fallback plain GeoJSON if the topojson URL is unreachable.
  const fallbackUrl =
      'https://raw.githubusercontent.com/datameet/maps/master/Districts/Bihar.geojson';

  Future<Map<String, dynamic>> fetchGeoJson(String uri) async {
    final res =
        await http.get(Uri.parse(uri)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('GeoJSON fetch failed: HTTP \${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  try {
    final raw = await fetchGeoJson(url);
    // Convert TopoJSON → GeoJSON if needed.
    if (raw['type'] == 'Topology') {
      return _topoToGeoJson(raw);
    }
    return raw;
  } catch (_) {
    return fetchGeoJson(fallbackUrl);
  }
});

// ── Minimal TopoJSON → GeoJSON converter ─────────────────────────────────────
// Handles arcs-based Polygon / MultiPolygon geometry for district polygons.

Map<String, dynamic> _topoToGeoJson(Map<String, dynamic> topo) {
  final objects = topo['objects'] as Map<String, dynamic>? ?? {};
  final firstObj = objects.values.first as Map<String, dynamic>;
  final geometries =
      (firstObj['geometries'] as List? ?? []).cast<Map<String, dynamic>>();
  final arcs = (topo['arcs'] as List? ?? []).cast<List>();
  final scale = topo['transform']?['scale'] as List?;
  final translate = topo['transform']?['translate'] as List?;

  List<double> decodePoint(List<int> delta, List<double> cursor) {
    cursor[0] += delta[0];
    cursor[1] += delta[1];
    final x = scale != null
        ? cursor[0] * (scale[0] as num).toDouble() +
            (translate![0] as num).toDouble()
        : cursor[0].toDouble();
    final y = scale != null
        ? cursor[1] * (scale[1] as num).toDouble() +
            (translate![1] as num).toDouble()
        : cursor[1].toDouble();
    return [x, y];
  }

  List<List<double>> decodeArc(int arcIndex) {
    final reversed = arcIndex < 0;
    final idx = reversed ? ~arcIndex : arcIndex;
    final rawArc = arcs[idx];
    final cursor = [0.0, 0.0];
    final pts = rawArc
        .cast<List>()
        .map((p) => decodePoint(p.cast<int>(), cursor))
        .toList();
    return reversed ? pts.reversed.toList() : pts;
  }

  List<List<List<double>>> decodeRing(List arcIndices) {
    final pts = <List<double>>[];
    for (final i in arcIndices.cast<int>()) {
      final decoded = decodeArc(i);
      if (pts.isNotEmpty) pts.removeLast(); // remove shared endpoint
      pts.addAll(decoded);
    }
    if (pts.isNotEmpty && pts.first != pts.last) pts.add(pts.first);
    return [pts];
  }

  final features = geometries.map((g) {
    final type = g['type'] as String? ?? '';
    final props = g['properties'] as Map<String, dynamic>? ?? {};
    dynamic geometry;

    if (type == 'Polygon') {
      final rings = (g['arcs'] as List).cast<List>();
      geometry = {
        'type': 'Polygon',
        'coordinates': rings.map(decodeRing).toList(),
      };
    } else if (type == 'MultiPolygon') {
      final parts = (g['arcs'] as List).cast<List>();
      geometry = {
        'type': 'MultiPolygon',
        'coordinates':
            parts.map((p) => p.cast<List>().map(decodeRing).toList()).toList(),
      };
    } else {
      geometry = {'type': type, 'coordinates': []};
    }

    return {
      'type': 'Feature',
      'properties': props,
      'geometry': geometry,
    };
  }).toList();

  return {
    'type': 'FeatureCollection',
    'features': features,
  };
}
